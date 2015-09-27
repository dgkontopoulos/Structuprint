#!/usr/bin/env perl

use strict;
use warnings;

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
        eval 'use IPC::ShareLite';
        die "$@" if $@;

        eval 'use Parallel::ForkManager';
        die "$@" if $@;
    }
}

use feature qw(say);

use DBI;
use File::Spec;
use File::Copy qw(copy);
use Getopt::Long;
use Imager;
use Imager::File::TIFF;
use Imager::File::GIF;
use Pod::Usage qw(pod2usage);
use Term::ANSIScreen;
use Term::ProgressBar;

my $VERSION = 1.001;

my (
    $prop,          $dir,          $properties, $nthreads,  $delay,
    $nloops,        $width,        $height,     $bgcol,     $bgalpha,
    $res,           $legend_title, $no_legend,  $no_id,     $no_NC,
    $del_temp_dirs, $outdir,       $point_size, $custom_db, $help,
);

my @original_argv = @ARGV;

my $more_cmd = 'more';
if ( $^O ne 'MSWin32' )
{
    $more_cmd .= ' -d';
}

# Get command line options.
GetOptions(
    'prop=s'         => \$prop,
    'dir=s'          => \$dir,
    'properties'     => \$properties,
    'nthreads=i'     => \$nthreads,
    'delay=i'        => \$delay,
    'nloops=i'       => \$nloops,
    'width=f'        => \$width,
    'height=f'       => \$height,
    'bgcol=s'        => \$bgcol,
    'bgalpha=f'      => \$bgalpha,
    'res=f'          => \$res,
    'legend_title=s' => \$legend_title,
    'no_legend'      => \$no_legend,
    'no_id'          => \$no_id,
    'del_temp_dirs'  => \$del_temp_dirs,
    'outdir=s'       => \$outdir,
    'point_size=f'   => \$point_size,
    'no_NC'          => \$no_NC,
    'custom_db=s'    => \$custom_db,
    'help'           => \$help,
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

my $rootdir = $0;
$rootdir =~ s/\/?structuprint(.pl|.exe)?$//;
if ( $rootdir eq q{} )
{
    $rootdir = q{.};
}

if ($help)
{
    pod2usage(1);
    exit;
}
elsif ($properties)
{
    local $/ = undef;
    open my $fh, '<', $rootdir . '/props.txt' or die $!;
    my $properties = <$fh>;
    close $fh;
    print $properties;
    exit;
}
else
{
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

    # Make sure that the specified property actually exists.#
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

# Decide on whether to show the ASCII logo or not.
my $terminal_width;

if ( $^O eq 'linux' or $^O eq 'darwin' )
{
    $terminal_width = `tput cols`;
}
elsif ( $^O eq 'MSWin32' )
{
    $terminal_width = 80;
}

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

say colored( "VERSION:", 'bold' ) . q{ } . $VERSION;
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

sleep 3;

say "\n" . colored( 'Structuprint was called with this command:', 'bold' );
say q{   } . used_command() . "\n";

my ( $files, $prefix );
( $dir, $files, $prefix ) = directory_handling();

my $offset = 0;
if ( $files->[0] == 0 )
{
    $offset = 1;
}

$outdir //= $dir;
mkdir $outdir . '/final_output'
  or die colored( 'ERROR!', 'bold' )
  . "\nA directory could not be created at '$outdir/'.
Most probably the destination directory is not empty.\n\n";

# Open the log file.
no warnings 'once';
open SAVE, '>&STDERR';
open STDERR, '>', $outdir . '/final_output/log.txt' or die $!;
say {*STDERR} 'Structuprint was called with this command:';
say {*STDERR} q{   } . used_command() . "\n";

if ( defined $nthreads and $nthreads < 0 )
{
    print colored( 'Warning!', 'bold' )
      . "\nInvalid number of threads. Setting it to 1.\n\n";
    say {*STDERR} "\nInvalid number of threads. Setting it to 1.\n\n";
    $nthreads = 1;
}
$nthreads //= 1;

if ( defined $nloops and $nloops < 0 )
{
    print colored( 'Warning!', 'bold' )
      . "\nInvalid number of loops. Setting it to 0.\n\n";
    say {*STDERR} "\nInvalid number of loops. Setting it to 0.\n\n";
    $nloops = 0;
}
$nloops //= 0;

my ( @images, $pm, $share, $share2 );

# Prepare parallel execution for non-Windows systems.
if ( $^O eq 'MSWin32' )
{
    $share  = 0;
    $share2 = 0;
}
else
{
    $pm = Parallel::ForkManager->new($nthreads);
    $pm->run_on_finish(
        sub {
            my ( $pid, $exit_code, $ident, $exit_signal, $core_dump, $result )
              = @_;

            if ( defined $result->[0]
                and $result->[0] =~ /final_output\/(\d+)[.]gif$/ )
            {
                $images[ $1 + $offset - 1 ] = $result->[0];
            }
        }
    );

    $share = IPC::ShareLite->new(
        -key     => 1337 . $$,
        -create  => 'yes',
        -destroy => 'no',
    ) or die $!;
    $share->store('0');

    $share2 = IPC::ShareLite->new(
        -key     => 1604 . $$,
        -create  => 'yes',
        -destroy => 'no',
    ) or die $!;
    $share->store('0');
}

# Validate various parameters...
my $extra_params = q{};
if ( defined $width and $width > 0 )
{
    $extra_params .= "-width $width ";
}
elsif ( defined $width and $width <= 0 )
{
    print colored( 'Warning!', 'bold' )
      . "\nInvalid width. Setting it to the default value.\n\n";
    say {*STDERR} "\nInvalid width. Setting it to the default value.\n\n";
}

if ( defined $height and $height > 0 )
{
    $extra_params .= "-height $height ";
}
elsif ( defined $height and $height <= 0 )
{
    print colored( 'Warning!', 'bold' )
      . "\nInvalid height. Setting it to the default value.\n\n";
    say {*STDERR} "\nInvalid height. Setting it to the default value.\n\n";
}

if ( defined $res and $res > 0 )
{
    $extra_params .= "-res $res ";
}
elsif ( defined $res and $res <= 0 )
{
    print colored( 'Warning!', 'bold' )
      . "\nInvalid resolution. Setting it to 100 ppi.\n\n";
    say {*STDERR} "\nInvalid resolution. Setting it to 100 ppi.\n\n";
}

if ( defined $legend_title )
{
    $extra_params .= "-legend_title '$legend_title' ";
}

if ( defined $no_legend )
{
    $extra_params .= '-no_legend ';
}

if ( defined $no_id )
{
    $extra_params .= '-no_id ';
}

if ( defined $point_size and $point_size > 0 )
{
    $extra_params .= "-point_size $point_size ";
}

if ( defined $no_NC )
{
    $extra_params .= '-no_NC ';
}

if ( defined $custom_db and -e $custom_db )
{
    $extra_params .= "-custom_db '$custom_db' ";
}

$extra_params .= '-_no_heading ';

close STDERR;
open STDERR, '>&SAVE';

# Prepare the progress bar and start!
my $progress_bar = Term::ProgressBar->new( { count => scalar @{$files} } );
foreach ( @{$files} )
{

    # If one file failed, exit the loop.
    if ( $^O eq 'MSWin32' )
    {
        last if $share2 eq 'failure';
    }
    else
    {
        $pm->start and next;
        if ( $share2->fetch() eq 'failure' )
        {
            $pm->finish( 0, [undef] );
        }
    }

    # Call the structuprint_frame executable.
    mkdir $outdir . q{/} . $_;
    my $old_file = $dir . q{/} . $prefix . '_' . $_ . '.pdb';
    my $new_file = $outdir . q{/} . $_ . q{/} . $prefix . '_' . $_ . '.pdb';

    copy $old_file, $new_file or die $!;

    my $dir2 = q{"} . $outdir . q{/} . $_ . q{"};

    if ( defined $outdir )
    {
        $extra_params .= "-outdir $dir2 ";
    }

    system
      "\"$rootdir/structuprint_frame\" -dir $dir2 -prop $prop $extra_params";

    my $old_print = $outdir . q{/} . $_ . '/structuprint.tiff';
    my $new_print = $outdir . q{/} . 'final_output/' . $_ . '.tiff';

    # Wait for 1 second to make sure that the TIFF file
    # has finished being written.
    sleep 1;

    # Convert the TIFF file to GIF format.
    my $new_print2;
    if ( -e $old_print )
    {
        copy $old_print, $new_print or die $!;

        $new_print2 = $new_print;
        $new_print2 =~ s/[.]tiff/.gif/;

        my $image = Imager->new;
        $image->read( file => $new_print ) or die $image->errstr;
        $image->write( file => $new_print2 ) or die $image->errstr;

        unlink $new_print;

        if ( $^O eq 'MSWin32' and $new_print2 =~ /final_output\/(\d+)[.]gif$/ )
        {
            $images[ $1 + $offset - 1 ] = $new_print2;
        }
    }
    else
    {
        if ( $^O eq 'MSWin32' )
        {
            $share2 = 'failure';
        }
        else
        {
            $share2->store('failure');
        }
    }

    # Delete temporary directories, if requested by the user.
    if ($del_temp_dirs)
    {
        unlink $outdir . q{/} . $_ . '/log.txt';
        unlink $outdir . q{/} . $_ . '/structuprint.tiff';
        unlink $outdir . q{/} . $_ . q{/} . $prefix . '_' . $_ . '.pdb';

        rmdir $outdir . q{/} . $_;
    }

    # Update the progress bar.
    if ( $^O eq 'MSWin32' )
    {
        $share++;
        $progress_bar->update($share);
    }
    else
    {
        $share->store( $share->fetch() + 1 );
        $progress_bar->update( $share->fetch() );
        $pm->finish( 0, [$new_print2] );
    }
}

if ( $^O ne 'MSWin32' )
{
    $pm->wait_all_children;
}

if ( !( defined $delay ) || ( $delay <= 0 ) )
{
    $delay = 100;
}

# Make sure that all files have been created.
@images = grep defined, @images;
if ( scalar @{$files} < ( $#images + 1 ) )
{
    say colored( "\n\nUh-oh...\n", 'bold' );
    say
"Something went wrong and the animation could not be produced! Check the log files!\n";
}

open STDERR, '>>', $outdir . '/final_output/log.txt' or die $!;

# Concatenate frames into a GIF animation.
eval {
    my @frames;

    foreach (@images)
    {
        my $frame = Imager->new;
        $frame->read( file => $_ ) or die $frame->errstr;
        push @frames, $frame;
    }

    Imager->write_multi(
        {
            file      => $outdir . '/final_output/animation.gif',
            type      => 'gif',
            gif_delay => $delay,
            gif_loop  => $nloops
        },
        @frames
    );
};

my $error = $@;
if ( $error ne q{} )
{
    say {*STDERR} $error;
}

# Display the final status message.
if (    -e $outdir . '/final_output/animation.gif'
    and -s $outdir . '/final_output/animation.gif' )
{
    say colored( "\n\nSUCCESS!\n", 'bold' );
    say
"The resulting gif file is located at:\n   $outdir/final_output/animation.gif\n";
}
else
{
    say colored( "\n\nUh-oh...\n", 'bold' );
    say
"Something went wrong and the animation could not be produced! Check the log files!\n";
}

exit;

#---------------------------------------------------------------------#
#    S     U     B     R     O     U     T     I     N     E     S    #
#---------------------------------------------------------------------#

# Connect to the database and retrieve the amino acid properties.
sub amino_acid_properties
{
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

    return $dbh->selectcol_arrayref(
        'SELECT name FROM sqlite_master WHERE type = "table"');
}

#Define the working directory and its file.#
sub directory_handling
{
    my $full_path = File::Spec->rel2abs($dir);

    opendir my $dh, $full_path
      or die colored( 'ERROR!', 'bold' ) . "\n'$dir' cannot be opened.\n\n";

    my $prefix;
    my @files;

    #Read the files in the directory.#
    while ( readdir $dh )
    {
        if (/_(\d+)[.]pdb$/)
        {
            push @files, $1;
            $prefix //= $`;
        }
    }
    closedir $dh;

    if ( $#files == -1 )
    {
        die colored( "\nERROR!\n", 'bold' )
          . "No suitable PDB file was found in '$dir'.\n"
          . "Please provide a directory that contains numbered PDB files (e.g., mds_1.pdb, mds_2.pdb).\n\n";
    }

    @files = sort { $a <=> $b } @files;
    return $full_path, \@files, $prefix;
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

structuprint - utility for 2D animations of protein surfaces

=head1 SYNOPSIS

B<structuprint> B<-prop> PROPERTY
             B<-dir> INPUT_DIRECTORY
             [B<-outdir> OUTPUT_DIRECTORY]
             [B<-custom_db> PATH_TO_DATABASE]
             [B<-height> HEIGHT] [B<-width> WIDTH]
             [B<-res> PPI_NUMBER]
             [B<-point_size> SIZE]
             [B<-bgcol> HEX_COLOR|COLOR_NAME] [B<-bgalpha> ALPHA_VALUE]
             [B<-legend_title> TITLE]
             [B<--no_ID>] [B<--no_legend>] [B<--no_NC>]
             [B<--del_temp_dirs>]
             [B<-delay> DELAY]
             [B<-nloops> NUMBER_OF_LOOPS]
             [B<-nthreads> NUMBER_OF_THREADS]
             [B<--help>]
             [B<--properties>]

=head1 DESCRIPTION

Structuprint is a tool for generating two-dimensional animations of protein surfaces. Given an input directory with properly named PDB files, structuprint will render each frame separately and join them into an animation at the end.

Refer to the B<structuprint_frame> manpage or to the documentation for details about the core algorithm.

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

=item B<--del_temp_dirs>

=over 4

By default, Structuprint creates one directory per frame and one for the final animation. With this flag, only the final animation directory will remain at the end. Do NOT use this flag if you are trying to report a bug, as all the log files from the individual frames will be deleted.

=back

=item B<-delay> DELAY

=over 4

Set the delay between individual frames in milliseconds. Default value: 100

=back

=item B<-dir> INPUT_DIRECTORY

=over 4

Specify the directory location of the input PDB files. The PDB filenames must contain an underscore and an ID number before the pdb suffix, e.g. mds_1.pdb, mds_2.pdb ...

=back

=item B<-height> HEIGHT

=over 4

Specify the height of the animation in mm. If only B<-width> is set, then Structuprint will automatically adjust the height to the appropriate value. Default values: 76.56 by default or 66 when the B<--no_legend> flag is active.

=back

=item B<--help>

=over 4

Show the available options and exit.

=back

=item B<-legend_title> TITLE

=over 4

Specify the title of the legend. If this is not set, then Structuprint will use the name of the selected property as the legend title.

=back

=item B<-nloops> NUMBER_OF_LOOPS

=over 4

Set the number of loops for the animation. Default value: 0 (infinite loops)

=back

=item B<--no_ID>

=over 4

Remove the ID numbers from the frames of the animation.

=back

=item B<--no_legend>

=over 4

Remove the legend from the frames of the animation.

=back

=item B<--no_NC>

=over 4

Do not show the N/C-termini positions in the frames of the animation.

=back

=item B<-nthreads> NUMBER_OF_THREADS

=over 4

Set the number of parallel threads to be launched by Structuprint in order to speed up the execution. Do NOT ask for more threads than the number of cores in your system or you will suffer a decrease in performance! Default value: 1

=back

=item B<-outdir> OUTPUT_DIRECTORY

=over 4

Specify the location for Structuprint's output directories. The directory must be empty. If this is not set, Structuprint will write its output in the input directory.

=back

=item B<-point_size> SIZE

=over 4

Specify the size of the data points in the frames of the animation. Default value: 1

=back

=item B<-prop> PROPERTY

=over 4

Specify the amino acid property based on which the animation will be colored.

=back

=item B<--properties>

=over 4

List all the amino acid properties available in the default database along with their explanation, and quit.

=back

=item B<-res> PPI_NUMBER

=over 4

Specify the resolution of the animation in pixels per inch. Default value: 100

=back

=item B<-width> WIDTH

=over 4

Specify the width of the animation in mm. If only B<-height> is set, then Structuprint will automatically adjust the width to the appropriate value. Default value: 90

=back

=back

=head1 EXAMPLE

structuprint -dir './Data/' -prop FCharge -legend_title 'Charge' -width 250 -res 300 -outdir './Results/' -nthreads 4

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
