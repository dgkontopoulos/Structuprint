#!/usr/bin/env perl

=head1 NAME

structuprint_frame

=head1 SYNOPSIS

structuprint_frame.pl directory property

=head1 DESCRIPTION

structuprint_frame is a tool for creating single 'structuprints' 
from PDB structures. Refer to structuprint's main documentation 
for more details.

=head1 OPTIONS

=head2 -prop

Display the list of available amino acid properties to choose from.

=head1 DEPENDENCIES

-the Perl interpreter, >= 5.10
-Astro::MapProjection, >= 0.01 (Perl module)
-Bio::PDB::Structure, >= 0.01 (Perl module)
-DBD::SQLite, >= 1.37 (Perl module)
-DBI, >= 1.622 (Perl module)
-File::Spec, >= 3.33 (Perl module)
-List::Util, >= 1.25 (Perl module)
-Math::Round, >= 0.06 (Perl module)
-Statistics::R, >= 0.30 (Perl module)
-the R interpreter, >= 2.15.1
-ggplot2, >= 0.9.3 (R package)

=head1 AUTHOR

Dimitrios - Georgios Kontopoulos
<dgkontopoulos@gmail.com>

=head1 LICENSE

This program is free software: you can redistribute it 
and/or modify it under the terms of the GNU General 
Public License as published by the Free Software 
Foundation, either version 2 of the License, or (at your 
option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

For more information, see http://www.gnu.org/licenses/.

=cut

use strict;
use warnings;

use feature qw(say);

use Astro::MapProjection qw(miller_projection);
use Bio::PDB::Structure;
use DBI;
use File::Spec;
use List::Util qw(min max);
use Math::Round qw(round nearest nhimult);
use Statistics::R;

#Display the available amino acid properties, when using the prop flag.#
if ( $ARGV[0] && $ARGV[0] eq '-prop' )
{
    local $/ = undef;
    open my $fh, '<', '/opt/structuprint/props.txt' or die $!;
    my $properties = <$fh>;
    close $fh;
    print $properties;
    exit;
}
else
{
    my @properties = @{ amino_acid_properties() };

    #Check the number of arguments/flags.#
    @ARGV == 2
      or die "\033[1mUsage: $0 directory property\033[0m\n"
      . "\nTo see a list of all available amino acid properties, type:\n"
      . "$0 \033[1m-prop\033[0m | more -d\n";

    #Make sure that the specified property actually exists.#
    if ( !( /$ARGV[1]/i ~~ @properties ) )
    {
        die "\033[1mERROR!\033[0m\n"
          . "No such amino acid property: $ARGV[1]\n"
          . "\nTo see a list of all available amino acid properties, type:\n"
          . "$0 \033[1m-prop\033[0m | more -d\n";
    }
}

my ( $directory, $files ) = directory_handling();
open STDERR, '>', $directory . 'log.txt' or die $!;

my ( $grid, $surface_residue ) = initial_grid( $ARGV[0] );

dummy_atoms( $grid, $surface_residue );
my ( $min_charge, $max_charge ) =
  map_projection( sphere( $grid, $surface_residue ) );
plot_fingerprint( $directory . 'miller2' );
standing_out_areas( $directory . 'miller2', $min_charge, $max_charge );

#---------------------------------------------------------------------#
#    S     U     B     R     O     U     T     I     N     E     S    #
#---------------------------------------------------------------------#

#Connect to the database and retrieve the amino acid properties.#
sub amino_acid_properties
{
    my $dbh =
      DBI->connect( 'dbi:SQLite:/opt/structuprint/amino_acid_properties.db',
        q{}, q{} );
    my $db_sel =
      $dbh->prepare('SELECT name FROM sqlite_master WHERE type = "table"');
    $db_sel->execute();
    my $properties = $db_sel->fetchall_arrayref;
    $dbh->disconnect();

    my $index = 0;
    my @properties;
    while ( $properties->[$index] )
    {
        push @properties, $properties->[$index]->[0];
        $index++;
    }
    return \@properties;
}

#Define the working directory and its file.#
sub directory_handling
{
    my $temp_file = 'temp';
    my $full_path = File::Spec->catpath( q{}, $ARGV[0], $temp_file );
    $full_path = File::Spec->rel2abs($full_path);

    my $directory;
    if ( $full_path =~ /$temp_file$/ )
    {
        $directory = $`;
    }

    opendir my $dh, $directory
      or die "\033[1mERROR!\033[0m\n" . "$directory cannot be opened.\n";
    my @files;

    #Read the files in the directory.#
    while ( readdir $dh )
    {

        #Exclude ".", "..".#
        if ( $_ ne q{.} && $_ ne q{..} && $_ =~ /[.]pdb$/ )
        {
            push @files, $_;
        }
    }
    closedir $dh;

    #Check for more -or fewer- files than needed.#
    if ( $#files > 0 )
    {
        die "\n\033[1mERROR!\033[0m\n"
          . "The directory contains more than one PDB file.\n"
          . "Please provide a directory with only one PDB file inside.\n\n";
    }
    elsif ( $#files == -1 )
    {
        die "\n\033[1mERROR!\033[0m\n"
          . "No suitable PDB file in $directory.\n"
          . "Please provide a directory with only one PDB file inside.\n\n";
    }

    return $directory, \@files;
}

#Generate a PDB file with dummy atoms, where nothing was found.#
sub dummy_atoms
{
    my ( $grid, $surface_residue ) = @_;

    my ( $x_coor, $y_coor, $z_coor );

    #Set the output file's name and change it if it already exists.#
    my $resulting_file = $directory . 'void.pdb';

    while ( -e $resulting_file )
    {
        if ( $resulting_file =~ /([_]?\w+)[.]pdb/ )
        {
            $resulting_file = $` . $1 . '_new.pdb';
        }
    }

    my $dbh =
      DBI->connect( 'dbi:SQLite:/opt/structuprint/amino_acid_properties.db',
        q{}, q{} );
    my $db_sel = $dbh->prepare("SELECT * FROM $ARGV[1]");
    $db_sel->execute();
    my $properties = $db_sel->fetchall_hashref('Amino_Acid');
    $dbh->disconnect();

    my $atom_number = 1;
    open my $fh, '>', $resulting_file || die "Cannot create $resulting_file.\n";
    foreach my $key ( keys %$grid )
    {
        if ( $grid->{$key} == 0 )
        {
            if ( $key =~ /([-]?\d+)\s+([-]?\d+)\s+([-]?\d+)/ )
            {
                my $residue = $surface_residue->{"$1 $2 $3"};
                my $charge = property_value( $residue, $properties );

                #Make sure the PDB file is well formatted.#
                $x_coor = $1;
                $x_coor = sprintf '%7.3f', $x_coor;
                $y_coor = $2;
                $y_coor = sprintf '%7.3f', $y_coor;
                $z_coor = $3;
                $z_coor = sprintf '%7.3f', $z_coor;

                $charge = sprintf '%5.2f', $charge;
                my $atom_number_new = sprintf '%4d', $atom_number;

                #Print to the PDB file.#
                say {$fh}
"HETATM $atom_number_new Du       U         $x_coor $y_coor $z_coor       $charge";
                $atom_number++;
            }

        }
    }
    say {$fh} 'END';
    close $fh;
    return 0;
}

sub grouping_grid
{
    my ( $x, $y, $weighting, $grid_dim, $R ) = @_;
    my ( %grid, %grid_weights, %average, %max, %min, %counter, %values );

    for ( 0 .. scalar @{$weighting} - 1 )
    {
        my $old_x  = $x->[$_];
        my $old_y  = $y->[$_];
        my $x_coor = nearest( $grid_dim, $x->[$_] );
        my $y_coor = nearest( $grid_dim, $y->[$_] );
        my $weight = $weighting->[$_];

        if ( $grid{"$x_coor $y_coor"} )
        {
            $counter{"$x_coor $y_coor"} //= 0;
            $counter{"$x_coor $y_coor"}++;
            $average{"$x_coor $y_coor"} //= 0;

            $average{"$x_coor $y_coor"} =
              ( ( $grid{"$x_coor $y_coor"} * $grid_weights{"$x_coor $y_coor"} )
                + $weight ) / ( $grid{"$x_coor $y_coor"} + 1 );
            $grid_weights{"$x_coor $y_coor"} = $average{"$x_coor $y_coor"};
            $grid{"$x_coor $y_coor"}++;

            $max{"$x_coor $y_coor"} //= -5000;
            $min{"$x_coor $y_coor"} //= 5000;

            $max{"$x_coor $y_coor"} = max( $weight, $max{"$x_coor $y_coor"} );
            $min{"$x_coor $y_coor"} = min( $weight, $min{"$x_coor $y_coor"} );
        }
        else
        {
            $grid{"$x_coor $y_coor"}         = 1;
            $grid_weights{"$x_coor $y_coor"} = $weight;
        }
    }

    my $element_counter = 0;
    my $elements        = 0;
    foreach my $key ( keys %counter )
    {
        $elements += $counter{$key};
        $element_counter++;
    }
    $elements /= $element_counter;

    foreach my $key ( keys %counter )
    {
        if ( $counter{$key} < ( $elements * 0.25 ) )
        {
            $grid_weights{$key} = 0;
        }
    }
    return \%grid_weights;
}

sub initial_grid
{
    my ( %grid, %grid_freq, %amino_acid );

    my $xmin = 99_999;
    my $ymin = 99_999;
    my $zmin = 99_999;
    my $xmax = -99_999;
    my $ymax = -99_999;
    my $zmax = -99_999;

    my $prot = Bio::PDB::Structure::Molecule->new;
    my $atoms_number;
    $prot->read( $directory . $files->[0] );
    $atoms_number = $prot->size;

    #For every atom...#
    for my $atom ( 0 .. $atoms_number - 1 )
    {

        #... round its coordinates...#
        my $atom1  = $prot->atom($atom);
        my $x_coor = round( $atom1->x );
        my $y_coor = round( $atom1->y );
        my $z_coor = round( $atom1->z );

        #... and put them in the grid.#
        if ( !( $grid{"$x_coor $y_coor $z_coor"} ) )
        {
            $grid{"$x_coor $y_coor $z_coor"}      = 1;
            $grid_freq{"$x_coor $y_coor $z_coor"} = 0;
        }

        $grid_freq{"$x_coor $y_coor $z_coor"}++;

        #Get the residues for each position.#
        if ( !( $amino_acid{"$x_coor $y_coor $z_coor"} ) )
        {
            $amino_acid{"$x_coor $y_coor $z_coor"} =
              $atom1->residue_name . q{ };
        }
        else
        {
            $amino_acid{"$x_coor $y_coor $z_coor"} .=
              $atom1->residue_name . q{ };
        }

        #Get the current grid dimensions.#
        $xmin = min $xmin, $x_coor;
        $xmax = max $xmax, $x_coor;
        $ymin = min $ymin, $y_coor;
        $ymax = max $ymax, $y_coor;
        $zmin = min $zmin, $z_coor;
        $zmax = max $zmax, $z_coor;
    }

    my ( $grid, $surf ) = proximity_check(
        $xmin, $xmax,  $ymin,       $ymax, $zmin,
        $zmax, \%grid, \%grid_freq, \%amino_acid
    );

    return $grid, $surf;
}

#Create a map projection from the sphere coordinates.#
sub map_projection
{
    my ( $maphash, $radius ) = @_;

    my ( %amino_miller, %miller );

    my $max_x = -500;
    my $min_x = 500;

    #Iterate through the sphere data.#
    foreach my $key ( keys %$maphash )
    {
        if ( $maphash->{$key} == 1 )
        {
            if ( $key =~ /\d+\s+(\S+)\s+(\S+)\s+(\S+)\s+(.+)/ )
            {
                my $x          = $1;
                my $y          = $2;
                my $z          = $3;
                my $amino_acid = $4;

                #Compute the latitude and longitude for each point.#
                my $latitude  = atan2 $y, sqrt( $x * $x + $z * $z );
                my $longitude = atan2 $x, $z;

                #Perform a Miller projection.#
                my ( $new_x, $new_y ) =
                  miller_projection( $latitude, $longitude );

                $max_x = max $max_x, $new_x;
                $min_x = min $min_x, $new_x;
                if ( !( $miller{"$new_x $new_y"} ) )
                {
                    $miller{"$new_x $new_y"}       = 1;
                    $amino_miller{"$new_x $new_y"} = $amino_acid;
                }
                else
                {
                    my $new_percent =
                      $amino_miller{"$new_x $new_y"} . q{, } . $amino_acid;
                    $amino_miller{"$new_x $new_y"} =
                      residue_percentage_reformat($new_percent);
                }
            }
        }
    }

    #Select an output file for the Miller projection and write to it.#
    my $resulting_file1 = $directory . 'miller.txt';
    while ( -e $resulting_file1 )
    {
        if ( $resulting_file1 =~ /([_]?\w+)[.]txt/ )
        {
            $resulting_file1 = $` . $1 . '_new.txt';
        }
    }

    #Connect to the database and fetch a hash for the property of choice.#
    my $dbh =
      DBI->connect( 'dbi:SQLite:/opt/structuprint/amino_acid_properties.db',
        q{}, q{} );
    my $db_sel = $dbh->prepare("SELECT * FROM $ARGV[1]");
    $db_sel->execute();
    my $properties = $db_sel->fetchall_hashref('Amino_Acid');
    $dbh->disconnect();

    open my $fh1, '>',
      $resulting_file1 || die "Cannot create $resulting_file1.\n";
    say {$fh1} "<--- Miller projection coordinates from $directory --->";
    say {$fh1}
"\n   No.             X                        Y                  Residue";
    say {$fh1}
'============================================================================================';

    open my $fh_pl, '>',
      $directory . 'miller' || die "Cannot create $directory" . "miller.\n";

    my $atom_number = 1;
    my ( @x, @y, @weight );

    foreach my $key ( keys %miller )
    {
        if ( $miller{$key} == 1 )
        {
            if ( $key =~ /(\S+)\s+(\S+)/ )
            {
                my $x = $1;
                if ( $x <= 0 )
                {
                    $x += abs($min_x) + $max_x;
                }
                $x = sprintf '%23.20f', $x;
                my $y = $2;
                $y = sprintf '%23.20f', $y;
                my $amino_acid = $amino_miller{$key};

                my $id = sprintf '%6d', $atom_number;
                say {$fh1} "$id  $x  $y   $amino_acid";
                $amino_acid = property_value( $amino_acid, $properties );
                say {$fh_pl} "$x  $y $amino_acid";
                push @x,      $x;
                push @y,      $y;
                push @weight, $amino_acid;
                $atom_number++;
            }
        }
    }
    close $fh_pl;
    close $fh1;

    my @runs;
    my $R = Statistics::R->new();
    for ( my $dimensions = 0.001 ; $dimensions <= 0.5 ; $dimensions += 0.001 )
    {
        my ($grid) = grouping_grid( \@x, \@y, \@weight, $dimensions, $R );
        push @runs, $grid;
    }
    $R->stop();

    my $min_charge = 500;
    my $max_charge = -500;
    open my $fh_pl2, '>',
      $directory . 'miller2' || die "Cannot create $directory" . "miller2.\n";

    $atom_number = 1;
    foreach my $key ( keys %miller )
    {
        if ( $miller{$key} == 1 )
        {
            if ( $key =~ /(\S+)\s+(\S+)/ )
            {
                my $x = $1;
                if ( $x <= 0 )
                {
                    $x += abs($min_x) + $max_x;
                }
                my $y = $2;

                my $amino_acid = 0;

                my $dimension = 0.001;
                for ( 0 .. $#runs )
                {
                    my $temp_x = nearest( $dimension, $x );
                    my $temp_y = nearest( $dimension, $y );

                    $amino_acid += $runs[$_]->{"$temp_x $temp_y"};
                    $dimension  += 0.001;
                }
                $amino_acid /= ( $#runs + 1 );
                $amino_acid //= 0;

                $min_charge = min( $amino_acid, $min_charge );
                $max_charge = max( $amino_acid, $max_charge );
                $x = sprintf '%23.20f', $x;
                $y = sprintf '%23.20f', $y;

                say {$fh_pl2} "$x  $y $amino_acid";
                $atom_number++;
            }
        }
    }
    close $fh_pl2;

    return $min_charge, $max_charge;
}

#Move every atom in the sphere to its surface.#
sub move_to_surface
{
    my ( $radius, $x, $y, $z ) = @_;
    my ( $new_x, $new_y );

    if ( $x == 0 )
    {
        $new_x = 0;
        my $root = $radius * $radius - $z * $z;
        if ( $root >= 0 )
        {
            $new_y = sqrt $root;
            if ( $y < 0 )
            {
                $new_y *= -1;
            }
        }
        else
        {
            $new_x = 'NA';
            $new_y = 'NA';
        }
    }
    elsif ( $y == 0 )
    {
        $new_y = 0;
        my $root = $radius * $radius - $z * $z;
        if ( $root >= 0 )
        {
            $new_x = sqrt $root;
            if ( $x < 0 )
            {
                $new_x *= -1;
            }
        }
        else
        {
            $new_x = 'NA';
            $new_y = 'NA';
        }
    }
    else
    {
        my $a_factor = $y / $x;
        my $root =
          ( $radius * $radius - $z * $z ) / ( $a_factor * $a_factor + 1 );
        if ( $root >= 0 )
        {
            $new_x = sqrt $root;
            $new_y = abs $a_factor * $new_x;
            if ( $x < 0 )
            {
                $new_x *= -1;
            }
            if ( $y < 0 )
            {
                $new_y *= -1;
            }
        }
        else
        {
            $new_x = 'NA';
            $new_y = 'NA';
        }
    }
    return $new_x, $new_y;
}

#Calls the R interpreter to plot the fingerprint graph.#
sub plot_fingerprint
{
    my ($miller_file) = @_;

    my $R = Statistics::R->new();
    $R->set( 'directory',   $directory );
    $R->set( 'miller_file', $miller_file );
    $R->set( 'property',    $ARGV[1] );

    my $R_commands = << 'END';
	library("ggplot2")
	library("grid")
	ending <- "structuprint.png"
	name <- paste(directory, ending, sep = "")
	png(filename = name, width = 1700, height = 1700, units = "px", bg = "black")
	
	x <- read.table(pipe(paste("perl -anle 'print $F[0]'", miller_file)))
	x <- as.vector(x$V1)
	
	y <- read.table(pipe(paste("perl -anle 'print $F[1]'", miller_file)))
	y <- as.vector(y$V1)
	
	Charge <- read.table(pipe(paste("perl -anle 'print $F[2]'", miller_file)))
	Charge <- as.vector(Charge$V1)
	
	dat <- data.frame(cond = Charge, xvar = x, yvar = y)
	ggplot(dat, aes(x = x, y = y, color = Charge)) + labs(colour = property) + geom_point() + scale_colour_gradientn(colours = c("blue", 
    "white", "red")) + theme(panel.background = element_rect(fill = "black"), panel.grid.major.x = element_blank(), 
    panel.grid.major.y = element_blank(), panel.grid.minor.x = element_blank(), panel.grid.minor.y = element_blank(),
    legend.title = element_text(size=30), legend.text = element_text(size = 30), legend.key.size = unit(1.5, "cm"))
END
    $R->run($R_commands);
    $R->stop();
    return 0;
}

#Compute the value of the property of choice for each position.#
sub property_value
{
    my ( $residue, $properties ) = @_;

    my %aminos;

    #Get all the residues.#
    while ( $residue =~ /\w/ )
    {
        if ( $residue =~ /(\d+[.]\d+)%\s(\w+)[,]?\s?/ )
        {
            $aminos{$2} = $1;
            $aminos{$2} /= 100;
            $residue = $';
        }
    }

    my $value = 0;

    #Calculate the resulting value.#
    foreach my $key ( keys %aminos )
    {
        if ( $properties->{$key}->{'Value'} )
        {
            $value += $properties->{$key}->{'Value'} * $aminos{$key};
        }
    }

    return $value;
}

#Select air atoms located next to one and only atom of the protein.#
sub proximity_check
{
    my (
        $xmin, $xmax, $ymin,      $ymax, $zmin,
        $zmax, $grid, $grid_freq, $amino_acid
    ) = @_;

    my %surface_residue;

    #Iterate through the grid elements.#
    for my $current_x ( $xmin - 1 .. $xmax + 1 )
    {
        for my $current_y ( $ymin - 1 .. $ymax + 1 )
        {
            for my $current_z ( $zmin - 1 .. $zmax + 1 )
            {
                if ( !( $grid->{"$current_x $current_y $current_z"} ) )
                {

                    #Prepare the steps.#
                    my $temp_x_p = $current_x + 1;
                    my $temp_y_p = $current_y + 1;
                    my $temp_z_p = $current_z + 1;
                    my $temp_x_m = $current_x - 1;
                    my $temp_y_m = $current_y - 1;
                    my $temp_z_m = $current_z - 1;

                    my $sum = 0;
                    my $residue;

                    my @neighbors = (
                        "$temp_x_p $current_y $current_z",
                        "$temp_x_p $temp_y_p $current_z",
                        "$temp_x_p $temp_y_m $current_z",
                        "$temp_x_m $current_y $current_z",
                        "$temp_x_m $temp_y_p $current_z",
                        "$temp_x_m $temp_y_m $current_z",
                        "$current_x $temp_y_p $current_z",
                        "$current_x $temp_y_p $temp_z_p",
                        "$current_x $temp_y_p $temp_z_m",
                        "$current_x $temp_y_m $temp_z_m",
                        "$current_x $temp_y_m $temp_z_p",
                        "$current_x $temp_y_m $current_z",
                        "$current_x $current_y $temp_z_p",
                        "$temp_x_p $current_y $temp_z_p",
                        "$temp_x_m $current_y $temp_z_p",
                        "$temp_x_m $current_y $temp_z_m",
                        "$temp_x_p $current_y $temp_z_m",
                        "$current_x $current_y $temp_z_m",
                    );

                    for ( 0 .. $#neighbors )
                    {

                        #Check for existing protein atoms nearby.#
                        if ( $grid->{ $neighbors[$_] } )
                        {
                            $sum += $grid->{ $neighbors[$_] };
                            $residue //= $amino_acid->{ $neighbors[$_] };
                        }
                    }

                    #Select only those having one protein atom next to them.#
                    if ( $sum == 1 )
                    {
                        $grid->{"$current_x $current_y $current_z"}      = 0;
                        $grid_freq->{"$current_x $current_y $current_z"} = 0;

                        #Get the percentage of nearby residues.#
                        $surface_residue{"$current_x $current_y $current_z"} =
                          residue_percentage($residue);
                    }
                }
            }
        }
    }
    return $grid, \%surface_residue;
}

#Calculate the percentage of residues for a position.#
sub residue_percentage
{
    my ($residue) = @_;

    my @amino;

    #Get all the residues.#
    while ( $residue =~ /\w/ )
    {
        if ( $residue =~ /(\w+)/ )
        {
            push @amino, $1;
            $residue = $';
        }
    }

    my %freq;

    #Count the occurences for each residue.#
    foreach my $value (@amino)
    {
        if ( !( $freq{$value} ) )
        {
            $freq{$value} = 1;
        }
        else
        {
            $freq{$value}++;
        }
    }

    #Calculate the percentage.#
    foreach my $key ( keys %freq )
    {
        $freq{$key} = sprintf '%6.2f',
          ( ( $freq{$key} / ( $#amino + 1 ) ) * 100 );
        $freq{$key} .= q{%};
    }
    $residue = q{};

    #Format the result.#
    foreach my $key ( keys %freq )
    {
        $residue .= $freq{$key} . q{ } . $key . q{, };
    }
    $residue =~ s/, $//;
    return $residue;
}

#Compute the percentage of residues, starting with percentages.#
sub residue_percentage_reformat
{
    my ($residue) = @_;
    my %aminos;

    #Get all the residues.#
    while ( $residue =~ /\w/ )
    {
        if ( $residue =~ /(\d+[.]\d+)%\s(\w+)[,]?\s?/ )
        {
            if ( !( $aminos{$2} ) )
            {
                $aminos{$2} = $1;
            }
            else
            {
                $aminos{$2} += $1;
            }
            $residue = $';
        }
    }

    my $sum = 0;

    #Add their per cent values.#
    foreach my $key ( keys %aminos )
    {
        $sum += $aminos{$key};
    }

    #Transform the sum to a percentage.#
    foreach my $key ( keys %aminos )
    {
        $aminos{$key} = sprintf '%6.2f', ( ( $aminos{$key} / $sum ) * 100 );
        $aminos{$key} .= q{%};
    }
    $residue = q{};

    #Format the result.#
    foreach my $key ( keys %aminos )
    {
        $residue .= $aminos{$key} . q{ } . $key . q{, };
    }
    $residue =~ s/, $//;
    return $residue;
}

#Create a sphere out of the x, y, z coordinates of the atoms.#
sub sphere
{
    my ( $grid, $surface_residue ) = @_;

    my $center_x = 0;
    my $center_y = 0;
    my $center_z = 0;

    my $atom_counter = 0;

    #Find the center of mass.#
    foreach my $key ( keys %$grid )
    {
        if ( $grid->{$key} == 0 )
        {
            if ( $key =~ /([-]?\d+)\s+([-]?\d+)\s+([-]?\d+)/ )
            {
                $center_x += $1;
                $center_y += $2;
                $center_z += $3;
            }
            $atom_counter++;
        }
    }
    $center_x /= $atom_counter;
    $center_x = round($center_x);
    $center_y /= $atom_counter;
    $center_y = round($center_y);
    $center_z /= $atom_counter;
    $center_z = round($center_z);

    my $radius = 0;

    #Compute the distance of each atom from the center of mass.#
    my %distance;
    foreach my $key ( keys %$grid )
    {
        if ( $grid->{$key} == 0 )
        {
            if ( $key =~ /([-]?\d+)\s+([-]?\d+)\s+([-]?\d+)/ )
            {
                my $x = $1;
                my $y = $2;
                my $z = $3;

                my $dist =
                  sqrt( ( $x - $center_x ) * ( $x - $center_x ) +
                      ( $y - $center_y ) * ( $y - $center_y ) +
                      ( $z - $center_z ) * ( $z - $center_z ) );
                $distance{$key} = $dist;
                $radius = max $radius, $dist;
            }
        }
    }

    #Select the output file for the sphere data.#
    my $resulting_file = $directory . 'sphere.txt';
    while ( -e $resulting_file )
    {
        if ( $resulting_file =~ /([_]?\w+)[.]txt/ )
        {
            $resulting_file = $` . $1 . '_new.txt';
        }
    }

    my $resulting_file2 = $resulting_file;
    $resulting_file2 =~ s/txt/pdb/;

    #Print data to the output file.#
    open my $fh, '>', $resulting_file || die "Cannot create $resulting_file.\n";
    open my $fh2, '>',
      $resulting_file2 || die "Cannot create $resulting_file2\n";
    say {$fh} "<--- Sphere data from $directory --->";
    say {$fh} 'Radius: ' . $radius;
    say {$fh} "\n   No.     X       Y       Z    Residue";
    say {$fh} '=============================================================';

    my $atom_number = 1;

    my $dbh =
      DBI->connect( 'dbi:SQLite:/opt/structuprint/amino_acid_properties.db',
        q{}, q{} );
    my $db_sel = $dbh->prepare("SELECT * FROM $ARGV[1]");
    $db_sel->execute();
    my $properties = $db_sel->fetchall_hashref('Amino_Acid');
    $dbh->disconnect();

    my %map_hash;

    foreach my $key ( keys %$grid )
    {
        if ( $grid->{$key} == 0 )
        {
            if ( $key =~ /([-]?\d+)\s+([-]?\d+)\s+([-]?\d+)/ )
            {
                my $x = $1 - $center_x * 0.9;
                my $y = $2 - $center_y * 0.9;
                my $z = $3 - $radius * 0.9;

                ( $x, $y ) = move_to_surface( $radius, $x, $y, $z );
                if ( $x ne 'NA' && $y ne 'NA' )
                {
                    $x = sprintf '%7.2f', $x;
                    $y = sprintf '%7.2f', $y;
                    $z = sprintf '%7.2f', $z;

                    my $id = sprintf '%6d', $atom_number;
                    say {$fh} "$id $x $y $z   $surface_residue->{$key}";
                    $map_hash{"$id $x $y $z   $surface_residue->{$key}"} = 1;

                    my $charge =
                      property_value( $surface_residue->{$key}, $properties );

                    #Make sure the PDB file is well formatted.#
                    my $x_coor = $x;
                    $x_coor = sprintf '%7.3f', $x_coor;
                    my $y_coor = $y;
                    $y_coor = sprintf '%7.3f', $y_coor;
                    my $z_coor = $z;
                    $z_coor = sprintf '%7.3f', $z_coor;

                    $charge = sprintf '%5.2f', $charge;

                    my $atom_number_new = sprintf '%4d', $atom_number;

                    #Print to the PDB file.#
                    say {$fh2}
"HETATM $atom_number_new Du       U         $x_coor $y_coor $z_coor       $charge";
                    $atom_number++;
                }
            }
        }
    }
    close $fh2;
    close $fh;
    return \%map_hash, $radius;
}

#Report areas with peaks.#
sub standing_out_areas
{
    my ( $input_file, $charge_min, $charge_max ) = @_;

    my ( %positively_charged, %negatively_charged );
    open my $fh, '<', $input_file or die "Cannot open $input_file\n";
    local $/ = "\n";
    while ( my $line = <$fh> )
    {
        if ( $line =~ /^(.+)\s(.+)\s(.+)$/ )
        {

            #Get the areas with a weighting of more than 85% of max.#
            if ( $3 > ( 0.85 * $charge_max ) )
            {

                #Create a grid of 0.25.#
                my $x = nearest( 0.25, $1 );
                my $y = nearest( 0.25, $2 );

                if ( !( $positively_charged{"$x $y"} ) )
                {
                    $positively_charged{"$x $y"} = 1;
                }
                else
                {
                    $positively_charged{"$x $y"}++;
                }
            }

            #Get the areas with a weighting of more than 85% of max.#
            elsif ( $3 < ( 0.85 * $charge_min ) )
            {

                #Create a grid of 0.25.#
                my $x = nearest( 0.25, $1 );
                my $y = nearest( 0.25, $2 );

                if ( !( $negatively_charged{"$x $y"} ) )
                {
                    $negatively_charged{"$x $y"} = 1;
                }
                else
                {
                    $negatively_charged{"$x $y"}++;
                }
            }
        }
    }
    close $fh;

    my @positive_locations;
    foreach my $key ( keys %positively_charged )
    {
        if ( $positively_charged{$key} > 1 )
        {
            push @positive_locations, $key;
        }
    }

    my @negative_locations;
    foreach my $key ( keys %negatively_charged )
    {
        if ( $negatively_charged{$key} > 1 )
        {
            push @negative_locations, $key;
        }
    }

    my $positive_locations = unite_nearby( \@positive_locations );
    my $negative_locations = unite_nearby( \@negative_locations );

    my $output_file = $input_file;
    $output_file =~ s/miller2/areas_worth_noting.txt/;

    open my $out_fh, '>', $output_file or die $!;
    say {$out_fh} 'Areas worth noting:';
    foreach ( @{$positive_locations} )
    {
        if ($_)
        {
            say {$out_fh} $_;
        }
    }

    foreach ( @{$negative_locations} )
    {
        if ($_)
        {
            say {$out_fh} $_;
        }
    }
    close $out_fh;
    return 0;
}

#Connect nearby regions when reporting them.#
sub unite_nearby
{
    my ($locations) = @_;
    my @locations = @{$locations};

    for my $index1 ( 0 .. $#locations )
    {
        if ( defined $locations[$index1] )
        {
            my ( $x1, $y1 );
            if ( $locations[$index1] =~ /\s/ )
            {
                $x1 = $`;
                $y1 = $';
            }
            for my $index2 ( $index1 .. $#locations )
            {
                if ( defined $locations[$index2] )
                {
                    my ( $x2, $y2 );
                    if ( $locations[$index2] =~ /\s/ )
                    {
                        $x2 = $`;
                        $y2 = $';
                    }

                    #If their distance is 0.5 or less, join them.#
                    if (   ( abs( $x2 - $x1 ) <= 0.5 )
                        && ( abs( $y2 - $y1 ) <= 0.5 ) )
                    {
                        my $new_x = ( $x1 + $x2 ) / 2;
                        my $new_y = ( $y1 + $y2 ) / 2;

                        $locations[$index1] = $new_x . q{ } . $new_y;
                        undef $locations[$index2];
                    }
                }
            }
        }
    }
    return \@locations;
}
