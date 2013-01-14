#!/usr/bin/env perl

=head1 NAME

structuprint

=head1 SYNOPSIS

structuprint.pl directory property

=head1 DESCRIPTION

structuprint is a tool for creating 'structuprint' animations 
from PDB structures. Refer to structuprint's main documentation 
for more details.

=head1 OPTIONS

=head2 -prop

Display the list of available amino acid properties to choose from.

=head1 DEPENDENCIES

-the Perl interpreter, >= 5.10
-DBD::SQLite, >= 1.37 (Perl module)
-DBI, >= 1.622 (Perl module)
-File::Spec, >= 3.33 (Perl module)
-File::Copy, >= 2.18 (Perl module)
-ImageMagick
-Gifsicle

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

use DBI;
use File::Spec;
use File::Copy qw(copy);

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
      . "$0 \033[1m-prop\033[0m | less\n";

    #Make sure that the specified property actually exists.#
    if ( !( /$ARGV[1]/i ~~ @properties ) )
    {
        die "\033[1mERROR!\033[0m\n"
          . "No such amino acid property: $ARGV[1]\n"
          . "\nTo see a list of all available amino acid properties, type:\n"
          . "$0 \033[1m-prop\033[0m | less\n";
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

if ( `tput cols` >= 75 )
{
    print $ascii_logo;
}

my ( $directory, $files, $prefix ) = directory_handling();
my $property = $ARGV[1];

my $files_number = scalar @{$files};

my $files_counter = 1;
my $average_time;
my $last_time = 0;
system "mkdir " . '"' . $directory . 'final_output"';
foreach ( @{$files} )
{
    print "-> File $files_counter/$files_number ...";
    if ( $files_counter >= $files_number * 0.7 )
    {
        say " ||| Estimated remaining time: "
          . time_formatter(
            2 * $average_time * ( $files_number - $files_counter + 1 ) );
    }
    else
    {
        say q{};
    }

    system "mkdir " . '"' . $directory . $_ . '"';
    my $old_file = $directory . $prefix . '_' . $_ . '.pdb';
    my $new_file = $directory . $_ . '/' . $prefix . '_' . $_ . '.pdb';

    copy $old_file, $new_file or die;

    my $directory2 = '"' . $directory . $_ . '"';

    my $start_time = time;
    system "/opt/structuprint/structuprint_frame.pl $directory2 $property";

    my $end_time   = time;
    my $round_time = $end_time - $start_time;

    if ( !($average_time) )
    {
        $average_time = $round_time;
    }
    else
    {
        $average_time = 0.005 * $last_time + ( 1 - 0.005 ) * $average_time;
    }
    $last_time = $round_time;

    my $old_print = $directory . $_ . '/structuprint.png';
    my $new_print = $directory . 'final_output/' . $_ . '.png';
    copy $old_print, $new_print or die;

    my $new_print2 = $new_print;
    $new_print2 =~ s/[.]png/.gif/;
    system "convert $new_print $new_print2";
    unlink $new_print;

    $files_counter++;
}

opendir my $dh, $directory . 'final_output' or die;
my @gifs;

while ( readdir $dh )
{
    if ( $_ =~ /[.]gif/ )
    {
        push @gifs, $`;
    }
}

@gifs = sort { $a <=> $b } @gifs;

my $animation_command = 'gifsicle -O2 --delay=60 ';

foreach my $gif (@gifs)
{
    $animation_command .= '"' . $directory . 'final_output/' . $gif . '.gif" ';
}
close $dh;

$animation_command .= '>"' . $directory . 'final_output/animation.gif"';
system "$animation_command 2>/dev/null";

say "\nSUCCESS!\n";
say 'The resulting gif file is located at "'
  . $directory
  . 'final_output/animation.gif".';

#---------------------------------------------------------------------#
#    S     U     B     R     O     U     T     I     N     E     S    #
#---------------------------------------------------------------------#

sub amino_acid_properties
{
    my $dbh =
      DBI->connect( "dbi:SQLite:/opt/structuprint/amino_acid_properties.db",
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
      or die "ERROR!\n" . "$directory cannot be opened.\n";
    my @files;
    my $prefix;

    #Read the files in the directory.#
    while ( readdir $dh )
    {

        #Exclude ".", "..".#
        if ( $_ ne q{.} && $_ ne q{..} && $_ =~ /_(\d+)[.]pdb$/ )
        {
            push @files, $1;
            $prefix //= $`;
        }
    }
    closedir $dh;

    if ( $#files == -1 )
    {
        die "\nERROR!\n"
          . "No suitable PDB file in $directory.\n"
          . "Please provide a directory containing PDB files.\n\n";
    }

    @files = sort { $a <=> $b } @files;
    return $directory, \@files, $prefix;
}

sub time_formatter
{
    my ($time) = @_;

    my ( $hours, $minutes, $seconds );
    if ( $time > 3600 )
    {
        $hours = $time / 3600;
        $time %= 3600;
    }
    if ( $time > 60 )
    {
        $minutes = $time / 60;
        $time %= 60;
    }
    if ( $time > 0 )
    {
        $seconds = $time;
    }

    my $text = q{};
    if ( $hours && $minutes && $seconds )
    {
        if ( $hours >= 2 )
        {
            $text .= int($hours) . ' hours';
        }
        else
        {
            $text .= '1 hour';
        }
        if ( $minutes >= 2 )
        {
            $text .= ' and ' . int($minutes) . ' minutes.';
        }
        else
        {
            $text .= ' and 1 minute.';
        }
    }
    elsif ( $hours && $seconds )
    {
        if ( $hours >= 2 )
        {
            $text .= int($hours) . ' hours.';
        }
        else
        {
            $text .= '1 hour.';
        }
    }
    elsif ( $minutes && $seconds )
    {
        if ( $minutes >= 2 )
        {
            $text .= int($minutes) . ' minutes.';
        }
        else
        {
            $text = '1 minute.';
        }
    }
    elsif ($hours)
    {
        if ( $hours >= 2 )
        {
            $text .= int($hours) . ' hours.';
        }
        else
        {
            $text .= '1 hour.';
        }
    }
    elsif ($minutes)
    {
        if ( $minutes >= 2 )
        {
            $text .= int($minutes) . ' minutes.';
        }
        else
        {
            $text .= '1 minute.';
        }
    }
    elsif ($seconds)
    {
        if ( $seconds >= 2 )
        {
            $text .= int($seconds) . ' seconds.';
        }
        else
        {
            $text .= '1 second.';
        }
    }
    return $text;
}
