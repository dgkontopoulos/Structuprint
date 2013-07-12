#!/usr/bin/env perl

use strict;
use warnings;

use feature qw(say);

use DBI;
use File::Copy qw(copy);
use Gtk2 -init;

my $window = Gtk2::Window->new('toplevel');
$window->set_title('Structuprint');

$window->set_default_icon_from_file('/opt/structuprint/images/logo.png');
$window->signal_connect( destroy => sub { Gtk2->main_quit; exit; } );
$window->set_position('mouse');
$window->set_resizable(0);

# Enable tooltips. #
my $tooltips = Gtk2::Tooltips->new();

my $menu_bar = Gtk2::MenuBar->new();

#######
#File.#
#######
my $menu_item_file = Gtk2::MenuItem->new('_File');

my $menu_file = Gtk2::Menu->new();

# Create the notebook layout (tabs). #
my $notebook = Gtk2::Notebook->new;
$notebook->set_scrollable('TRUE');

# Animation items (menu, button & animation tab items) #
my ( $menu_file_animation, $new_structuprint, $animation_items ) =
  main_items('animation');
$menu_file->append($menu_file_animation);

# Frame items (button & frame tab items). #
my ( $menu_file_frame, $new_frame, $frame_items ) = main_items('frame');
$menu_file->append($menu_file_frame);

# Horizontal separator for menu. #
$menu_file->append( Gtk2::SeparatorMenuItem->new() );

# Quit structuprint. #
my $menu_file_quit = Gtk2::MenuItem->new('Exit');
$menu_file_quit->signal_connect( 'activate' => sub { Gtk2->main_quit(); exit; }
);
$menu_file->append($menu_file_quit);

$menu_item_file->set_submenu($menu_file);
$menu_bar->append($menu_item_file);

#######
#Help.#
#######
my $menu_item_help = Gtk2::MenuItem->new('_Help');
my $menu_help      = Gtk2::Menu->new();

# About Perl. #
my $menu_help_Perl = Gtk2::MenuItem->new('About Perl');
$menu_help_Perl->signal_connect(
    'activate' => sub { system 'x-www-browser http://www.perl.org/about.html' }
);
$menu_help->append($menu_help_Perl);

# About gtk2-perl. #
my $menu_help_gtk2 = Gtk2::MenuItem->new('About gtk2-perl');
$menu_help_gtk2->signal_connect( 'activate' =>
      sub { system 'x-www-browser http://gtk2-perl.sourceforge.net/' } );
$menu_help->append($menu_help_gtk2);

# About R. #
my $menu_help_R = Gtk2::MenuItem->new('About R');
$menu_help_R->signal_connect( 'activate' =>
      sub { system 'x-www-browser http://www.r-project.org/about.html' } );
$menu_help->append($menu_help_R);

# Horizontal separator. #
$menu_help->append( Gtk2::SeparatorMenuItem->new() );

# About structuprint. #
my $menu_help_codebook = Gtk2::MenuItem->new('Amino acid properties Codebook');
$menu_help_codebook->signal_connect(
    'activate' => sub { system 'xdg-open /opt/structuprint/codebook.pdf' } );
$menu_help->append($menu_help_codebook);

# About structuprint. #
my $menu_help_about = Gtk2::MenuItem->new('About Structuprint');
$menu_help_about->signal_connect( 'activate' => \&about );
$menu_help->append($menu_help_about);

$menu_item_help->set_submenu($menu_help);
$menu_bar->append($menu_item_help);

my $vbox = Gtk2::VBox->new( '0', '10' );
$vbox->add($menu_bar);

my $hbox1 = Gtk2::HBox->new( '0', '5' );
$hbox1->add($new_structuprint);
$hbox1->add($new_frame);

# About button. #
my $about_button = Gtk2::Button->new();
$about_button->set_image(
    Gtk2::Image->new_from_stock( 'gtk-about', 'large-toolbar' ) );
$about_button->signal_connect( 'clicked' => \&about );
$about_button->set_label('About');
$tooltips->set_tip( $about_button, 'About Structuprint' );
$hbox1->add($about_button);

# Exit button. #
my $exit_button = Gtk2::Button->new();
$exit_button->set_image(
    Gtk2::Image->new_from_stock( 'gtk-quit', 'large-toolbar' ) );
$exit_button->signal_connect( 'clicked' => sub { Gtk2->main_quit(); exit; } );
$tooltips->set_tip( $exit_button, 'Exit Structuprint' );
$hbox1->add($exit_button);

$vbox->add($hbox1);

# Animation tab: add main items. #
my $animation_page = Gtk2::Frame->new();
$animation_page->add($animation_items);
$notebook->append_page( $animation_page,
    Gtk2::Label->new("\t\t\t\tAnimation\t\t\t\t") );

# Frame tab: add main items #
my $frame_page = Gtk2::Frame->new();
$frame_page->add($frame_items);
$notebook->append_page( $frame_page,
    Gtk2::Label->new("\t\t\t\tFrame\t\t\t\t") );

$vbox->add($notebook);

$window->add($vbox);
$window->show_all;
Gtk2->main;

#######################################################
# S    U    B    R    O    U    T    I    N    E    S #
#######################################################

sub about
{
    my $window = Gtk2::Window->new('toplevel');
    $window->set_title('About Structuprint');
    $window->set_default_icon_from_file('/opt/structuprint/images/logo.png');
    $window->signal_connect( destroy => sub { Gtk2->main_quit() } );
    $window->set_resizable(0);

    my $hbox0 = Gtk2::HBox->new( 0, 20 );
    my $logo = Gtk2::Image->new_from_file('/opt/structuprint/images/logo.png');
    $hbox0->add($logo);

    my $top_info = <<'ABOUT';
<b>Structuprint</b>, v1.0
<a href='http://www.bioacademy.gr/bioinformatics/structuprint/index.html'>Website</a> --- <a href='https://github.com/dgkontopoulos/Structuprint'>Source Code</a>
(C) 2012-13 <a href="mailto:dvlachakis@bioacademy.gr?Subject=Structuprint">Dimitrios Vlachakis</a>, <a href="mailto:gtsiliki@bioacademy.gr?Subject=Structuprint">Georgia Tsiliki</a>,
<a href="mailto:dgkontopoulos@gmail.com?Subject=Structuprint">Dimitrios - Georgios Kontopoulos</a>, <a href="mailto:skossida@bioacademy.gr?Subject=Structuprint">Sophia Kossida</a>
ABOUT
    chomp $top_info;
    my $second_info = <<'ABOUT';
<span size="small">
<b>Structuprint</b> is a utility for analysis of MD simulations -and single PDB structures as well-,
offering a novel 2D visualisation technique.

The code is written in <a href="http://www.perl.org/">Perl</a>/<a href="http://gtk2-perl.sourceforge.net/">GTK2</a> and <a href="http://www.r-project.org/">R.</a></span>
ABOUT
    chomp $second_info;
    $second_info =~ s/(>+)\n(<+|$)/$1$2/g;
    my $license = <<'ABOUT';
<span size="small"><b><u>License:</u></b>
<i>This program is free software; you can redistribute it and/or modify it under the terms
of the <a href="http://www.gnu.org/licenses/gpl-2.0.html">GNU General Public License, as published by the Free Software Foundation; either
version 2 of the License, or (at your option) any later version</a>.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
PURPOSE.</i></span>
ABOUT
    chomp $license;

    my $vbox = Gtk2::VBox->new( '0', '10' );
    my $label1 = Gtk2::Label->new();
    $label1->set_markup($top_info);
    $label1->set_justify('center');
    $hbox0->add($label1);

    my $separator1 = Gtk2::HSeparator->new;
    my $label2     = Gtk2::Label->new();
    $label2->set_markup($second_info);
    my $separator2 = Gtk2::HSeparator->new;

    my $license_button = Gtk2::ToggleButton->new_with_label('License');

    my $license_counter = 0;
    $license_button->signal_connect(
        toggled => sub {
            if ( $license_counter == 0 )
            {
                $license_counter = 1;
                $label2->set_markup($license);
                $window->show_all;
            }
            else
            {
                $license_counter = 0;
                $license_button->set_active(0);
                $label2->set_markup($second_info);
                $window->show_all;
            }
        }
    );

    $vbox->add($hbox0);
    $vbox->add($separator1);
    $vbox->add($label2);
    $vbox->add($separator2);

    my $hbox = Gtk2::HBox->new( 0, 20 );
    $hbox->add($license_button);

    my $quit_button = Gtk2::Button->new();
    $quit_button->set_image(
        Gtk2::Image->new_from_stock( 'gtk-quit', 'large-toolbar' ) );
    $quit_button->signal_connect( clicked => sub { $window->destroy; } );
    $hbox->add($quit_button);

    $vbox->add($hbox);
    $window->set_border_width(15);
    $window->set_position('mouse');
    $window->add($vbox);

    $window->show_all;
    Gtk2->main;
    return 0;
}

# Count suitable pdb files in the input directory. #
sub count_pdbs
{
    my ($directory) = @_;

    opendir my $dh, $directory or return 0;
    my $files_count = 0;
    while ( readdir $dh )
    {
        if ( $_ =~ /_\d+[.]pdb$/ )
        {
            $files_count++;
        }
    }
    return $files_count;
}

sub error_message
{
    my ($error_input) = @_;

    # Throw an error. #
    my $error_window = Gtk2::Window->new('popup');
    $error_window->set_position('mouse');
    $error_window->set_border_width(5);

    my $vbox  = Gtk2::VBox->new( '0', '10' );
    my $hbox1 = Gtk2::HBox->new( '0', '5' );

    # Error logo. #
    my $error = Gtk2::Image->new_from_stock( 'gtk-dialog-warning', 'dialog' );
    $hbox1->add($error);

    # Error text. #
    my $error_label = Gtk2::Label->new;
    my $error_text;

    if ( $error_input eq 'property' )
    {
        $error_text = << 'END';
<b>ERROR!</b>
No amino acid property was selected!
END
    }
    elsif ( $error_input eq 'no_dir' )
    {
        $error_text = << 'END';
<b>ERROR!</b>
No input directory has been selected!
END
    }
    elsif ( $error_input eq 'no_pdb' )
    {
        $error_text = << 'END';
<b>ERROR!</b>
No input PDB file has been selected!
END
    }
    elsif ( $error_input eq 'no_output' )
    {
        $error_text = << 'END';
<b>ERROR!</b>
No output directory has been selected!
END
    }
    elsif ( $error_input eq 'output_not_empty' )
    {
        $error_text = << 'END';
<b>ERROR!</b>
The output directory is not empty!
END
    }
    elsif ( $error_input eq 'output_dir_does_not_exist' )
    {
        $error_text = << 'END';
<b>ERROR!</b>
The output directory does not exist!
END
    }
    elsif ( $error_input eq 'input_dir_does_not_exist' )
    {
        $error_text = << 'END';
<b>ERROR!</b>
The input directory does not exist!
END
    }
    elsif ( $error_input eq 'no_suitable_input_pdbs' )
    {
        $error_text = << 'END';
<b>ERROR!</b>
The input PDB filename(s) should contain an underscore
and a number before the pdb extension!

eg: mds_1.pdb, mds_2.pdb ... mds_40.pdb
END
    }
    chomp $error_text;

    $error_label->set_markup($error_text);
    $error_label->set_justify('center');
    $hbox1->add($error_label);

    $vbox->add($hbox1);

    # Ok button. #
    my $ok_button = Gtk2::Button->new('OK');
    $ok_button->signal_connect( 'clicked' => sub { $error_window->destroy; } );
    $vbox->add($ok_button);

    $error_window->add($vbox);
    $error_window->show_all;
    Gtk2->main;
    return 0;
}

# Insert all available properties into the combobox. #
sub insert_properties
{
    my ($combobox) = @_;

    # Connect to the database. #
    my $dbh =
      DBI->connect( 'dbi:SQLite:/opt/structuprint/amino_acid_properties.db',
        q{}, q{} );

    my $db_sel =
      $dbh->prepare('Select name from sqlite_master where type = "table"');
    $db_sel->execute();
    my $properties = $db_sel->fetchall_arrayref;
    $dbh->disconnect();

    my $index = 0;
    while ( $properties->[$index] )
    {
        $combobox->append_text( $properties->[$index]->[0] );
        $index++;
    }
    return 0;
}

sub is_dir_proper
{
    my ( $dir, $type ) = @_;

    if ( $type eq 'output' )
    {
        opendir my $fh, $dir or return 2;
        while ( readdir $fh )
        {
            if ( $_ ne q{.} and $_ ne q{..} )
            {
                return 1;
            }
        }
    }
    elsif ( $type eq 'input' )
    {
        opendir my $fh, $dir or return 2;
        while ( readdir $fh )
        {
            if ( $_ =~ /_\d+[.]pdb$/ )
            {
                return 0;
            }
        }
        return 1;
    }
    return 0;
}

sub main_items
{
    my ($type) = @_;

    my $button = Gtk2::Button->new();
    my $menu   = Gtk2::MenuItem->new();
    if ( $type eq 'frame' )
    {

        # New frame. #
        $button->set_label('New Frame');
        $tooltips->set_tip( $button, 'New structuprint frame' );
        $menu->set_label('New Frame');
    }
    elsif ( $type eq 'animation' )
    {

        # New animation. #
        $button->set_label('New Animation');
        $tooltips->set_tip( $button, 'New structuprint animation' );
        $menu->set_label('New Animation');
    }

    my $hbox0 = Gtk2::HBox->new( '0', '20' );

    # Select an amino acid property. #
    my $label_sel = Gtk2::Label->new('Select an amino acid property:');
    $hbox0->add($label_sel);

    my $combobox = Gtk2::ComboBox->new_text;
    $combobox->append_text(q{});

    # Insert properties to the combobox. #
    insert_properties($combobox);
    $hbox0->add($combobox);

    # Button to codebook. #
    my $codebook_button = Gtk2::Button->new;
    $codebook_button->set_image(
        Gtk2::Image->new_from_stock( 'gtk-help', 'button' ) );
    $codebook_button->signal_connect(
        'clicked' => sub { system 'xdg-open /opt/structuprint/codebook.pdf' } );
    $hbox0->add($codebook_button);

    my $vbox1 = Gtk2::VBox->new( '0', '10' );
    $vbox1->add($hbox0);

    my $hbox1 = Gtk2::HBox->new( '0', '20' );

    # Select input directory or file. #
    my $input;
    my $label_input  = Gtk2::Label->new;
    my $input_entry  = Gtk2::Entry->new;
    my $input_button = Gtk2::Button->new_with_label('...');
    $input_entry->set_editable(1);

    if ( $type eq 'frame' )
    {
        $label_input->set_text('                  Input file:');
        $input_button->signal_connect(
            'clicked' => \&select_file,
            $input_entry
        );
    }
    elsif ( $type eq 'animation' )
    {
        $label_input->set_text('     Input directory:');
        $input_button->signal_connect(
            'clicked' => \&select_directory,
            $input_entry
        );
    }
    $hbox1->add($label_input);
    $hbox1->add($input_entry);
    $hbox1->add($input_button);
    $vbox1->add($hbox1);

    my $hbox2 = Gtk2::HBox->new( '0', '20' );
    my $output_dir;

    # Select an output directory. #
    my $label_dir = Gtk2::Label->new('Output directory:');
    $hbox2->add($label_dir);

    my $output_entry = Gtk2::Entry->new;
    $output_entry->set_editable(1);

    my $active_tab;

    if ( $type eq 'frame' )
    {
        $active_tab = 1;
    }
    elsif ( $type eq 'animation' )
    {
        $active_tab = 0;
    }
    $menu->signal_connect(
        'activate' => sub {
            $combobox->set_active(0);
            $input_entry->set_text(q{});
            $output_entry->set_text(q{});
            $notebook->set_current_page($active_tab);
        }
    );

    $button->signal_connect(
        'clicked' => sub {
            $combobox->set_active(0);
            $input_entry->set_text(q{});
            $output_entry->set_text(q{});
            $notebook->set_current_page($active_tab);
        }
    );

    $hbox2->add($output_entry);

    my $dir_button = Gtk2::Button->new_with_label('...');
    $dir_button->signal_connect(
        'clicked' => \&select_directory,
        $output_entry
    );
    $hbox2->add($dir_button);

    $vbox1->add($hbox2);

    my $hbox3 = Gtk2::HBox->new( '0', '20' );
    $hbox3->add($vbox1);

    # Vertical Separator. #
    $hbox3->add( Gtk2::VSeparator->new() );

    # Start button. #
    my $start_button = Gtk2::Button->new_with_label('Start!');

    # Start button action. #
    my @needed_items = ( $combobox, $input_entry, $type, $output_entry );
    $start_button->signal_connect(
        clicked => \&prepare_execution,
        \@needed_items
    );

    $hbox3->add($start_button);

    return $menu, $button, $hbox3;
}

# Check that everything is ready for structuprint to run. #
sub prepare_execution
{
    my ( $start_button, $items ) = @_;

    my $combobox     = $items->[0];
    my $input_entry  = $items->[1];
    my $type         = $items->[2];
    my $output_entry = $items->[3];

    # Check if a property was selected. #
    unless ( defined $combobox->get_active_text )
    {
        error_message('property');
    }
    elsif ( $input_entry->get_text() =~ /^\s*$/ && $type eq 'animation' )
    {
        error_message('no_dir');
    }
    elsif ( $input_entry->get_text() =~ /^\s*$/ && $type eq 'frame' )
    {
        error_message('no_pdb');
    }
    elsif ( $output_entry->get_text() =~ /^\s*$/ )
    {
        error_message('no_output');
    }
    else
    {
        my $property = $combobox->get_active_text;
        my $destdir  = $output_entry->get_text();

        my $empty = is_dir_proper( $destdir, 'output' );
        if ( $empty == 1 )
        {
            error_message('output_not_empty');
        }
        elsif ( $empty == 2 )
        {
            error_message('output_dir_does_not_exist');
        }
        elsif ( $empty == 0 )
        {
            if ( $type eq 'frame' )
            {
                unless ( $input_entry->get_text() =~ /_\d+[.]pdb/ )
                {
                    error_message('no_suitable_input_pdbs');
                }
                else
                {
                    copy $input_entry->get_text(), $destdir;
                    system "xterm -hold -e 'structuprint $destdir $property'";
                }
            }
            elsif ( $type eq 'animation' )
            {
                my $input_dir = $input_entry->get_text();
                $input_dir =~ s/(\/?)$//;

                my $pdb_inside = is_dir_proper( $input_dir, 'input' );
                my $pdbs_number = count_pdbs($input_dir);

                if ( $pdb_inside == 2 )
                {
                    error_message('input_dir_does_not_exist');
                }
                elsif ( $pdb_inside == 1 )
                {
                    error_message('no_suitable_input_pdbs');
                }
                elsif ( $pdb_inside == 0 )
                {
                    if ( $pdbs_number > 50 )
                    {
                        my $warning_window = Gtk2::Window->new('popup');
                        $warning_window->set_position('mouse');
                        $warning_window->set_border_width(5);

                        my $vbox  = Gtk2::VBox->new( '0', '10' );
                        my $hbox1 = Gtk2::HBox->new( '0', '5' );

                        # Warning logo. #
                        my $warning =
                          Gtk2::Image->new_from_stock( 'gtk-dialog-warning',
                            'dialog' );
                        $hbox1->add($warning);

                        # Warning text. #
                        my $warning_label = Gtk2::Label->new;
                        my $warning_text  = << 'END';
<b>Warning!</b>

The output images created by structuprint are quite detailed
and therefore big in terms of filesize. On average, it is a good
idea to limit structuprint animations to no more than 50 PDBs
per animation.

Do you want to proceed anyway?
END
                        $warning_label->set_markup($warning_text);
                        $warning_label->set_justify('center');
                        $hbox1->add($warning_label);

                        $vbox->add($hbox1);

                        my $hbox2 = Gtk2::HBox->new( '0', '5' );

                        # Abort button. #
                        my $abort_button = Gtk2::Button->new('Abort');
                        $abort_button->signal_connect(
                            'clicked' => sub { $warning_window->destroy; } );
                        $hbox2->add($abort_button);

                        # Proceed button. #
                        my $proceed_button = Gtk2::Button->new('Proceed');
                        $proceed_button->signal_connect(
                            'clicked' => sub {
                                $warning_window->destroy;
                                system "cp $input_dir/* $destdir";
                                system
"xterm -hold -e 'structuprint $destdir $property'";
                            }
                        );
                        $hbox2->add($proceed_button);

                        $vbox->add($hbox2);

                        $warning_window->add($vbox);
                        $warning_window->show_all;
                        Gtk2->main;
                    }
                    else
                    {
                        system "cp $input_dir/* $destdir";
                        system
                          "xterm -hold -e 'structuprint $destdir $property'";
                    }
                }
            }
        }
    }
    return 0;
}

sub select_directory
{
    my ( undef, $output_entry ) = @_;
    my $output_dir;
    my $filechooser = Gtk2::FileChooserDialog->new( 'Select Output Directory',
        $window, 'select-folder', 'gtk-cancel', 'cancel', 'gtk-open',
        'accept' );

    my $res = $filechooser->run;
    if ( $res eq 'accept' or $res eq 'accept-filename' )
    {
        $output_dir = $filechooser->get_filename;
        $output_entry->set_text($output_dir);
    }
    $filechooser->destroy;

    return $output_dir;
}

# Select input file. #
sub select_file
{
    my ( undef, $input_entry ) = @_;

    my $filechooser =
      Gtk2::FileChooserDialog->new( 'Select File', $window, 'open',
        'gtk-cancel', 'cancel', 'gtk-open', 'accept' );
    $filechooser->set_select_multiple('TRUE');

    my $res = $filechooser->run;
    if ( $res eq 'accept' or $res eq 'accept-filename' )
    {
        my $input = $filechooser->get_filename;
        $input_entry->set_text($input);
    }
    $filechooser->destroy;

    return 0;
}
