#!/usr/bin/env perl

# This block loads modules for specific operating systems only.
BEGIN
{
    if ( $^O eq 'MSWin32' )
    {
        eval 'use Win32::Console::ANSI';
        die "$@" if $@;
    }
    else
    {
        eval 'use Statistics::R';
        die "$@" if $@;
    }
}

use strict;
use warnings;

use feature qw(say);

use Astro::MapProjection qw(miller_projection);
use Bio::PDB::Structure;
use DBI;
use File::Spec;
use Getopt::Long;
use List::Util qw(min max);
use Math::Round qw(round nearest nhimult);
use Pod::Usage qw(pod2usage);
use Term::ANSIScreen;

my $VERSION = 1.001;

my (
    $prop,       $dir,   $properties, $width,        $height,
    $res,        $bgcol, $bgalpha,    $legend_title, $no_legend,
    $no_id,      $no_NC, $outdir,     $point_size,   $custom_db,
    $no_heading, $help,
);

my @original_argv = @ARGV;

my $more_cmd = 'more';

# The 'more' executable on Windows does not support the
# '-d' flag, therefore only add it on other platforms.
if ( $^O ne 'MSWin32' )
{
    $more_cmd .= ' -d';
}

# Get the command line options.
GetOptions(
    'prop=s'         => \$prop,
    'dir=s'          => \$dir,
    'properties'     => \$properties,
    'width=f'        => \$width,
    'height=f'       => \$height,
    'res=f'          => \$res,
    'bgcol=s'        => \$bgcol,
    'bgalpha=f'      => \$bgalpha,
    'legend_title=s' => \$legend_title,
    'no_legend'      => \$no_legend,
    'no_id'          => \$no_id,
    'outdir=s'       => \$outdir,
    'point_size=f'   => \$point_size,
    'no_NC'          => \$no_NC,
    'custom_db=s'    => \$custom_db,
    'help'           => \$help,
    '_no_heading'    => \$no_heading,
  )
  or die colored( "\nUsage: $0 -dir directory -prop property\n", 'bold' )
  . "\nTo see all the available options, type:\n"
  . $0
  . colored( ' --help', 'bold' )
  . " | $more_cmd\n\n"
  . "To see a list of all the available amino acid properties, type:\n"
  . $0
  . colored( ' --properties', 'bold' )
  . " | $more_cmd\n\n";

# Determine the directory where the structuprint
# executable is located.
my $rootdir = $0;
$rootdir =~ s/\/?structuprint_frame(.pl|.exe)?$//;
if ( $rootdir eq q{} )
{
    $rootdir = q{.};
}

# If structuprint was called with the --help flag,
# show the documentation and exit.
if ($help)
{
    pod2usage(1);
    exit;
}
elsif ($properties)
{

    # If structuprint was called with the --properties flag,
    # show the available properties and exit.
    local $/ = undef;
    open my $fh, '<', $rootdir . '/props.txt' or die $!;
    my $properties = <$fh>;
    close $fh;
    print $properties;
    exit;
}
else
{

    # Retrieve the available amino acid properties.
    my $properties = amino_acid_properties();

    # Make sure a directory and a property are specified.
    unless ( defined $dir and defined $prop )
    {
        die colored( "\nUsage: $0 -dir directory -prop property\n", 'bold' )
          . "\nTo see all the available options, type:\n"
          . $0
          . colored( ' --help', 'bold' )
          . " | $more_cmd\n\n"
          . "To see a list of all the available amino acid properties, type:\n"
          . $0
          . colored( ' --properties', 'bold' )
          . " | $more_cmd\n\n";
    }

    # Make sure that the specified property actually exists.
    unless ( grep { /^\Q$prop\E$/i } @{$properties} )
    {
        die colored( "ERROR!\n", 'bold' )
          . "No such amino acid property: $prop\n"
          . "\nTo see a list of all available amino acid properties, type:\n"
          . $0
          . colored( ' --properties', 'bold' )
          . " | $more_cmd\n";
    }
}

# Make sure that everything is ok before running.
my ( $input_dir, $output_dir, $files ) = directory_handling();

# Unless structuprint_frame is called from structuprint ...
if ( !( defined $no_heading ) )
{
    my $ascii_logo = << 'END';
      f@                         @.                        @f         @@   
      f@                         @.                                   @@   
@@@@ @@@@@  G@@@  @G  :@   @@@tt@@@@ f@   @;  @@@i   G@@@  @G  i@@i  @@@@f@
@:t@ ,C@i, f@fl@@ @@  ;@  @@iGL i@li L@   @l @@t@@. L@fl@@ @@ l@@@@L i@@i @
@.    f@   @@  ,, @@  ;@ ,@.     @.  L@   @l @L  @C @@  ,, @@ @@  @@  @@  .
@@@@  f@   @@     @@  ;@ :@      @.  L@   @l @t  @@ @@     @@ @@  @@  @@   
   @@ f@   @@     @@  i@ ,@.     @.  f@   @i @f  @C @@     @@ @@  @@  @@  @
@tC@G :@fC @@     f@ti@@  @@iGL  @@L. @@;@@  @@f@@. @@     @@ @@  @@  @@ti.
@@@@   @@@ @G      G@@@    @@@l  ;@@t ,@@@.  @@@@;  @G     @G @@  G@   @@@ 
                                             @t                            
                                             @t                            
                                             @:                               
END

    my $terminal_width;

    # Get the number of columns in the terminal.
    if ( $^O eq 'linux' or $^O eq 'darwin' )
    {
        $terminal_width = `tput cols`;
    }
    elsif ( $^O eq 'MSWin32' )
    {

        # Windows have 80 columns by default, so...
        $terminal_width = 80;
    }

    # Figure out where to place the logo, in order for it to be centered.
    if ( $terminal_width >= 75 )
    {
        $terminal_width = int( ( $terminal_width - 75 ) / 2 );

        my $space = q{};
        for ( 1 .. $terminal_width )
        {
            $space .= q{ };
        }

        $ascii_logo =~ s/^/$space/;
        $ascii_logo =~ s/\n(.)/\n$space$1/g;
        print $ascii_logo;
    }

    # Open an output logfile.
    open STDERR, '>', $output_dir . '/log.txt' or die $!;

    # Print the Copyright + GPL stuff.
    say colored( 'VERSION:', 'bold' ) . q{ } . $VERSION;
    say colored(
'Copyright (C) 2012-15 Kontopoulos D.-G., Vlachakis D., Tsiliki G., Kossida S.',
        'bold'
    );
    say << "END";
\n    This program is free software: you can redistribute it and/or
    modify it under the terms of the GNU General Public License, 
    as published by the Free Software Foundation, either version 
    3 of the License, or (at your option) any later version.
END

    # Wait 3 seconds...
    sleep 3;

    # Print the command with which structuprint was called.
    say "\n" . colored( 'Structuprint was called with this command:', 'bold' );
    say q{   } . used_command() . "\n";

    # Write the command and the version in the logfile.
    say {*STDERR} 'VERSION:' . q{ } . $VERSION;
    say {*STDERR} 'Structuprint was called with this command:';
    say {*STDERR} q{   } . used_command() . "\n";
}
else    # Otherwise, just create a logfile.
{
    open STDERR, '>', $output_dir . '/log.txt' or die $!;
}

# Redefine the method that counts how many models exist in a PDB file.
no warnings 'redefine';
*Bio::PDB::Structure::Molecule::models = sub {
    shift;
    my $fname = shift;
    open( CMDFPDB, "<$fname" )
      or die "Error in models: File $fname not found\n";
    my $count = 0;

    my $end = 'no';
    while (<CMDFPDB>)
    {
        if ( /^END$/ and $end eq 'yes' )
        {
            $end = 'no';
        }
        elsif (/^END/)
        {
            $count++;
            $end = 'yes';
        }
        else
        {
            $end = 'no';
        }
    }
    close CMDFPDB;
    return $count;
};

my ( @n_term, @c_term );

# Initialize some variables to very high/low values.
my $min_value_overall = 99999999;
my $max_value_overall = -99999999;

my $min_x = 99999999;
my $max_x = -99999999;

# Create the initial grid of exposed residues.
my ( $grid, $surface_residue ) = initial_grid();

# Generate a sphere and project it to 2 dimensions.
my ( $min_value, $max_value ) =
  map_projection( sphere( $grid, $surface_residue ) );

# Generate the final figure.
plot_fingerprint( $output_dir . '/miller2' );

# Make sure that a tiff file was created.
if ( !( defined $no_heading ) )
{
    if (    -e $output_dir . '/structuprint.tiff'
        and -s $output_dir . '/structuprint.tiff' )
    {
        say colored( "\nSUCCESS!\n", 'bold' );
        say
"The resulting tiff file is located at:\n   $output_dir/structuprint.tiff\n";
    }
    else
    {
        say colored( "\n\nUh-oh...\n", 'bold' );
        say
"Something went wrong and the structuprint could not be produced! Check the log file!\n";
    }
}

exit;

#---------------------------------------------------------------------#
#    S     U     B     R     O     U     T     I     N     E     S    #
#---------------------------------------------------------------------#

# Connect to the database and retrieve the amino acid properties.
sub amino_acid_properties
{
    my $dbh =
      DBI->connect( 'dbi:SQLite:' . $rootdir . '/amino_acid_properties.db',
        q{}, q{} );

    return $dbh->selectcol_arrayref(
        'SELECT name FROM sqlite_master WHERE type = "table"');
}

# Define the working directory, the input file and the output directory.
sub directory_handling
{
    $outdir //= $dir;

    my ( @paths, @file_dirs );

    # Get the absolute path.
    foreach my $temp_dir ( $dir, $outdir )
    {
        my $full_path = File::Spec->rel2abs($temp_dir);

        opendir my $dh, $full_path
          or die colored( 'ERROR!', 'bold' ) . "\n'$dir' cannot be opened.\n\n";

        my @files;

        # Read the files in the directory.
        while ( readdir $dh )
        {
            if (/_?\d*[.]pdb$/)
            {
                push @files, $_;
            }
        }
        closedir $dh;

        # Make sure that only one pdb file was available.
        if ( $#files > 0 && !( defined $paths[0] ) )
        {
            die "\n"
              . colored( 'ERROR!', 'bold' )
              . "\nThe input directory contains more than one PDB file.\n"
              . "Please provide a directory with only one PDB file inside.\n\n";
        }
        elsif ( $#files == -1 && !( defined $paths[0] ) )
        {
            die "\n"
              . colored( 'ERROR!', 'bold' )
              . "\nNo suitable PDB file in $temp_dir.\n"
              . "Please provide a directory with only one PDB file inside.\n\n";
        }

        push @paths, $full_path;
        push @file_dirs, $files[0] if ( defined $files[0] );
    }
    return $paths[0], $paths[1], \@file_dirs;
}

# Returns the average property values for each grid cell of
# varying dimensions.
sub grouping_grid
{
    my ( $x, $y, $weighting, $grid_dim ) = @_;
    my ( %grid, %grid_weights, %average );

    for ( 0 .. scalar @{$weighting} - 1 )
    {

        # Convert the old coordinates to those in the new grid.
        my $old_x  = $x->[$_];
        my $old_y  = $y->[$_];
        my $x_coor = nearest( $grid_dim, $old_x );

        # If the x coordinate falls outside the minimum, then put
        # the data point at the other end.
        if ( $x_coor < $min_x )
        {
            $x_coor = nhimult( $grid_dim, $max_x );
        }

        my $y_coor = nearest( $grid_dim, $old_y );
        my $weight = $weighting->[$_];

        # If this grid cell was already visited...
        if ( $grid{"$x_coor $y_coor"} )
        {
            $average{"$x_coor $y_coor"} //= 0;

            # Get the average value of the cell.
            $average{"$x_coor $y_coor"} =
              ( ( $grid{"$x_coor $y_coor"} * $grid_weights{"$x_coor $y_coor"} )
                + $weight ) /
              ( $grid{"$x_coor $y_coor"} + 1 );
            $grid_weights{"$x_coor $y_coor"} = $average{"$x_coor $y_coor"};
            $grid{"$x_coor $y_coor"}++;
        }
        else
        {

            # Otherwise, initialize this grid cell.
            $grid{"$x_coor $y_coor"}         = 1;
            $grid_weights{"$x_coor $y_coor"} = $weight;
        }
    }

    return \%grid_weights;
}

# Create the first grid to identify exposed residues.
sub initial_grid
{
    my ( %grid, %amino_acid );

    # Initialize variables to very low/high values.
    my $xmin = 99_999;
    my $ymin = 99_999;
    my $zmin = 99_999;
    my $xmax = -99_999;
    my $ymax = -99_999;
    my $zmax = -99_999;

    # Read the input PDB file and get the number of the available models.
    my $prot      = Bio::PDB::Structure::Molecule->new;
    my $models_no = $prot->models( $input_dir . q{/} . $files->[0] );

    # Raise an error if no models could be found.
    if ( $models_no == 0 )
    {
        if ( !( defined $no_heading ) )
        {
            say colored( "ERROR!\n", 'bold' )
              . 'No models could be found in that PDB file!';
            say 'Please try and fix any format errors.';
            say
              "For example, is there an \"ENDMDL\" keyword after each model?\n";
        }

        say {*STDERR} 'ERROR! No models could be found in that PDB file!';
        say {*STDERR} 'Please try and fix any format errors.';
        say {*STDERR}
          'For example, is there an "ENDMDL" keyword after each model?';

        exit;
    }

    # For every model in the PDB file ...
    for ( 0 .. $models_no - 1 )
    {

        # Read it and ge the number of atoms.
        $prot->read( $input_dir . q{/} . $files->[0], $_ );
        my $atoms_number = $prot->size;

        # Find the coordinates of the first and last atom.
        push @n_term,
          [
            round( $prot->atom(0)->x ),
            round( $prot->atom(0)->y ),
            round( $prot->atom(0)->z )
          ];
        push @c_term,
          [
            round( $prot->atom( $atoms_number - 1 )->x ),
            round( $prot->atom( $atoms_number - 1 )->y ),
            round( $prot->atom( $atoms_number - 1 )->z )
          ];

        # For every atom ...
        for my $atom ( 0 .. $atoms_number - 1 )
        {

            # ... round its coordinates...
            my $atom1  = $prot->atom($atom);
            my $x_coor = round( $atom1->x );
            my $y_coor = round( $atom1->y );
            my $z_coor = round( $atom1->z );

            # ... and put them in the grid.
            if ( !( $grid{"$x_coor $y_coor $z_coor"} ) )
            {
                $grid{"$x_coor $y_coor $z_coor"} = 1;
            }

            # Get the residues at each position.
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

            # Get the current grid dimensions.
            $xmin = min $xmin, $x_coor;
            $xmax = max $xmax, $x_coor;
            $ymin = min $ymin, $y_coor;
            $ymax = max $ymax, $y_coor;
            $zmin = min $zmin, $z_coor;
            $zmax = max $zmax, $z_coor;
        }

    }

    # Return only those empty grid cells that are next to a single protein atom.
    my ( $grid, $surf ) = proximity_check( $xmin, $xmax, $ymin, $ymax, $zmin,
        $zmax, \%grid, \%amino_acid );

    return $grid, $surf;
}

# Project the sphere to 2 dimensions, using the Miller Cylindrical projection.
sub map_projection
{
    my ( $maphash, $radius ) = @_;

    my ( %amino_miller, %miller );

    # Iterate through the sphere data.
    foreach my $key ( keys %{$maphash} )
    {
        if ( $maphash->{$key} == 1 )
        {
            if ( $key =~ /\d+\s+(\S+)\s+(\S+)\s+(\S+)\s+(.+)/ )
            {
                my $x          = $1;
                my $y          = $2;
                my $z          = $3;
                my $amino_acid = $4;

                # Compute the latitude and longitude for each point.
                my $latitude  = atan2 $z, sqrt( $x * $x + $y * $y );
                my $longitude = atan2 $y, $x;

                # Perform a Miller projection.
                my ( $new_x, $new_y ) =
                  miller_projection( $latitude, $longitude );

                # If multiple amino acids fall on the same position,
                # capture that bit of information.
                if ( !( $miller{"$new_x $new_y"} ) )
                {
                    $miller{"$new_x $new_y"}       = 1;
                    $amino_miller{"$new_x $new_y"} = $amino_acid;
                }
                else
                {
                    $amino_miller{"$new_x $new_y"} .= q{, } . $amino_acid;
                }
            }
        }
    }

    # Calculate the percentage of residues for each location.
    foreach ( keys %amino_miller )
    {
        $amino_miller{$_} = residue_percentage_reformat( $amino_miller{$_} );
    }

    foreach my $prot (@n_term)
    {
        my $x = $prot->[0];
        my $y = $prot->[1];
        my $z = $prot->[2];

        # Compute the latitude and longitude for each point.
        my $latitude  = atan2 $y, sqrt( $x * $x + $z * $z );
        my $longitude = atan2 $x, $z;

        # Perform a Miller projection.
        my ( $new_x, $new_y ) = miller_projection( $latitude, $longitude );

        $prot->[0] = $new_x;
        $prot->[1] = $new_y;
    }

    foreach my $prot (@c_term)
    {
        my $x = $prot->[0];
        my $y = $prot->[1];
        my $z = $prot->[2];

        # Compute the latitude and longitude for each point.
        my $latitude  = atan2 $y, sqrt( $x * $x + $z * $z );
        my $longitude = atan2 $x, $z;

        # Perform a Miller projection.
        my ( $new_x, $new_y ) = miller_projection( $latitude, $longitude );

        $prot->[0] = $new_x;
        $prot->[1] = $new_y;
    }

    my $dbh;

    # Connect to the database and fetch the hash of the property of choice.
    if ( defined $custom_db && -e $custom_db )
    {
        $dbh = DBI->connect( "dbi:SQLite:$custom_db", q{}, q{} );
    }
    else
    {
        $dbh =
          DBI->connect( 'dbi:SQLite:' . $rootdir . '/amino_acid_properties.db',
            q{}, q{} );
    }
    my $db_sel = $dbh->prepare("SELECT * FROM $prop");
    $db_sel->execute();
    my $properties = $db_sel->fetchall_hashref('Amino_Acid');
    $dbh->disconnect();

    # Find the maximum and minimum values for this property.
    foreach ( keys %{$properties} )
    {
        $max_value_overall = max $max_value_overall,
          $properties->{$_}->{'Value'};
        $min_value_overall = min $min_value_overall,
          $properties->{$_}->{'Value'};
    }

    my ( @x, @y, @weight );

   # Get the data points at each coordinate and their amino acid property value.
    foreach my $key ( keys %miller )
    {
        if ( $miller{$key} == 1 )
        {
            if ( $key =~ /(\S+)\s+(\S+)/ )
            {
                my $x = $1;
                $x = sprintf '%23.20f', $x;
                my $y = $2;
                $y = sprintf '%23.20f', $y;

                push @x, $x;
                push @y, $y;
                push @weight,
                  property_value( $amino_miller{$key}, $properties );
            }
        }
    }

    # Smoothen the map by calculating the property value for each
    # grid cell, with dimensions that vary from 0.001 x 0.001 to
    # 0.5 x 0.5.
    my @runs;
    for ( my $dimensions = 0.001 ; $dimensions <= 0.5 ; $dimensions += 0.001 )
    {
        my ($grid) = grouping_grid( \@x, \@y, \@weight, $dimensions );
        push @runs, $grid;
    }

    my $min_value = 50000;
    my $max_value = -50000;

    # Open the temporary miller projection file.
    open my $fh_pl2, '>', $output_dir . '/miller2'
      or die "Cannot create $output_dir/miller2.\n";

    foreach my $key ( keys %miller )
    {

        # If a data point is defined at this position...
        if ( $miller{$key} == 1 )
        {
            if ( $key =~ /(\S+)\s+(\S+)/ )
            {

                # Extract the x and y coordinates.
                my $x = $1;
                my $y = $2;

                my $amino_acid = 0;

                my $dimension = 0.001;

                # Get the average (smoothed) value across all runs.
                for ( 0 .. $#runs )
                {
                    my $temp_x = nearest( $dimension, $x );

                    if ( $temp_x < $min_x )
                    {
                        $temp_x = nhimult( $dimension, $max_x );
                    }

                    my $temp_y = nearest( $dimension, $y );

                    $amino_acid += $runs[$_]->{"$temp_x $temp_y"};
                    $dimension  += 0.001;
                }
                $amino_acid /= ( $#runs + 1 );
                $amino_acid //= 0;

                # Get the minimum and maximum property values.
                $min_value = min( $amino_acid, $min_value );
                $max_value = max( $amino_acid, $max_value );

                say {$fh_pl2} "$x $y $amino_acid";
            }
        }
    }
    close $fh_pl2;
    return $min_value, $max_value;
}

# Move every data point to the surface of the sphere.
sub move_to_surface
{
    my ( $radius, $x, $y, $z ) = @_;

    # This will only fail for the very unlikely scenario
    # of x = y = z = 0.
    if ( $x == 0 and $y == 0 and $z == 0 )
    {
        return 'NA';
    }
    else
    {
        my $ratio = $radius / sqrt( $x * $x + $y * $y + $z * $z );
        return $x * $ratio, $y * $ratio, $z * $ratio;
    }
}

# Call the R interpreter to plot the resulting figure.
sub plot_fingerprint
{
    my ($miller_file) = @_;

    my ( $R, $R_code_win, $win_fh );

    # Necessary changes for Windows and OS X ... -__-
    if ( $^O eq 'MSWin32' )
    {
        my $temp_R_dir    = $output_dir;
        my $temp_R_miller = $miller_file;
        $temp_R_dir =~ s/\\/\//g;
        $temp_R_miller =~ s/\\/\//g;

        $R_code_win = $output_dir . '/R_code_structuprint.R';
        open $win_fh, '>', $R_code_win or die $!;
        print {$win_fh} << "END";
		directory <- "$temp_R_dir/"
		miller_file <- "$temp_R_miller"
END
    }
    elsif ( $^O eq 'darwin' )
    {
        $ENV{'DYLD_LIBRARY_PATH'} = $rootdir . '/R_libs/';
        $R =
          Statistics::R->new(
            bin => $rootdir . '/R/R.framework/Versions/3.2/Resources/bin/R' );
        $R->run('options("bitmapType" = "cairo")');

        $R->set( 'directory',   $output_dir . q{/} );
        $R->set( 'miller_file', $miller_file );
    }
    else
    {
        $R = Statistics::R->new();
        $R->set( 'directory',   $output_dir . q{/} );
        $R->set( 'miller_file', $miller_file );
    }

    # Decide if the ID number will be printed on the figure.
    my $id_number;
    if ( $files->[0] =~ /_(\d+)[.]pdb$/ && !($no_id) )
    {
        $id_number = $1;
    }
    else
    {
        $id_number = q{};
    }

    # Decide on the width and height of the image...
    if ( !defined $width && !defined $height )
    {
        $width = 90;
        if ($no_legend)
        {
            $height = 66;
        }
        else
        {
            $height = 76.56;
        }
    }
    elsif ( defined $width && !defined $height )
    {
        if ($no_legend)
        {
            $height = $width / 1.3639;
        }
        else
        {
            $height = $width / 1.3639 * 1.16;
        }
    }
    elsif ( defined $height && !defined $width )
    {
        if ($no_legend)
        {
            $width = $height * 1.3639;
        }
        else
        {
            $width = $height * 1.3639 / 1.16;
        }
    }
    else
    {
        if ($no_legend)
        {
            if ( ( $width / $height ) < 1.29 or ( $width / $height ) > 1.43 )
            {
                say {*STDERR}
                  'Warning! The width to height ratio is not close to 1.3639.';
                say {*STDERR} "The map will be distorted!\n";
            }
        }
        else
        {
            if (   ( $width / $height * 1.16 ) < 1.29
                or ( $width / $height * 1.16 ) > 1.43 )
            {
                say {*STDERR}
'Warning! The width to height ratio (excluding the legend) is not close to 1.3639.';
                say {*STDERR} "The map will be distorted!\n";
            }
        }
    }
    $res //= 100;

    # Background color and transparency...
    my ( $R_color, $legend_bg );
    my $tiff_transparency = q{};

    # Match all R's default colors and nothing else.
    my $R_colors_regex = qr/a(liceblue|ntiquewhite(1|2|3|4)|
quamarine(1|2|3|4)|zure(1|2|3|4))|b(eige|isque(1|2|3|4)|l(a(ck|nchedalmond)|
ue(1|2|3|4|violet))|rown(1|2|3|4)|urlywood(1|2|3|4))|c(adetblue(1|2|3|4)|
h(artreuse(1|2|3|4)|ocolate(1|2|3|4))|or(al(1|2|3|4)|n(flowerblue|
silk(1|2|3|4)))|yan(1|2|3|4))|d(ark(blue|cyan|g(oldenrod(1|2|3|4)|
r(ay|e(en|y)))|khaki|magenta|o(livegreen(1|2|3|4)|r(ange(1|2|3|4)|
chid(1|2|3|4)))|red|s(almon|eagreen(1|2|3|4)|late(blue|gr(ay(1|2|3|4)|
ey)))|turquoise|violet)|eep(pink(1|2|3|4)|skyblue(1|2|3|4))|imgr(ay|ey)|
odgerblue(1|2|3|4))|f(irebrick(1|2|3|4)|loralwhite|orestgreen)|g(ainsboro|
hostwhite|old(1|2|3|4|enrod(1|2|3|4))|r(ay(0|1(00|1|2|3|4|5|6|7|8|9)|
2(0|1|2|3|4|5|6|7|8|9)|3(0|1|2|3|4|5|6|7|8|9)|4(0|1|2|3|4|5|6|7|8|9)|
5(0|1|2|3|4|5|6|7|8|9)|6(0|1|2|3|4|5|6|7|8|9)|7(0|1|2|3|4|5|6|7|8|9)|
8(0|1|2|3|4|5|6|7|8|9)|9(0|1|2|3|4|5|6|7|8|9))|e(en(1|2|3|4|yellow)|y(0|
1(00|1|2|3|4|5|6|7|8|9)|2(0|1|2|3|4|5|6|7|8|9)|3(0|1|2|3|4|5|6|7|8|9)|
4(0|1|2|3|4|5|6|7|8|9)|5(0|1|2|3|4|5|6|7|8|9)|6(0|1|2|3|4|5|6|7|8|9)|
7(0|1|2|3|4|5|6|7|8|9)|8(0|1|2|3|4|5|6|7|8|9)|9(0|1|2|3|4|5|6|7|8|9)))))|
ho(neydew(1|2|3|4)|tpink(1|2|3|4))|i(ndianred(1|2|3|4)|vory(1|2|3|4))|
khaki(1|2|3|4)|l(a(venderblush(1|2|3|4)|wngreen)|emonchiffon(1|2|3|4)|
i(ght(blue(1|2|3|4)|c(oral|yan(1|2|3|4))|g(oldenrod(1|2|3|4|yellow)|
r(ay|e(en|y)))|pink(1|2|3|4)|s(almon(1|2|3|4)|eagreen|kyblue(1|2|3|4)|
late(blue|gr(ay|ey))|teelblue(1|2|3|4))|yellow(1|2|3|4))|megreen|nen))|
m(a(genta(1|2|3|4)|roon(1|2|3|4))|edium(aquamarine|blue|orchid(1|2|3|4)|
purple(1|2|3|4)|s(eagreen|lateblue|pringgreen)|turquoise|violetred)|
i(dnightblue|ntcream|styrose(1|2|3|4))|occasin)|nav(ajowhite(1|2|3|4)|
yblue)|o(l(dlace|ivedrab(1|2|3|4))|r(ange(1|2|3|4|red(1|2|3|4))|
chid(1|2|3|4)))|p(a(le(g(oldenrod|reen(1|2|3|4))|turquoise(1|2|3|4)|
violetred(1|2|3|4))|payawhip)|e(achpuff(1|2|3|4)|ru)|ink(1|2|3|4)|
lum(1|2|3|4)|owderblue|urple(1|2|3|4))|r(ed(1|2|3|4)|o(sybrown(1|2|3|4)|
yalblue(1|2|3|4)))|s(a(ddlebrown|lmon(1|2|3|4)|ndybrown)|ea(green(1|2|3|4)|
shell(1|2|3|4))|ienna(1|2|3|4)|kyblue(1|2|3|4)|late(blue(1|2|3|4)|
gr(ay(1|2|3|4)|ey))|now(1|2|3|4)|pringgreen(1|2|3|4)|teelblue(1|2|3|4))|
t(an(1|2|3|4)|histle(1|2|3|4)|omato(1|2|3|4)|urquoise(1|2|3|4))|
violetred(1|2|3|4)|wh(eat(1|2|3|4)|itesmoke)|yellow(1|2|3|4|green)/x;

    if ( !( defined $bgcol ) )
    {
        $bgcol = '#000000';
    }
    elsif ( lc($bgcol) !~ $R_colors_regex
        and $bgcol !~ /^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/ )
    {
        say {*STDERR} "Warning! '$bgcol' is not a color that R can understand.";
        say {*STDERR} "Setting the background color to '#000000'.\n";
        $bgcol = '#000000';
    }

    if ( !defined $bgalpha )
    {
        $R_color   = "fill = '$bgcol'";
        $legend_bg = 'fill = "white"';
    }
    elsif ( defined $bgalpha && ( $bgalpha < 0 || $bgalpha > 1 ) )
    {
        say {*STDERR}
          'Warning! The alpha value (-bgalpha) needs to be between 0 and 1.';
        say {*STDERR} "Setting it to 1\n";
        $R_color = "fill = '$bgcol'";

        $legend_bg = 'fill = "white"';
    }
    elsif ( $bgalpha == 0 )
    {
        $R_color           = 'fill = NA';
        $legend_bg         = 'fill = NA';
        $tiff_transparency = ', bg = "transparent"';
    }
    else
    {
        $legend_bg = 'fill = "white"';
        $R_color   = "fill = add.alpha('$bgcol', $bgalpha)";
    }

    # If the user did not specify a title for the legend,
    # just use the name of the amino acid property.
    $legend_title //= $prop;

    # Point size...
    if ( ( defined $point_size && $point_size <= 0 ) || !defined $point_size )
    {
        $point_size = 1;
    }

    my $R_commands;

    # Load the necessary R packages...
    if ( -d $rootdir . '/R_pkgs/' )
    {
        $R_commands = << "END";
	library(ggplot2, lib.loc = '$rootdir/R_pkgs/')
	library(scales, lib.loc = '$rootdir/R_pkgs/')
	library(labeling, lib.loc = '$rootdir/R_pkgs/')
END
    }
    else
    {
        $R_commands = << 'END';
	library(ggplot2)
	library(scales)
	library(labeling)
END
    }

    # Default housekeeping R code...
    $R_commands .= << "END";
	library(grid)
	
	add.alpha <- function(col, alpha=1){
	apply(sapply(col, col2rgb)/255, 2,
	function(x)
	rgb(x[1], x[2], x[3], alpha=alpha))
	} 
		
	ending <- "structuprint.tiff"
	name <- paste(directory, ending, sep = "")
	tiff(filename = name, width = $width, height = $height, units = "mm", 
		res = $res, compression = 'lzw' $tiff_transparency)
	
	miller <- read.table(miller_file)
	miller <- miller[with(miller, order(V1, V2, V3)),]
	x <- as.vector(miller\$V1)
	x <- as.numeric(x)
	y <- as.vector(miller\$V2)
	y <- as.numeric(y)
	$prop <- as.vector(miller\$V3)
	$prop <- as.numeric($prop)
	
	max_prop <- $max_value_overall
	min_prop <- $min_value_overall
	
	if ( min_prop < 0 && max_prop > 0 )
	{	
		breaks <- c(floor(-max(abs(c(min_prop, max_prop)))), 
				0, 
				ceiling(max(abs(c(min_prop, max_prop)))))
		
		limits <- c(floor(-max(abs(c(min_prop, max_prop)))), 
			ceiling(max(abs(c(min_prop, max_prop)))))
		
		mycols <- c('#b2182b', '#ef8a62', '#fddbc7', '#f7f7f7', '#d1e5f0', 
			'#67a9cf', '#2166ac')
	} else if ( (min_prop >= 0 && max_prop > 0) || (min_prop < 0 && max_prop <= 0))
	{
		breaks <- c(floor(min(c(min_prop, max_prop))), 
				(ceiling(max(c(min_prop, max_prop))) + 
				floor(min(c(min_prop, max_prop))))/2, 
				ceiling(max(c(min_prop, max_prop))))
				
		limits <- c(floor(min(c(min_prop, max_prop))), 
			ceiling(max(c(min_prop, max_prop))))
		
		if (min_prop >= 0)
		{
			mycols <- c('white', '#deebf7', '#c6dbef', '#9ecae1', '#6baed6', 
				'#4292c6', '#2171b5')
		} else
		{
			mycols <- c('#cb181d', '#ef3b2c', '#fb6a4a', '#fc9272', '#fcbba1', 
				'#fee0d2', 'white')
		}
	}
	
	height_sp <- $height
	height_legend <- height_sp * 0.02
	font_number <- as.integer(height_sp * 0.1)
	
	dat <- data.frame(cond = $prop, xvar = x, yvar = y)
END

    # If we are on Windows, write the R code to a file,
    # instead of running it directly.
    if ( $^O ne 'MSWin32' )
    {
        $R->run($R_commands);
    }
    else
    {
        print {$win_fh} $R_commands;
    }

    my $annotate_text = q{};

    # Will we show the -N and -C termini?
    if ( !$no_NC )
    {
        my $counter = 1;
        foreach my $prot (@n_term)
        {
            if ( $prot->[0] eq 'NA' or $prot->[1] eq 'NA' )
            {
                next;
            }

            $annotate_text .=
                '+ annotate("text", x = '
              . $prot->[0]
              . ', y = '
              . $prot->[1]
              . ', label = ';

            if ( $#n_term > 0 )
            {
                $annotate_text .= '"N[' . $counter . ']", parse = TRUE';
                $counter++;
            }
            else
            {
                $annotate_text .= '"N"';
            }

            $annotate_text .=
              ', color = "forestgreen", size = as.integer(font_number * 0.8)) ';
        }

        $counter = 1;
        foreach my $prot (@c_term)
        {
            if ( $prot->[0] eq 'NA' or $prot->[1] eq 'NA' )
            {
                next;
            }

            $annotate_text .=
                '+ annotate("text", x = '
              . $prot->[0]
              . ', y = '
              . $prot->[1]
              . ', label = ';

            if ( $#c_term > 0 )
            {
                $annotate_text .= '"C[' . $counter . ']", parse = TRUE';
                $counter++;
            }
            else
            {
                $annotate_text .= '"C"';
            }

            $annotate_text .=
              ', color = "forestgreen", size = as.integer(font_number * 0.8)) ';
        }
    }

    # Code for a figure without a legend.
    if ($no_legend)
    {
        $R_commands = << "END";
		ggplot(dat, aes(x = x, y = y, color = $prop)) + 
		ylim(-2.30, 2.30) + xlim(-3.14, 3.14) +
		geom_point(shape = 20, size = $point_size) + 
		scale_colour_gradientn(
			limits = limits, 
			colours = mycols, breaks = breaks, 
			values = seq(0, 1, 0.025), 
			guide=guide_colourbar(title.position="top")) + 
		theme(panel.background = element_rect($R_color),
			panel.grid.major.x = element_blank(), 
			panel.grid.major.y = element_blank(), 
			panel.grid.minor.x = element_blank(), 
			panel.grid.minor.y = element_blank(),
			legend.title = element_text(size=font_number), 
			legend.text = element_text(size=font_number), 
			legend.key.size = unit(height_legend, "mm"),
			axis.text.x = element_blank(), 
			axis.text.y = element_blank(),
			axis.title.x = element_blank(),
			axis.title.y = element_blank(),
			axis.ticks.x = element_blank(),
			axis.ticks.length = unit(0,"null"),
			legend.position = "none",
			legend.margin = unit(0, "lines"),
			axis.ticks.margin = unit(0,"null"),
			plot.background = element_rect($legend_bg),
			plot.margin = unit(c(0.05,0.05,-0.2,-0.2), "cm"))  +
			annotate("text", x = 3, 
				y = -2.2, 
				size = as.integer(font_number * 0.7), label = "$id_number", color = 'purple') $annotate_text
END
    }
    else    # Code for a figure with a legend.
    {
        $R_commands = << "END";
		ggplot(dat, aes(x = x, y = y, color = $prop)) + 
		ylim(-2.30, 2.30) + xlim(-3.14, 3.14) +
		geom_point(shape = 20, size = $point_size) + 
		scale_colour_gradientn(
			limits = limits, 
			colours = mycols, breaks = breaks, 
			values = seq(0, 1, 0.025),
			guide=guide_colourbar(barwidth = as.integer(1/10*$width), title.position="top")) + 
		theme(panel.background = element_rect($R_color), 
			panel.grid.major.x = element_blank(), 
			panel.grid.major.y = element_blank(), 
			panel.grid.minor.x = element_blank(), 
			panel.grid.minor.y = element_blank(),
			legend.title = element_text(size=font_number), 
			legend.text = element_text(size=font_number), 
			legend.key.size = unit(height_legend, "mm"),
			axis.text.x = element_blank(), 
			axis.text.y = element_blank(),
			axis.title.x = element_blank(),
			axis.title.y = element_blank(),
			axis.ticks.x = element_blank(),
			axis.ticks.length = unit(0,"null"),
			legend.position = "bottom",
			legend.margin = unit(0, "lines"),
			axis.ticks.margin = unit(0,"null"),
			legend.background = element_rect($legend_bg),
			plot.background = element_rect($legend_bg),
			plot.margin = unit(c(0.05,0.05,-0.3,-0.2), "cm"))  +
			annotate("text", x = 3,
				y = -2.2, 
				size = as.integer(font_number * 0.7), label = "$id_number", color = 'purple') + 
			labs(colour = "$legend_title", x = NULL) $annotate_text
END
    }

    # Windows again. ;-___-
    if ( $^O ne 'MSWin32' )
    {
        $R->run($R_commands);
    }
    else
    {
        print {$win_fh} $R_commands;
        close $win_fh;

        system $rootdir . '\R\bin\Rscript\ ' . $R_code_win;
        unlink $R_code_win;
    }

    # Delete the temporary Miller projection file.
    unlink $miller_file;
    return 0;
}

# Compute the value of the property of choice for each position.
sub property_value
{
    my ( $residue, $properties ) = @_;

    my %aminos;

    # Get all the residues.
    while ( $residue =~ /\w/ )
    {
        if ( $residue =~ /(\d+[.]\d+)%\s(\w+)[,]?\s?/ )
        {
            $aminos{$2} = $1 / 100;
            $residue = $';
        }
    }

    my $value = 0;

    # Calculate the resulting value (if available).
    foreach my $key ( keys %aminos )
    {
        if ( defined $properties->{$key}->{'Value'} )
        {
            $value += $properties->{$key}->{'Value'} * $aminos{$key};
        }
        else
        {
            say {*STDERR}
'Warning! A residue (?) for which there is no recorded value was found: '
              . $key;
            say {*STDERR}
              "Its value was set to 0; that may lead to wrong results!\n";
        }
    }

    return $value;
}

# Select empty grid cells located next to one and only atom of the protein.
sub proximity_check
{
    my ( $xmin, $xmax, $ymin, $ymax, $zmin, $zmax, $grid, $amino_acid ) = @_;

    my %surface_residue;

    # Iterate through the grid elements.
    for my $current_x ( $xmin - 1 .. $xmax + 1 )
    {
        for my $current_y ( $ymin - 1 .. $ymax + 1 )
        {
            for my $current_z ( $zmin - 1 .. $zmax + 1 )
            {
                if ( !( $grid->{"$current_x $current_y $current_z"} ) )
                {

                    # Prepare all possible steps to a nearby grid cell.
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

                        # Check for existing protein atoms nearby.
                        if ( $grid->{ $neighbors[$_] } )
                        {
                            $sum += $grid->{ $neighbors[$_] };
                            $residue //= $amino_acid->{ $neighbors[$_] };
                        }

                        last if $sum > 1;
                    }

                    # Select only those cells having a single protein
                    # atom next to them.
                    if ( $sum == 1 )
                    {
                        $grid->{"$current_x $current_y $current_z"} = 0;

                        # Format the percentage of the nearby residue.
                        $surface_residue{"$current_x $current_y $current_z"} =
                          residue_percentage_format($residue);
                    }
                }
            }
        }
    }
    return $grid, \%surface_residue;
}

# Format the percentage of residues for a position.
sub residue_percentage_format
{
    my ($residue) = @_;

    my @amino;

    #G et all the residues.
    while ( $residue =~ /\w/ )
    {
        if ( $residue =~ /(\w+)/ )
        {
            push @amino, $1;
            $residue = $';
        }
    }

    my %freq;

    # Count the occurences for each residue.
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

    # Calculate the percentage.
    foreach my $key ( keys %freq )
    {
        $freq{$key} = sprintf '%6.2f',
          ( ( $freq{$key} / ( $#amino + 1 ) ) * 100 );
        $freq{$key} .= q{%};
    }
    $residue = q{};

    # Format the result.
    foreach my $key ( keys %freq )
    {
        $residue .= $freq{$key} . q{ } . $key . q{, };
    }
    $residue =~ s/, $//;
    return $residue;
}

# Re-calculate the percentage of residues.
sub residue_percentage_reformat
{
    my ($residue) = @_;

    my %aminos;

    # Get all the residues.
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

    # Add their per cent values.
    foreach my $key ( keys %aminos )
    {
        $sum += $aminos{$key};
    }

    # Transform the sum to a percentage.
    foreach my $key ( keys %aminos )
    {
        $aminos{$key} = sprintf '%6.2f', ( ( $aminos{$key} / $sum ) * 100 );
        $aminos{$key} .= q{%};
    }
    $residue = q{};

    # Format the result.
    foreach my $key ( sort { $a cmp $b } keys %aminos )
    {
        $residue .= $aminos{$key} . q{ } . $key . q{, };
    }
    $residue =~ s/, $//;
    return $residue;
}

# Create a sphere out of the x, y, z coordinates of the (dummy) atoms.
sub sphere
{
    my ( $grid, $surface_residue ) = @_;

    my $center_x = 0;
    my $center_y = 0;
    my $center_z = 0;

    my $atom_counter = 0;

    # Find the center of mass.
    foreach my $key ( keys %{$grid} )
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
    $center_x = $center_x / $atom_counter;
    $center_y = $center_y / $atom_counter;
    $center_z = $center_z / $atom_counter;

    my $radius = 0;

    # Compute the distance of each atom from the center of mass
    # to identify the maximum distance (= radius).
    my %distance;
    foreach my $key ( keys %{$grid} )
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

    # Get the properties from the database.
    my $dbh;
    if ( defined $custom_db && -e $custom_db )
    {
        $dbh = DBI->connect( "dbi:SQLite:$custom_db", q{}, q{} );
    }
    else
    {
        $dbh =
          DBI->connect( 'dbi:SQLite:' . $rootdir . '/amino_acid_properties.db',
            q{}, q{} );
    }
    my $db_sel = $dbh->prepare("SELECT * FROM $prop");
    $db_sel->execute();
    my $properties = $db_sel->fetchall_hashref('Amino_Acid');
    $dbh->disconnect();

    my %map_hash;
    my $atom_number = 1;
    foreach my $key ( keys %{$grid} )
    {
        if ( $grid->{$key} == 0 )
        {
            if ( $key =~ /([-]?\d+)\s+([-]?\d+)\s+([-]?\d+)/ )
            {

                # Center the coordinates according to the center of mass.
                my $x = $1 - $center_x;
                my $y = $2 - $center_y;
                my $z = $3 - $center_z;

                # Move the data point to the surface of the sphere.
                ( $x, $y, $z ) = move_to_surface( $radius, $x, $y, $z );

                # Store the position of the data point in the map.
                if ( $x ne 'NA' )
                {
                    $min_x = min( $min_x, $x );
                    $max_x = max( $max_x, $x );

                    $x = sprintf '%7.2f', $x;
                    $y = sprintf '%7.2f', $y;
                    $z = sprintf '%7.2f', $z;

                    my $id = sprintf '%6d', $atom_number;
                    $map_hash{"$id $x $y $z   $surface_residue->{$key}"} = 1;

                    $atom_number++;
                }
            }
        }
    }

    # Move the -N and -C termini to the appropriate position on the surface.
    foreach my $prot (@n_term)
    {
        my $x = $prot->[0] - $center_x;
        my $y = $prot->[1] - $center_y;
        my $z = $prot->[2] - $center_z;

        ( $x, $y, $z ) = move_to_surface( $radius, $x, $y, $z );

        $prot->[0] = $x;
        $prot->[1] = $y;
        $prot->[2] = $z;
    }

    foreach my $prot (@c_term)
    {
        my $x = $prot->[0] - $center_x;
        my $y = $prot->[1] - $center_y;
        my $z = $prot->[2] - $center_z;

        ( $x, $y, $z ) = move_to_surface( $radius, $x, $y, $z );

        $prot->[0] = $x;
        $prot->[1] = $y;
        $prot->[2] = $z;
    }

    return \%map_hash, $radius;
}

# Identify the command that was used to call the program.
sub used_command
{
    my $command;
    if ( $0 =~ /\s/ )
    {
        $command = q{"} . $0 . q{" };
    }
    else
    {
        $command = $0 . q{ };
    }

    foreach (@original_argv)
    {
        if ( /\s/ or /#/ )
        {
            $command .= q{"} . $_ . q{" };
        }
        else
        {
            $command .= $_ . q{ };
        }
    }
    return $command;
}

__END__

=head1 NAME

structuprint_frame - utility for generation of 2D maps of protein surfaces (structuprints)

=head1 SYNOPSIS

B<structuprint_frame> B<-prop> PROPERTY
                   B<-dir> INPUT_DIRECTORY
                   [B<-outdir> OUTPUT_DIRECTORY]
                   [B<-custom_db> PATH_TO_DATABASE]
                   [B<-height> HEIGHT] [B<-width> WIDTH]
                   [B<-res> PPI_NUMBER]
                   [B<-point_size> SIZE]
                   [B<-bgcol> HEX_COLOR|COLOR_NAME] [B<-bgalpha> ALPHA_VALUE]
                   [B<-legend_title> TITLE]
                   [B<--no_ID>] [B<--no_legend>] [B<--no_NC>]
                   [B<--help>]
                   [B<--properties>]

=head1 DESCRIPTION

Structuprint_frame is a tool for generating two-dimensional maps of protein surfaces. Given an input directory with a PDB file, Structuprint_frame will execute an algorithm that involves i) creating a mould of the structure, ii) transforming the mould into a sphere and iii) projecting it on two dimensions using the Miller cylindrical projection.

Refer to the documentation for more details about the core algorithm.

=head1 OPTIONS

=over 1

=item B<-bgalpha> ALPHA_VALUE

=over 4

Set the transparency level of the background color from 0 (fully transparent) to 1 (no transparency). Default value: 1

=back

=item B<-bgcol> HEX_COLOR|COLOR_NAME

=over 4

Set the background color either as an HTML hex color or as a color name that R understands. Default: #000000

=back

=item B<-custom_db> PATH_TO_DATABASE

=over 4

Provide the path to a custom SQLite database of amino acid properties. For information about the schema, refer to the documentation.

=back

=item B<-dir> INPUT_DIRECTORY

=over 4

Specify the directory location of the input PDB file. The directory must have no more than a single PDB file inside it.

=back

=item B<-height> HEIGHT

=over 4

Specify the height of the structuprint in mm. If only B<-width> is set, then Structuprint_frame will automatically adjust the height to the appropriate value. Default values: 76.56 by default or 66 when the B<--no_legend> flag is active.

=back

=item B<--help>

=over 4

Show the available options and exit.

=back

=item B<-legend_title> TITLE

=over 4

Specify the title of the legend. If this is not set, then Structuprint_frame will use the name of the selected property as the legend title.

=back

=item B<--no_ID>

=over 4

Remove the ID number from the structuprint.

=back

=item B<--no_legend>

=over 4

Remove the legend from the structuprint.

=back

=item B<--no_NC>

=over 4

Do not show the N/C-termini positions in the structuprint.

=back

=item B<-outdir> OUTPUT_DIRECTORY

=over 4

Specify the location for Structuprint_frame's output files. If this is not set, Structuprint_frame will write its output in the input directory.

=back

=item B<-point_size> SIZE

=over 4

Specify the size of the data points in the structuprint. Default value: 1

=back

=item B<-prop> PROPERTY

=over 4

Specify the amino acid property based on which the structuprint will be colored.

=back

=item B<--properties>

=over 4

List all the amino acid properties available in the default database along with their explanation, and quit.

=back

=item B<-res> PPI_NUMBER

=over 4

Specify the resolution of the structuprint in pixels per inch. Default value: 100

=back

=item B<-width> WIDTH

=over 4

Specify the width of the structuprint in mm. If only B<-height> is set, then Structuprint_frame will automatically adjust the width to the appropriate value. Default value: 90

=back

=back

=head1 EXAMPLE

structuprint_frame -dir './Data/' -prop FCharge -legend_title 'Charge' -width 250 -res 300 -outdir './Results/'

=head1 SEE ALSO

=over 1

=item B<Basic R colors> - http://www.stat.columbia.edu/~tzheng/files/Rcolor.pdf

=back

=head1 AUTHORS

=over 1

=item B<Dimitrios - Georgios Kontopoulos>

<d.kontopoulos13@imperial.ac.uk> or <dgkontopoulos@member.fsf.org> or <dgkontopoulos@gmail.com>

=item B<Dimitrios Vlachakis>

<dvlachakis@bioacademy.gr>

=item B<Georgia Tsiliki>

<gtsiliki@central.ntua.gr>

=item B<Sofia Kossida>

<sofia.kossida@igh.cnrs.fr>

=back

=head1 COPYRIGHT AND LICENSE

Copyright 2012-15 Dimitrios - Georgios Kontopoulos, Dimitrios Vlachakis, Georgia Tsiliki, Sofia Kossida

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

For more information, visit http://www.gnu.org/licenses/.

=cut
