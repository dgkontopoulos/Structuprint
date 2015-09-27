#!/usr/bin/env perl

use strict;
use warnings;

use feature qw(say);

use DBI;
use File::Copy qw(copy);
use Glib qw(TRUE FALSE);
use Gnome2::Vte;
use Gtk2 -init;
use Gtk2::Gdk::Keysyms;
use Gtk2::Helper;
use Sys::CPU;

my $VERSION = 1.001;

my $rootdir = $0;
$rootdir =~ s/\/?structuprint_gui(.pl|.exe)?$//;

starting_popup();

my $window = Gtk2::Window->new('toplevel');
$window->set_title('Structuprint');
$window->set_size_request( 800, 400 );
$window->set_resizable(0);

$window->set_default_icon_from_file( $rootdir . '/images/logo.png' );
$window->signal_connect( destroy => sub { Gtk2->main_quit; exit; } );
$window->set_position('center');

# Enable tooltips. #
my $tooltips    = Gtk2::Tooltips->new();
my $accel_group = Gtk2::AccelGroup->new();
$window->add_accel_group($accel_group);

my $menu_bar = Gtk2::MenuBar->new();

my $current_db              = $rootdir . '/amino_acid_properties.db';
my $no_NC_parameter         = 'off';
my $no_ID_parameter         = 'off';
my $no_legend_parameter     = 'off';
my $del_temp_dirs_parameter = 'off';
my $height_parameter        = 76.56;
my $width_parameter         = 90;
my $resolution_parameter    = 300;
my $legend_title_parameter  = q{};
my $bgcolor_parameter       = '#000000';
my $bgalpha_parameter       = 1;
my $point_size_parameter    = 1;
my $delay_parameter         = 100;
my $nloops_parameter        = 0;
my $nthreads_parameter      = 1;

my $keep_ratio           = 'yes';
my $changed_db_entry_p   = 'no';
my $changed_input_anim   = 'no';
my $changed_input_frame  = 'no';
my $changed_output_anim  = 'no';
my $changed_output_frame = 'no';

my $vbox = Gtk2::VBox->new( '0', '10' );

#######
#File.#
#######
my $menu_item_file = Gtk2::MenuItem->new('_File');

my $menu_file = Gtk2::Menu->new();

# Create the notebook layout (tabs). #
my $notebook = Gtk2::Notebook->new;
$notebook->set_scrollable('TRUE');

# NEW ANIMATION #
my $button_new_anim = Gtk2::Button->new('New Animation');
$tooltips->set_tip( $button_new_anim, 'New structuprint animation' );

my $menu_file_anim = Gtk2::MenuItem->new('New Animation');
$menu_file_anim->add_accelerator( 'activate', $accel_group, ord('N'),
    'control-mask', 'visible' );
$menu_file->append($menu_file_anim);

# NEW FRAME #
my $button_new_frame = Gtk2::Button->new('New Frame');
$tooltips->set_tip( $button_new_frame, 'New structuprint frame' );

my $menu_file_frame = Gtk2::MenuItem->new('New Frame');
my ( $ctrl_shift_n_key, $ctrl_shift_n_mods ) =
  Gtk2::Accelerator->parse('<Ctrl><Shift>N');
$menu_file_frame->add_accelerator( 'activate', $accel_group, $ctrl_shift_n_key,
    $ctrl_shift_n_mods, 'visible' );
$menu_file->append($menu_file_frame);

my $hbox_prop_anim = Gtk2::HBox->new( '0', '20' );
$hbox_prop_anim->set_border_width(3);
my $hbox_prop_frame = Gtk2::HBox->new( '0', '20' );
$hbox_prop_frame->set_border_width(3);

# Select an amino acid property. #
my $label_sel_anim = Gtk2::Label->new('Amino acid property:');
$label_sel_anim->set_alignment( 0.15, 0.5 );
$label_sel_anim->set_size_request( 100, -1 );
$hbox_prop_anim->add($label_sel_anim);

my $label_sel_frame = Gtk2::Label->new('Amino acid property:');
$label_sel_frame->set_alignment( 0.15, 0.5 );
$label_sel_frame->set_size_request( 100, -1 );
$hbox_prop_frame->add($label_sel_frame);

my $combobox_anim = Gtk2::ComboBox->new_text;
$combobox_anim->append_text(q{});
$combobox_anim->set_size_request( 250, -1 );
insert_properties($combobox_anim);

$combobox_anim->signal_connect(
    'changed' => sub {
        $legend_title_parameter = $combobox_anim->get_active_text();
    }
);
$hbox_prop_anim->add($combobox_anim);

my $combobox_frame = Gtk2::ComboBox->new_text;
$combobox_frame->append_text(q{});
$combobox_frame->set_size_request( 250, -1 );
insert_properties($combobox_frame);

$combobox_frame->signal_connect(
    'changed' => sub {
        $legend_title_parameter = $combobox_frame->get_active_text();
    }
);
$hbox_prop_frame->add($combobox_frame);

# Button to codebook. #
my $codebook_button_anim = Gtk2::Button->new;
$codebook_button_anim->set_size_request( 50, -1 );
$codebook_button_anim->set_image(
    Gtk2::Image->new_from_stock( 'gtk-help', 'button' ) );
$codebook_button_anim->signal_connect(
    'clicked' => sub {
        system default_open() . ' "' . $rootdir . '/properties_codebook.pdf"';
    }
);
$tooltips->set_tip( $codebook_button_anim,
    'Open the amino acid properties codebook' );
$hbox_prop_anim->add($codebook_button_anim);

my $codebook_button_frame = Gtk2::Button->new;
$codebook_button_frame->set_size_request( 50, -1 );
$codebook_button_frame->set_image(
    Gtk2::Image->new_from_stock( 'gtk-help', 'button' ) );
$codebook_button_frame->signal_connect(
    'clicked' => sub {
        system default_open() . ' "' . $rootdir . '/properties_codebook.pdf"';
    }
);
$tooltips->set_tip( $codebook_button_frame,
    'Open the amino acid properties codebook' );
$hbox_prop_frame->add($codebook_button_frame);

my $vbox1_anim  = Gtk2::VBox->new( '0', '10' );
my $vbox1_frame = Gtk2::VBox->new( '0', '10' );

$vbox1_anim->add($hbox_prop_anim);
$vbox1_frame->add($hbox_prop_frame);

my $hbox1_anim = Gtk2::HBox->new( '0', '20' );
$hbox1_anim->set_border_width(3);
my $hbox1_frame = Gtk2::HBox->new( '0', '20' );
$hbox1_frame->set_border_width(3);

# Select input directory #
my $input_dir_anim   = q{};
my $label_input_anim = Gtk2::Label->new("Input directory:");
$label_input_anim->set_alignment( 0.1, 0.5 );
$label_input_anim->set_size_request( 100, -1 );

my $input_entry_anim = Gtk2::Entry->new;
$input_entry_anim->set_size_request( 250, -1 );
$input_entry_anim->set_width_chars(24);
$input_entry_anim->signal_connect(
    'key-press-event' => sub {
        my ( undef, $event ) = @_;
        if ( $event->keyval == $Gtk2::Gdk::Keysyms{'Return'} )
        {
            select_directory( 'input', 'anim', 'typing' );
        }
    }
);

$input_entry_anim->signal_connect(
    'changed' => sub {
        $changed_input_anim = 'yes';
    }
);
$input_entry_anim->signal_connect(
    'focus-out-event' => sub {
        if ( $changed_input_anim eq 'yes' )
        {
            $changed_input_anim = 'no';
            Glib::Idle->add(
                sub {
                    select_directory( 'input', 'anim', 'typing' );
                }
            );
        }
        return 0;
    }
);

my $input_button_anim = Gtk2::Button->new_with_label('...');
$input_button_anim->set_size_request( 50, -1 );
$input_entry_anim->set_editable(0);

my $input_dir_frame   = q{};
my $label_input_frame = Gtk2::Label->new("Input directory:");
$label_input_frame->set_alignment( 0.1, 0.5 );
$label_input_frame->set_size_request( 100, -1 );
my $input_entry_frame = Gtk2::Entry->new;
$input_entry_frame->set_size_request( 250, -1 );
$input_entry_frame->set_width_chars(24);
$input_entry_frame->signal_connect(
    'key-press-event' => sub {
        my ( undef, $event ) = @_;
        if ( $event->keyval == $Gtk2::Gdk::Keysyms{'Return'} )
        {
            select_directory( 'input', 'frame', 'typing' );
        }
    }
);

$input_entry_frame->signal_connect(
    'changed' => sub {
        $changed_input_frame = 'yes';
    }
);
$input_entry_frame->signal_connect(
    'focus-out-event' => sub {
        if ( $changed_input_frame eq 'yes' )
        {
            $changed_input_frame = 'no';
            Glib::Idle->add(
                sub {
                    select_directory( 'input', 'frame', 'typing' );
                }
            );
        }
        return 0;
    }
);

my $input_button_frame = Gtk2::Button->new_with_label('...');
$input_button_frame->set_size_request( 50, -1 );
$input_entry_frame->set_editable(0);

$input_button_anim->signal_connect(
    'clicked' => sub {
        select_directory( 'input', 'anim' );
    }
);
$input_button_frame->signal_connect(
    'clicked' => sub {
        select_directory( 'input', 'frame' );
    }
);

$hbox1_anim->add($label_input_anim);
$hbox1_anim->add($input_entry_anim);
$hbox1_anim->add($input_button_anim);
$vbox1_anim->add($hbox1_anim);

$hbox1_frame->add($label_input_frame);
$hbox1_frame->add($input_entry_frame);
$hbox1_frame->add($input_button_frame);
$vbox1_frame->add($hbox1_frame);

my $hbox2_anim = Gtk2::HBox->new( '0', '20' );
$hbox2_anim->set_border_width(3);
my $hbox2_frame = Gtk2::HBox->new( '0', '20' );
$hbox2_frame->set_border_width(3);

# Select an output directory. #
my $output_dir_anim = q{};
my $label_dir_anim  = Gtk2::Label->new("Output directory:");
$label_dir_anim->set_alignment( 0.1, 0.5 );
$label_dir_anim->set_size_request( 100, -1 );
$hbox2_anim->add($label_dir_anim);

my $label_dir_frame = Gtk2::Label->new("Output directory:");
$label_dir_frame->set_alignment( 0.1, 0.5 );
$label_dir_frame->set_size_request( 100, -1 );
$hbox2_frame->add($label_dir_frame);

my $output_entry_anim = Gtk2::Entry->new;
$output_entry_anim->set_size_request( 250, -1 );
$output_entry_anim->set_width_chars(24);
$output_entry_anim->set_editable(0);
$output_entry_anim->signal_connect(
    'key-press-event' => sub {
        my ( undef, $event ) = @_;
        if ( $event->keyval == $Gtk2::Gdk::Keysyms{'Return'} )
        {
            select_directory( 'output', 'anim', 'typing' );
        }
    }
);

$output_entry_anim->signal_connect(
    'changed' => sub {
        $changed_output_anim = 'yes';
    }
);
$output_entry_anim->signal_connect(
    'focus-out-event' => sub {
        if ( $changed_output_anim eq 'yes' )
        {
            $changed_output_anim = 'no';
            Glib::Idle->add(
                sub {
                    select_directory( 'output', 'anim', 'typing' );
                }
            );
        }
        return 0;
    }
);

my $output_dir_frame   = q{};
my $output_entry_frame = Gtk2::Entry->new;
$output_entry_frame->set_size_request( 250, -1 );
$output_entry_frame->set_width_chars(24);
$output_entry_frame->set_editable(0);
$output_entry_frame->signal_connect(
    'key-press-event' => sub {
        my ( undef, $event ) = @_;
        if ( $event->keyval == $Gtk2::Gdk::Keysyms{'Return'} )
        {
            select_directory( 'output', 'frame', 'typing' );
        }
    }
);

$output_entry_frame->signal_connect(
    'changed' => sub {
        $changed_output_frame = 'yes';
    }
);
$output_entry_frame->signal_connect(
    'focus-out-event' => sub {
        if ( $changed_output_frame eq 'yes' )
        {
            $changed_output_frame = 'no';
            Glib::Idle->add(
                sub {
                    select_directory( 'output', 'frame', 'typing' );
                }
            );
        }
        return 0;
    }
);

my $active_tab = 0;

$menu_file_anim->signal_connect(
    'activate' => sub {
        restore_everything();
        $notebook->set_current_page(0);
    }
);

$menu_file_frame->signal_connect(
    'activate' => sub {
        restore_everything();
        $notebook->set_current_page(1);
    }
);

$button_new_anim->signal_connect(
    'clicked' => sub {
        restore_everything();
        $notebook->set_current_page(0);
    }
);

$button_new_frame->signal_connect(
    'clicked' => sub {
        restore_everything();
        $notebook->set_current_page(1);
    }
);

$hbox2_anim->add($output_entry_anim);
$hbox2_frame->add($output_entry_frame);

my $dir_button_anim = Gtk2::Button->new_with_label('...');
$dir_button_anim->set_size_request( 50, -1 );
$hbox2_anim->add($dir_button_anim);

my $dir_button_frame = Gtk2::Button->new_with_label('...');
$dir_button_frame->set_size_request( 50, -1 );
$hbox2_frame->add($dir_button_frame);

$dir_button_anim->signal_connect(
    'clicked' => sub {
        select_directory( 'output', 'anim' );
    }
);
$dir_button_frame->signal_connect(
    'clicked' => sub {
        select_directory( 'output', 'frame' );
    }
);

$vbox1_anim->add($hbox2_anim);
$vbox1_frame->add($hbox2_frame);

#############################
# Number of threads option. #
#############################
my $hbox_nthreads = Gtk2::HBox->new( '0', '20' );
$hbox_nthreads->set_border_width(3);
my $label_nthreads = Gtk2::Label->new('Number of threads:');
$label_nthreads->set_alignment( 0.1, 0.5 );
$label_nthreads->set_size_request( 80, -1 );
$hbox_nthreads->add($label_nthreads);

my $cpu_count = Sys::CPU::cpu_count();

my $threads_slider;
if ( defined $cpu_count and $cpu_count > 1 )
{
    $threads_slider = Gtk2::HScale->new_with_range( 1, $cpu_count, 1 );
    $threads_slider->signal_connect(
        'value_changed' => sub {
            $nthreads_parameter = $threads_slider->get_value();
        }
    );
    $threads_slider->set_size_request( 420, -1 );
    $hbox_nthreads->add($threads_slider);
    $vbox1_anim->add($hbox_nthreads);
}
else
{
    $vbox1_anim->add( Gtk2::Label->new() );
}

########################################
# Delete temporary directories option. #
########################################
my $hbox_no_temp_dirs = Gtk2::HBox->new( '0', '0' );
$hbox_no_temp_dirs->set_border_width(3);

my $check_no_temp_dirs =
  Gtk2::CheckButton->new("Delete temporary directories.");
$check_no_temp_dirs->signal_connect(
    toggled => sub {
        if ( $del_temp_dirs_parameter eq 'off' )
        {
            $del_temp_dirs_parameter = 'on';
            $check_no_temp_dirs->set_active(1);
        }
        else
        {
            $del_temp_dirs_parameter = 'off';
            $check_no_temp_dirs->set_active(0);
        }
    }
);

$hbox_no_temp_dirs->add($check_no_temp_dirs);
$vbox1_anim->add($hbox_no_temp_dirs);

my $hbox3_anim = Gtk2::HBox->new( '0', '20' );
$hbox3_anim->add($vbox1_anim);

my $hbox3_frame = Gtk2::HBox->new( '0', '20' );
$hbox3_frame->add($vbox1_frame);

# Start button. #
my $hbox_last_buttons_anim  = Gtk2::HBox->new( '0', '20' );
my $hbox_last_buttons_frame = Gtk2::HBox->new( '0', '20' );

my $adv_button_anim = Gtk2::Button->new_with_label('Advanced options');
$adv_button_anim->signal_connect( clicked => \&advanced_options );
$hbox_last_buttons_anim->add($adv_button_anim);

my $start_button_anim = Gtk2::Button->new_with_label('Run!');
$hbox_last_buttons_anim->add($start_button_anim);

my $adv_button_frame = Gtk2::Button->new_with_label('Advanced options');
$adv_button_frame->signal_connect( clicked => \&advanced_options );
$hbox_last_buttons_frame->add($adv_button_frame);

my $start_button_frame = Gtk2::Button->new_with_label('Run!');
$hbox_last_buttons_frame->add($start_button_frame);

my $running = 'no';
my ( $scrolled_terminal, $terminal );

my $animation_page = Gtk2::Frame->new();
my $frame_page     = Gtk2::Frame->new();

my $menu_file_run  = Gtk2::MenuItem->new('_Run!');
my $menu_file_stop = Gtk2::MenuItem->new('Sto_p!');

# Start button action. #
$start_button_anim->signal_connect(
    'clicked' => sub {
        if ( $running eq 'no' )
        {
            $menu_file_run->set_sensitive(0);
            $menu_file_stop->set_sensitive(1);

            $running = 'yes';
            $start_button_anim->set_label('Stop!');
            $frame_page->set_sensitive(0);
            prepare_execution('anim');
        }
        else
        {
            if ( defined $terminal )
            {
                $terminal->destroy();
                $vbox->remove($scrolled_terminal);
            }

            $menu_file_run->set_sensitive(1);
            $menu_file_stop->set_sensitive(0);

            $output_entry_anim->set_text(q{});
            $output_dir_anim = q{};
            $window->set_size_request( 800, 400 );
            $running = 'no';
            $start_button_anim->set_label('Run!');
            $frame_page->set_sensitive(1);
        }
    }
);

$start_button_frame->signal_connect(
    'clicked' => sub {
        if ( $running eq 'no' )
        {
            $menu_file_run->set_sensitive(0);
            $menu_file_stop->set_sensitive(1);

            $running = 'yes';
            $start_button_frame->set_label('Stop!');
            $animation_page->set_sensitive(0);
            prepare_execution('frame');
        }
        else
        {
            if ( defined $terminal )
            {
                $terminal->destroy();
                $vbox->remove($scrolled_terminal);
            }

            $menu_file_run->set_sensitive(1);
            $menu_file_stop->set_sensitive(0);

            $window->set_size_request( 800, 400 );
            $running = 'no';
            $start_button_frame->set_label('Run!');
            $animation_page->set_sensitive(1);
        }
    }
);

$vbox1_anim->add($hbox_last_buttons_anim);
$vbox1_frame->add($hbox_last_buttons_frame);

for ( 0 .. 3 )
{
    $vbox1_frame->add( Gtk2::Label->new(q{}) );
}

# Horizontal separator for menu. #
$menu_file->append( Gtk2::SeparatorMenuItem->new );

my $menu_file_adv_opt = Gtk2::MenuItem->new('_Advanced options');
$menu_file_adv_opt->signal_connect( activate => \&advanced_options );
my ( $ctrl_alt_a_key, $ctrl_alt_a_mods ) =
  Gtk2::Accelerator->parse('<Ctrl><Alt>A');
$menu_file_adv_opt->add_accelerator( 'activate', $accel_group, $ctrl_alt_a_key,
    $ctrl_alt_a_mods, 'visible' );

$menu_file->append($menu_file_adv_opt);

$menu_file_run->add_accelerator( 'activate', $accel_group, ord('R'),
    'control-mask', 'visible' );
$menu_file_run->signal_connect(
    'activate' => sub {
        $menu_file_run->set_sensitive(0);
        $menu_file_stop->set_sensitive(1);
        $running = 'yes';
        if ( $notebook->get_current_page == 0 )
        {
            $start_button_anim->set_label('Stop!');
            $frame_page->set_sensitive(0);
            prepare_execution('anim');
        }
        else
        {
            $start_button_frame->set_label('Stop!');
            $animation_page->set_sensitive(0);
            prepare_execution('frame');
        }
    }
);
$menu_file->append($menu_file_run);

my ( $ctrl_shift_c_key, $ctrl_shift_c_mods ) =
  Gtk2::Accelerator->parse('<Ctrl><Shift>C');
$menu_file_stop->add_accelerator( 'activate', $accel_group, $ctrl_shift_c_key,
    $ctrl_shift_c_mods, 'visible' );
$menu_file_stop->signal_connect(
    'activate' => sub {
        if ( defined $terminal )
        {
            $terminal->destroy();
            $vbox->remove($scrolled_terminal);
        }
        $menu_file_run->set_sensitive(1);
        $menu_file_stop->set_sensitive(0);
        $window->set_size_request( 800, 400 );

        if ( $notebook->get_current_page == 0 )
        {
            $output_entry_anim->set_text(q{});
            $output_dir_anim = q{};
            $start_button_anim->set_label('Run!');
            $frame_page->set_sensitive(1);
        }
        else
        {
            $start_button_frame->set_label('Run!');
            $animation_page->set_sensitive(1);
        }
        $running = 'no';

    }
);
$menu_file->append($menu_file_stop);
$menu_file_stop->set_sensitive(0);

$menu_file->append( Gtk2::SeparatorMenuItem->new );

# Quit structuprint. #
my $menu_file_quit = Gtk2::MenuItem->new('Quit');
$menu_file_quit->signal_connect( activate => sub { Gtk2->main_quit(); exit; } );
$menu_file_quit->add_accelerator( 'activate', $accel_group, ord('Q'),
    'control-mask', 'visible' );
$menu_file->append($menu_file_quit);

$menu_item_file->set_submenu($menu_file);
$menu_bar->append($menu_item_file);

#######
#Help.#
#######
my $menu_item_help = Gtk2::MenuItem->new('_Help');
my $menu_help      = Gtk2::Menu->new();

# Amino acid properties codebook. #
my $menu_help_documentation = Gtk2::MenuItem->new('Documentation');
$menu_help_documentation->signal_connect( 'activate' =>
      sub { system default_open() . ' "' . $rootdir . '/documentation.pdf"' } );
$menu_help->append($menu_help_documentation);

my $menu_help_codebook = Gtk2::MenuItem->new('Amino acid properties codebook');
$menu_help_codebook->signal_connect(
    'activate' => sub {
        system default_open() . ' "' . $rootdir . '/properties_codebook.pdf"';
    }
);
$menu_help->append($menu_help_codebook);

$menu_help->append( Gtk2::SeparatorMenuItem->new() );

# About Perl. #
my $menu_help_Perl = Gtk2::MenuItem->new('About Perl');
$menu_help_Perl->signal_connect( 'activate' =>
      sub { system default_open() . ' http://www.perl.org/about.html &' } );
$menu_help->append($menu_help_Perl);

# About gtk2-perl. #
my $menu_help_gtk2 = Gtk2::MenuItem->new('About gtk2-perl');
$menu_help_gtk2->signal_connect( 'activate' =>
      sub { system default_open() . ' http://gtk2-perl.sourceforge.net/ &' } );
$menu_help->append($menu_help_gtk2);

# About R. #
my $menu_help_R = Gtk2::MenuItem->new('About R');
$menu_help_R->signal_connect( 'activate' =>
      sub { system default_open() . ' http://www.r-project.org/about.html &' }
);
$menu_help->append($menu_help_R);

# Horizontal separator. #
$menu_help->append( Gtk2::SeparatorMenuItem->new() );

# About structuprint. #
my $menu_help_about = Gtk2::MenuItem->new('About Structuprint');
$menu_help_about->signal_connect( 'activate' => \&about );
my ( $alt_a_key, $alt_a_mods ) = Gtk2::Accelerator->parse('<Alt>A');
$menu_help_about->add_accelerator( 'activate', $accel_group, $alt_a_key,
    $alt_a_mods, 'visible' );
$menu_help->append($menu_help_about);

$menu_item_help->set_submenu($menu_help);
$menu_bar->append($menu_item_help);
$vbox->add($menu_bar);

my $hbox1 = Gtk2::HBox->new( '0', '5' );
$hbox1->add($button_new_anim);
$hbox1->add($button_new_frame);

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
$tooltips->set_tip( $exit_button, 'Quit Structuprint' );
$hbox1->add($exit_button);

$vbox->add($hbox1);

# Animation tab: add main items. #
$animation_page->add($hbox3_anim);
$notebook->append_page( $animation_page,
    Gtk2::Label->new("\t\t\t\tAnimation\t\t\t\t") );

# Frame tab: add main items #
$frame_page->add($hbox3_frame);
$notebook->append_page( $frame_page,
    Gtk2::Label->new("\t\t\t\tFrame\t\t\t\t") );

$vbox->add($notebook);

my $scrolled_window = Gtk2::ScrolledWindow->new();
$scrolled_window->add_with_viewport($vbox);

$window->add($scrolled_window);
$window->show_all;
Gtk2->main;

END
{

    # Make sure that no temporary scripts were left!
    unlink glob '/tmp/.structuprint_*.sh';
}

#######################################################
# S    U    B    R    O    U    T    I    N    E    S #
#######################################################

sub about
{
    my $window = Gtk2::Window->new('toplevel');
    $window->set_title('About Structuprint');
    $window->set_default_icon_from_file( $rootdir . '/images/logo.png' );
    $window->signal_connect( destroy => sub { Gtk2->main_quit() } );
    $window->signal_connect(
        'key_press_event' => sub {
            my ( undef, $event ) = @_;
            if ( $event->keyval eq $Gtk2::Gdk::Keysyms{'Escape'} )
            {
                $window->destroy;
            }
        }
    );
    $window->set_resizable(0);
    $window->set_position('center');

    my $hbox0 = Gtk2::HBox->new( 0, 20 );
    my $logo = Gtk2::Image->new_from_file( $rootdir . '/images/logo.png' );
    $hbox0->add($logo);

    my $top_info = <<"ABOUT";
<b>Structuprint</b>, v$VERSION
<a href='https://dgkontopoulos.github.io/Structuprint/'>Website</a> --- <a href='https://github.com/dgkontopoulos/Structuprint'>Source Code</a>

&#169; 2012-15
<a href="mailto:dgkontopoulos\@gmail.com?Subject=Structuprint">Dimitrios - Georgios Kontopoulos</a>,
<a href="mailto:dvlachakis\@bioacademy.gr?Subject=Structuprint">Dimitrios Vlachakis</a>,
<a href="mailto:gtsiliki\@central.ntua.gr?Subject=Structuprint">Georgia Tsiliki</a>,
<a href="mailto:sofia.kossida\@igh.cnrs.fr?Subject=Structuprint">Sofia Kossida</a>
ABOUT
    chomp $top_info;
    my $second_info = <<'ABOUT';
<span size="small">
<b>Structuprint</b> is a tool for generating two-dimensional animations 
and still figures of protein surfaces.

The code is written in <a href="http://www.perl.org/">Perl</a>/<a href="http://gtk2-perl.sourceforge.net/">GTK2</a> and <a href="http://www.r-project.org/">R.</a></span>
ABOUT
    chomp $second_info;
    $second_info =~ s/(>+)\n(<+|$)/$1$2/g;
    my $license = <<'ABOUT';
<span size="small"><b><u>License:</u></b>
<i>This program is free software; you can redistribute it and/or modify it under the terms
of the <a href="http://www.gnu.org/licenses/gpl-3.0.html">GNU General Public License, as published by the Free Software Foundation; either
version 3 of the License, or (at your option) any later version</a>.

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
    $window->add($vbox);

    $window->show_all;
    Gtk2->main;
    return 0;
}

sub advanced_options
{
    my $window = Gtk2::Window->new('toplevel');
    $window->set_title('Advanced options');
    $window->set_default_icon_from_file( $rootdir . '/images/logo.png' );
    $window->signal_connect( destroy => sub { $window->destroy() } );
    $window->signal_connect(
        'key_press_event' => sub {
            my ( undef, $event ) = @_;
            if ( $event->keyval eq $Gtk2::Gdk::Keysyms{'Escape'} )
            {
                $window->destroy;
            }
        }
    );

    $window->set_resizable(0);
    $window->set_border_width(5);

    $window->set_position('center');

    # Create the notebook layout (tabs). #
    my $notebook = Gtk2::Notebook->new;
    $notebook->set_scrollable('TRUE');

    # GENERAL TAB #
    my $general_page = Gtk2::Frame->new();
    my $vbox_general = Gtk2::VBox->new( '0', '3' );

    my $dimensions_label = Gtk2::Label->new();
    $dimensions_label->set_markup("<b>Dimensions</b>");
    $dimensions_label->set_alignment( 0, 0.5 );
    $vbox_general->add($dimensions_label);

    my $hbox_width = Gtk2::HBox->new( '0', '5' );
    my $width_label = Gtk2::Label->new("Width (mm):");
    $width_label->set_alignment( 0.1, 0.5 );
    $width_label->set_size_request( 55, -1 );
    $hbox_width->add($width_label);

    my $width_adj =
      Gtk2::Adjustment->new( $width_parameter, 1, 9999, 0.01, 1, 0.0 );
    my $width_spinner = Gtk2::SpinButton->new( $width_adj, 0, 2 );
    $width_spinner->set_size_request( 80, -1 );
    $hbox_width->add($width_spinner);
    $vbox_general->add($hbox_width);

    my $hbox_height = Gtk2::HBox->new( '0', '5' );
    my $height_label = Gtk2::Label->new("Height (mm):");
    $height_label->set_alignment( 0.1, 0.5 );
    $height_label->set_size_request( 55, -1 );
    $hbox_height->add($height_label);

    my $height_adj =
      Gtk2::Adjustment->new( $height_parameter, 1, 9999, 0.01, 1, 0.0 );
    my $height_spinner = Gtk2::SpinButton->new( $height_adj, 0, 2 );
    $height_spinner->set_size_request( 80, -1 );

    my $i_changed_it_myself = 'no';

    $width_spinner->signal_connect(
        'value-changed' => sub {
            if ( $keep_ratio eq 'yes' and $i_changed_it_myself eq 'no' )
            {
                $height_parameter =
                  ( $width_spinner->get_value() * $height_parameter ) /
                  $width_parameter;
                $i_changed_it_myself = 'yes';
                $height_spinner->set_value($height_parameter);
                $i_changed_it_myself = 'no';
            }
            $width_parameter = $width_spinner->get_value();
        }
    );
    $height_spinner->signal_connect(
        'value-changed' => sub {
            if ( $keep_ratio eq 'yes' and $i_changed_it_myself eq 'no' )
            {
                $width_parameter =
                  ( $height_spinner->get_value() * $width_parameter ) /
                  $height_parameter;
                $i_changed_it_myself = 'yes';
                $width_spinner->set_value($width_parameter);
                $i_changed_it_myself = 'no';
            }
            $height_parameter = $height_spinner->get_value();
        }
    );

    $hbox_height->add($height_spinner);
    $vbox_general->add($hbox_height);

    my $hbox_ratio = Gtk2::HBox->new( '0', '5' );
    $hbox_ratio->add( Gtk2::Label->new() );
    $hbox_ratio->set_size_request( 150, -1 );
    my $check_ratio =
      Gtk2::CheckButton->new("Keep the width-to-height ratio\t\t");
    if ( $keep_ratio eq 'yes' )
    {
        $check_ratio->set_active(1);
    }

    $check_ratio->signal_connect(
        'toggled' => sub {
            if ( $keep_ratio eq 'yes' )
            {
                $keep_ratio = 'no';
            }
            else
            {
                $keep_ratio = 'yes';
            }
        }
    );

    $hbox_ratio->add($check_ratio);
    $vbox_general->add($hbox_ratio);

    my $hbox_res = Gtk2::HBox->new( '0', '5' );
    my $res_label = Gtk2::Label->new("Resolution (ppi):");
    $res_label->set_alignment( 0.1, 0.5 );
    $res_label->set_size_request( 55, -1 );
    $hbox_res->add($res_label);

    my $res_adj =
      Gtk2::Adjustment->new( $resolution_parameter, 1, 9999, 0.1, 1, 0.0 );
    my $res_spinner = Gtk2::SpinButton->new( $res_adj, 0, 1 );
    $res_spinner->set_size_request( 80, -1 );
    $res_spinner->signal_connect(
        'value-changed' => sub {
            $resolution_parameter = $res_spinner->get_value();
        }
    );
    $hbox_res->add($res_spinner);
    $vbox_general->add($hbox_res);

    $vbox_general->add( Gtk2::Label->new(q{}) );

    my $plot_elements_label = Gtk2::Label->new();
    $plot_elements_label->set_markup("<b>Figure elements</b>");
    $plot_elements_label->set_alignment( 0, 0.5 );
    $vbox_general->add($plot_elements_label);

    my $hbox_no_NC = Gtk2::HBox->new( '0', '5' );
    $hbox_no_NC->add( Gtk2::Label->new(q{             }) );
    $hbox_no_NC->set_size_request( 55, -1 );
    my $check_no_NC =
      Gtk2::CheckButton->new("Hide the N/C-termini\t\t\t\t\t\t\t\t");

    if ( $no_NC_parameter eq 'on' )
    {
        $check_no_NC->set_active(1);
    }

    $check_no_NC->signal_connect(
        toggled => sub {
            if ( $no_NC_parameter eq 'on' )
            {
                $no_NC_parameter = 'off';
                $check_no_NC->set_active(0);
            }
            else
            {
                $no_NC_parameter = 'on';
                $check_no_NC->set_active(1);
            }
        }
    );

    $hbox_no_NC->add($check_no_NC);
    $hbox_no_NC->add( Gtk2::Label->new() );
    $vbox_general->add($hbox_no_NC);

    my $hbox_no_ID = Gtk2::HBox->new( '0', '5' );
    $hbox_no_ID->set_size_request( 55, -1 );
    $hbox_no_ID->add( Gtk2::Label->new(q{             }) );
    my $check_no_ID =
      Gtk2::CheckButton->new("Hide the ID number\t\t\t\t\t\t\t\t");

    if ( $no_ID_parameter eq 'on' )
    {
        $check_no_ID->set_active(1);
    }

    $check_no_ID->signal_connect(
        toggled => sub {
            if ( $no_ID_parameter eq 'off' )
            {
                $no_ID_parameter = 'on';
                $check_no_ID->set_active(1);
            }
            else
            {
                $no_ID_parameter = 'off';
                $check_no_ID->set_active(0);
            }
        }
    );

    $hbox_no_ID->add($check_no_ID);
    $hbox_no_ID->add( Gtk2::Label->new() );
    $vbox_general->add($hbox_no_ID);

    my $hbox_no_legend = Gtk2::HBox->new( '0', '5' );
    $hbox_no_legend->set_size_request( 55, -1 );
    $hbox_no_legend->add( Gtk2::Label->new(q{   }) );
    my $check_no_legend =
      Gtk2::CheckButton->new("Hide the legend\t\t\t\t\t\t    ");

    if ( $no_legend_parameter eq 'on' )
    {
        $check_no_legend->set_active(1);
    }

    $hbox_no_legend->add($check_no_legend);
    $hbox_no_legend->add( Gtk2::Label->new() );
    $vbox_general->add($hbox_no_legend);

    my $hbox_legend_title = Gtk2::HBox->new( '0', '5' );
    my $label_legend_title = Gtk2::Label->new("Legend title:");
    $label_legend_title->set_alignment( 0.1, 0.5 );
    $label_legend_title->set_size_request( 55, -1 );
    $hbox_legend_title->add($label_legend_title);

    my $entry_legend_title = Gtk2::Entry->new();

    if ( $no_legend_parameter eq 'on' )
    {
        $entry_legend_title->set_sensitive(0);
    }

    $entry_legend_title->set_width_chars(20);
    $entry_legend_title->set_text($legend_title_parameter);
    $entry_legend_title->set_size_request( 80, -1 );
    $entry_legend_title->signal_connect(
        'changed' => sub {
            $legend_title_parameter = $entry_legend_title->get_text();
        }
    );

    $hbox_legend_title->add($entry_legend_title);
    $vbox_general->add($hbox_legend_title);

    $check_no_legend->signal_connect(
        toggled => sub {
            if ( $no_legend_parameter eq 'on' )
            {
                $no_legend_parameter = 'off';
                $entry_legend_title->set_sensitive(1);
                $check_no_legend->set_active(0);

                if ( $keep_ratio eq 'yes' )
                {
                    $height_parameter    = $width_parameter / 1.3639 * 1.16;
                    $i_changed_it_myself = 'yes';
                    $height_spinner->set_value($height_parameter);
                    $i_changed_it_myself = 'no';
                }
            }
            else
            {
                $no_legend_parameter = 'on';
                $entry_legend_title->set_sensitive(0);
                $check_no_legend->set_active(1);

                if ( $keep_ratio eq 'yes' )
                {
                    $height_parameter    = $width_parameter / 1.3639;
                    $i_changed_it_myself = 'yes';
                    $height_spinner->set_value($height_parameter);
                    $i_changed_it_myself = 'no';
                }
            }
        }
    );

    my $hbox_bg_color = Gtk2::HBox->new( '0', '5' );
    my $label_bg_color = Gtk2::Label->new('Background colour:');
    $label_bg_color->set_alignment( 0.3, 0.5 );
    $label_bg_color->set_size_request( 55, -1 );
    $hbox_bg_color->add($label_bg_color);

    my $button_bg_color = Gtk2::Button->new_with_label($bgcolor_parameter);
    $button_bg_color->set_size_request( 80, -1 );
    $button_bg_color->signal_connect(
        'clicked' => sub {
            my $color_window = Gtk2::ColorSelectionDialog->new(
                'Select a background color for structuprints');
            my $selection = $color_window->get_color_selection;
            $selection->set_current_color(
                Gtk2::Gdk::Color->parse($bgcolor_parameter) );

            # We don't need a help button here.
            $color_window->help_button->destroy;

            $color_window->ok_button->signal_connect(
                'clicked' => sub {
                    $bgcolor_parameter =
                      $selection->get_current_color->to_string;
                    $bgcolor_parameter =~
                      s/#(\w{2})\w{2}(\w{2})\w{2}(\w{2})\w{2}$/#$1$2$3/;
                    $button_bg_color->set_label($bgcolor_parameter);
                    $color_window->destroy;
                }
            );

            $color_window->cancel_button->signal_connect(
                'clicked' => sub {
                    $color_window->destroy;
                }
            );

            $color_window->show_all;
        }
    );
    $hbox_bg_color->add($button_bg_color);
    $vbox_general->add($hbox_bg_color);

    my $hbox_bg_alpha = Gtk2::HBox->new( '0', '5' );
    my $label_bg_alpha = Gtk2::Label->new('Background alpha:');
    $label_bg_alpha->set_alignment( 0.2, 0.5 );
    $label_bg_alpha->set_size_request( 55, -1 );
    $hbox_bg_alpha->add($label_bg_alpha);

    my $alpha_slider = Gtk2::HScale->new_with_range( 0, 1, 0.01 );
    $alpha_slider->set_size_request( 80, -1 );
    $alpha_slider->set_value($bgalpha_parameter);
    $alpha_slider->signal_connect(
        'value_changed' => sub {
            $bgalpha_parameter = $alpha_slider->get_value();
        }
    );
    $hbox_bg_alpha->add($alpha_slider);

    $vbox_general->add($hbox_bg_alpha);

    my $hbox_point_size = Gtk2::HBox->new( '0', '5' );
    my $label_point_size = Gtk2::Label->new("Point size:");
    $label_point_size->set_alignment( 0.08, 0.5 );
    $label_point_size->set_size_request( 55, -1 );
    $hbox_point_size->add($label_point_size);

    my $point_adj =
      Gtk2::Adjustment->new( $point_size_parameter, 0.1, 9999, 0.1, 1, 0.0 );
    my $point_spinner = Gtk2::SpinButton->new( $point_adj, 0, 1 );
    $point_spinner->set_size_request( 80, -1 );
    $point_spinner->signal_connect(
        'value-changed' => sub {
            $point_size_parameter = $point_spinner->get_value();
        }
    );
    $hbox_point_size->add($point_spinner);
    $vbox_general->add($hbox_point_size);

    $general_page->add($vbox_general);

    $notebook->append_page( $general_page, 'General' );

    # PROPERTIES TAB #
    my $properties_page = Gtk2::Frame->new();
    $notebook->append_page( $properties_page, 'Amino acid properties' );

    my $vbox_properties = Gtk2::VBox->new( '0', '3' );

    my $database_label = Gtk2::Label->new();
    $database_label->set_markup("<b>Database</b>");
    $database_label->set_alignment( 0, 0.5 );
    $vbox_properties->add($database_label);

    my $hbox_custom_db = Gtk2::HBox->new( '0', '5' );
    my $label_custom_db = Gtk2::Label->new('Custom db:');
    $label_custom_db->set_alignment( 0.2, 0.5 );
    $label_custom_db->set_size_request( 80, -1 );
    $hbox_custom_db->add($label_custom_db);

    my $entry_custom_db = Gtk2::Entry->new();
    $entry_custom_db->set_text($current_db);
    $entry_custom_db->set_size_request( 180, -1 );
    $entry_custom_db->set_width_chars(15);
    $hbox_custom_db->add($entry_custom_db);

    my $button_custom_db = Gtk2::Button->new_with_label('...');
    $button_custom_db->set_size_request( 5, -1 );
    $button_custom_db->signal_connect(
        clicked => sub {
            database_change( $window, $entry_custom_db );
        }
    );

    $entry_custom_db->signal_connect(
        'key-press-event' => sub {
            my ( undef, $event ) = @_;
            if ( $event->keyval == $Gtk2::Gdk::Keysyms{'Return'} )
            {
                database_change( $window, $entry_custom_db, 'typing' );
            }
        }
    );

    $entry_custom_db->signal_connect(
        'changed' => sub {
            $changed_db_entry_p = 'yes';
        }
    );
    $entry_custom_db->signal_connect(
        'focus-out-event' => sub {
            if ( $changed_db_entry_p eq 'yes' )
            {
                $changed_db_entry_p = 'no';
                Glib::Idle->add(
                    sub {
                        database_change( $window, $entry_custom_db, 'typing' );
                    }
                );
            }
            return 0;
        }
    );

    $hbox_custom_db->add($button_custom_db);
    $vbox_properties->add($hbox_custom_db);

    my $hbox_default_db = Gtk2::HBox->new( '0', '5' );
    $hbox_default_db->add( Gtk2::Label->new(q{}) );

    my $button_default =
      Gtk2::Button->new_with_label('Use the default database');
    $button_default->set_size_request( 323, -1 );
    $button_default->signal_connect(
        clicked => sub {
            $current_db = $rootdir . '/amino_acid_properties.db';
            $entry_custom_db->set_text($current_db);

            $combobox_anim->get_model->clear();
            $combobox_anim->append_text(q{});

            $combobox_frame->get_model->clear();
            $combobox_frame->append_text(q{});

            insert_properties($combobox_anim);
            insert_properties($combobox_frame);
        }
    );
    $hbox_default_db->add($button_default);
    $vbox_properties->add($hbox_default_db);

    for ( 0 .. 12 )
    {
        $vbox_properties->add( Gtk2::Label->new(q{}) );
    }

    $properties_page->add($vbox_properties);

    # ANIMATION TAB #
    my $animation_page = Gtk2::Frame->new();
    $notebook->append_page( $animation_page, 'Animation' );

    my $vbox_animation = Gtk2::VBox->new( '0', '3' );

    my $label_gif = Gtk2::Label->new();
    $label_gif->set_markup("<b>GIF options</b>");
    $label_gif->set_alignment( 0, 0.5 );
    $vbox_animation->add($label_gif);

    my $hbox_delay = Gtk2::HBox->new( '0', '5' );
    my $label_delay = Gtk2::Label->new("Delay between frames (ms):");
    $label_delay->set_alignment( 0.1, 0.5 );
    $label_delay->set_size_request( 130, -1 );
    $hbox_delay->add($label_delay);

    my $delay_adj =
      Gtk2::Adjustment->new( $delay_parameter, 1, 9999, 1, 1, 0.0 );
    my $delay_spinner = Gtk2::SpinButton->new( $delay_adj, 0, 0 );
    $delay_spinner->set_size_request( 5, -1 );
    $delay_spinner->signal_connect(
        'value-changed' => sub {
            $delay_parameter = $delay_spinner->get_value();
        }
    );
    $hbox_delay->add($delay_spinner);
    $vbox_animation->add($hbox_delay);

    my $hbox_nloops = Gtk2::HBox->new( '0', '5' );
    my $label_nloops = Gtk2::Label->new('Number of loops (0 = infinite):');
    $label_nloops->set_alignment( 0.2, 0.5 );
    $label_nloops->set_size_request( 130, -1 );
    $hbox_nloops->add($label_nloops);

    my $nloops_adj =
      Gtk2::Adjustment->new( $nloops_parameter, 0, 9999, 1, 1, 0.0 );
    my $nloops_spinner = Gtk2::SpinButton->new( $nloops_adj, 0, 0 );
    $nloops_spinner->set_size_request( 5, -1 );
    $nloops_spinner->signal_connect(
        'value-changed' => sub {
            $nloops_parameter = $nloops_spinner->get_value();
        }
    );
    $hbox_nloops->add($nloops_spinner);
    $vbox_animation->add($hbox_nloops);

    for ( 0 .. 12 )
    {
        $vbox_animation->add( Gtk2::Label->new(q{}) );
    }

    $animation_page->add($vbox_animation);

    my $vbox = Gtk2::VBox->new();
    $vbox->add($notebook);

    my $quit_button = Gtk2::Button->new();
    $quit_button->set_image(
        Gtk2::Image->new_from_stock( 'gtk-quit', 'large-toolbar' ) );
    $quit_button->signal_connect( clicked => sub { $window->destroy; } );

    my $hbox_quit = Gtk2::HBox->new();
    $hbox_quit->add( Gtk2::Label->new(q{}) );
    $hbox_quit->add($quit_button);
    $hbox_quit->add( Gtk2::Label->new(q{}) );

    $vbox->add($hbox_quit);

    $window->add($vbox);

    $window->show_all;
    Gtk2->main;
    return 0;
}

sub database_change
{
    my ( $window, $entry_custom_db, $typing ) = @_;

    my ( $status, $db, $properties );
    if ( !( defined $typing ) )
    {
        ( $status, $db, $properties ) = select_custom_db();
    }
    else
    {
        ( $status, $db, $properties ) =
          check_custom_database( $entry_custom_db->get_text() );
    }

    if ( $status eq 'success' )
    {
        $current_db = $db;
        $entry_custom_db->set_text($current_db);

        $combobox_anim->get_model->clear();
        $combobox_anim->append_text(q{});

        $combobox_frame->get_model->clear();
        $combobox_frame->append_text(q{});

        insert_properties( $combobox_anim,  $properties );
        insert_properties( $combobox_frame, $properties );
        $window->present();
        success_message_properties( 'properties_found', scalar @{$properties} );
    }
    else
    {
        $entry_custom_db->set_text($current_db);
        $window->present();
    }

    $changed_db_entry_p = 'no';

    return 0;
}

sub check_custom_database
{
    my ($database) = @_;

    if ( !( -e $database ) || -z $database || !( -f $database ) )
    {
        error_message('db_does_not_exist_or_empty');
        return 'failure';
    }

    my $properties;
    eval { $properties = get_properties($database); };

    if ($@)
    {
        error_message('could_not_find_properties_in_db');
        return 'failure';
    }

    if ( scalar @{$properties} >= 1 )
    {
        return 'success', $database, $properties;
    }
    else
    {
        error_message('empty_db');
        return 'failure';
    }
    return 'failure';
}

sub check_results
{
    my ($anim_or_frame) = @_;

    sleep 1;
    if ( $anim_or_frame eq 'anim' )
    {
        if (   -e $output_dir_anim . '/final_output/animation.gif'
            && -s $output_dir_anim . '/final_output/animation.gif' )
        {
            success_message_run($anim_or_frame);
        }
        else
        {
            error_message('execution_error_anim');
        }
    }
    else
    {
        if (   -e $output_dir_frame . '/structuprint.tiff'
            && -s $output_dir_frame . '/structuprint.tiff' )
        {
            success_message_run($anim_or_frame);
        }
        else
        {
            error_message('execution_error_frame');
        }
    }
    return 0;
}

sub error_message
{
    my ($error_input) = @_;

    # Throw an error. #
    my $error_window = Gtk2::Window->new('popup');
    $error_window->set_position('center');
    $error_window->set_border_width(10);

    my $vbox  = Gtk2::VBox->new( '0', '10' );
    my $hbox1 = Gtk2::HBox->new( '0', '5' );

    # Error logo. #
    my $error = Gtk2::Image->new_from_stock( 'gtk-dialog-error', 'dialog' );
    $hbox1->add($error);

    # Error text. #
    my $error_label = Gtk2::Label->new;

    my %error_messages = (
        'no_property_selected' => << 'END',
<b>ERROR!</b>
No amino acid property has been selected!
END
        'input_dir_not_r' => << 'END',
<b>ERROR!</b>
The input directory is not readable!
END
        'no_input_dir' => << 'END',
<b>ERROR!</b>
No input directory has been selected!
END
        'no_output_dir' => << 'END',
<b>ERROR!</b>
No output directory has been selected!
END
        'output_dir_not_rw' => << 'END',
<b>ERROR!</b>
The output directory is either not readable
or not writable (or both)!
END
        'output_dir_not_empty' => << 'END',
<b>ERROR!</b>
The output directory is not empty!
END
        'no_suitable_pdbs_for_anim' => << 'END',
<b>ERROR!</b>
The input PDB filename(s) should contain an underscore
and a number before the pdb extension!

eg: mds_1.pdb, mds_2.pdb ... mds_40.pdb
END
        'no_pdb_for_frame' => << 'END',
<b>ERROR!</b>
A PDB file could not be found in that directory!
The input PDB filename should end with ".pdb".
END
        'more_than_one_pdb' => << 'END',
<b>ERROR!</b>
More than one PDB files were found in that directory!
Would you like to create an animation instead?
END
        'db_does_not_exist_or_empty' => << 'END',
<b>ERROR!</b>
This file does not exist or is empty!
END
        'execution_error_anim' => << 'END',
<b>ERROR!</b>
Something went wrong and the animation could not 
be produced! Check the log files!
END
        'execution_error_frame' => << 'END',
Something went wrong and the structuprint could 
not be produced! Check the log file!
END
    );

    my $error_text = $error_messages{$error_input};
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
    return 0;
}

sub get_properties
{
    my ($db_path) = @_;

    if ( !( defined $db_path ) )
    {
        $db_path = $current_db;
    }

    my $dbh = DBI->connect( 'dbi:SQLite:' . $db_path, q{}, q{} );

    my $db_sel =
      $dbh->prepare('Select name from sqlite_master where type = "table"');
    $db_sel->execute();
    my $properties = $db_sel->fetchall_arrayref;
    $dbh->disconnect();

    my @properties;
    my $index = 0;
    while ( $properties->[$index] )
    {
        push @properties, $properties->[$index]->[0];
        $index++;
    }
    return \@properties;
}

# Insert all available properties into the combobox. #
sub insert_properties
{
    my ( $combobox, $properties ) = @_;

    if ( !( defined $properties ) )
    {
        $properties = get_properties();
    }

    foreach ( @{$properties} )
    {
        $combobox->append_text($_);
    }
    return 0;
}

sub proper_dir_p
{
    my ( $dir, $type, $anim_or_frame ) = @_;

    if ( $type eq 'output' )
    {
        if ( !( -r $dir ) || !( -w $dir ) )
        {
            error_message('output_dir_not_rw');
            return 2;
        }

        if ( $anim_or_frame eq 'anim' )
        {
            opendir my ($fh), $dir;
            while ( readdir $fh )
            {
                if ( $_ ne q{.} and $_ ne q{..} )
                {
                    error_message('output_dir_not_empty');
                    return 1;
                }
            }
        }
    }
    elsif ( $type eq 'input' )
    {
        if ( !( -r $dir ) )
        {
            error_message('input_dir_not_r');
            return 2;
        }

        opendir my ($fh), $dir;

        if ( $anim_or_frame eq 'anim' )
        {
            while ( readdir $fh )
            {
                if (/_\d+[.]pdb$/)
                {
                    return 0;
                }
            }
            error_message('no_suitable_pdbs_for_anim');
            return 1;
        }
        else
        {
            my $pdb_counter = 0;
            while ( readdir $fh )
            {
                if (/[.]pdb$/)
                {
                    $pdb_counter++;
                }
            }

            if ( $pdb_counter == 0 )
            {
                error_message('no_pdb_for_frame');
                return 1;
            }
            elsif ( $pdb_counter > 1 )
            {
                error_message('more_than_one_pdb');
                return 1;
            }
        }
    }
    return 0;
}

# Check that everything is ready for structuprint to run. #
sub prepare_execution
{
    my ($anim_or_frame) = @_;

    my $command = q{};
    if ( $anim_or_frame eq 'anim' )
    {
        $command .= $rootdir . '/structuprint ';

        if ( !( defined $input_dir_anim ) || $input_dir_anim eq q{} )
        {
            error_message('no_input_dir');
            $running = 'no';
            $start_button_anim->set_label('Run!');
            $frame_page->set_sensitive(1);
            $menu_file_run->set_sensitive(1);
            $menu_file_stop->set_sensitive(0);
            return 0;
        }
        else
        {
            $command .= "-dir '$input_dir_anim' ";
        }

        if ( !( defined $output_dir_anim ) || $output_dir_anim eq q{} )
        {
            error_message('no_output_dir');
            $running = 'no';
            $start_button_anim->set_label('Run!');
            $frame_page->set_sensitive(1);
            $menu_file_run->set_sensitive(1);
            $menu_file_stop->set_sensitive(0);
            return 0;
        }
        else
        {
            $command .= "-outdir '$output_dir_anim' ";
        }

        $command .= "-nthreads $nthreads_parameter ";
    }
    else
    {
        $command .= $rootdir . '/structuprint_frame ';

        if ( !( defined $input_dir_frame ) || $input_dir_frame eq q{} )
        {
            error_message('no_input_dir');
            $running = 'no';
            $start_button_frame->set_label('Run!');
            $animation_page->set_sensitive(1);
            $menu_file_run->set_sensitive(1);
            $menu_file_stop->set_sensitive(0);
            return 0;
        }
        else
        {
            $command .= "-dir '$input_dir_frame' ";
        }

        if ( !( defined $output_dir_frame ) || $output_dir_frame eq q{} )
        {
            error_message('no_output_dir');
            $running = 'no';
            $start_button_frame->set_label('Run!');
            $animation_page->set_sensitive(1);
            $menu_file_run->set_sensitive(1);
            $menu_file_stop->set_sensitive(0);
            return 0;
        }
        else
        {
            $command .= "-outdir '$output_dir_frame' ";
        }
    }

    my $selected_property;
    if ( $anim_or_frame eq 'anim' )
    {
        $selected_property = $combobox_anim->get_active_text();
    }
    else
    {
        $selected_property = $combobox_frame->get_active_text();
    }

    if ( !( defined $selected_property ) || $selected_property eq q{} )
    {
        error_message('no_property_selected');

        if ( $anim_or_frame eq 'anim' )
        {
            $start_button_anim->set_label('Run!');
            $frame_page->set_sensitive(1);
        }
        else
        {
            $start_button_frame->set_label('Run!');
            $animation_page->set_sensitive(1);
        }
        $menu_file_run->set_sensitive(1);
        $menu_file_stop->set_sensitive(0);
        $running = 'no';
        return 0;
    }
    else
    {
        $command .= "-prop '$selected_property' ";
    }

    if ( $no_NC_parameter eq 'on' )
    {
        $command .= '--no_NC ';
    }

    if ( $no_ID_parameter eq 'on' )
    {
        $command .= '--no_id ';
    }

    if ( $no_legend_parameter eq 'on' )
    {
        $command .= '--no_legend ';
    }

    if ( $del_temp_dirs_parameter eq 'on' and $anim_or_frame eq 'anim' )
    {
        $command .= '--del_temp_dirs ';
    }

    if ( $anim_or_frame eq 'anim' )
    {
        $delay_parameter =~ s/,/./;
        $command .= "-delay $delay_parameter -nloops $nloops_parameter ";
    }

    if ( $current_db ne $rootdir . '/amino_acid_properties.db' )
    {
        $command .= "-custom_db '$current_db' ";
    }

    $height_parameter =~ s/,/./;
    $command .= "-height $height_parameter ";

    $width_parameter =~ s/,/./;
    $command .= "-width $width_parameter ";

    $resolution_parameter =~ s/,/./;
    $command .= "-res $resolution_parameter ";
    $command .= "-legend_title '$legend_title_parameter' ";
    $command .= "-bgcol '$bgcolor_parameter' ";

    $bgalpha_parameter =~ s/,/./;
    $command .= "-bgalpha $bgalpha_parameter ";

    $point_size_parameter =~ s/,/./;
    $command .= "-point_size $point_size_parameter ";

    my $temp_script = '/tmp/.structuprint_' . time . '.sh';

    $scrolled_terminal = Gtk2::ScrolledWindow->new( undef, undef );
    $scrolled_terminal->set_size_request( 800, 180 );

    $terminal = Gnome2::Vte::Terminal->new();
    $terminal->signal_connect(
        child_exited => sub {
            unlink $temp_script;
            check_results($anim_or_frame);

            $window->set_size_request( 800, 400 );
            $running = 'no';

            if ( $anim_or_frame eq 'anim' )
            {
                $start_button_anim->set_label('Run!');
                $frame_page->set_sensitive(1);
            }
            else
            {
                $start_button_frame->set_label('Run!');
                $animation_page->set_sensitive(1);
            }
            $menu_file_run->set_sensitive(1);
            $menu_file_stop->set_sensitive(0);

            $terminal->destroy();
            $vbox->remove($scrolled_terminal);
        }
    );

    $scrolled_terminal->add($terminal);
    $vbox->add($scrolled_terminal);

    $window->set_size_request( 800, 580 );
    $window->show_all();

    open my $fh, '>', $temp_script or die $!;
    print {$fh} $command;
    close $fh;

    $terminal->fork_command( '/bin/bash', [ 'bash', $temp_script ],
        undef, q{./}, FALSE, FALSE, FALSE );
    return 0;
}

sub select_directory
{
    my ( $type, $anim_or_frame, $typing ) = @_;

    my ( $status, $db, $properties );
    if ( !( defined $typing ) )
    {
        my $filechooser =
          Gtk2::FileChooserDialog->new( "Select $type Directory",
            $window, 'select-folder', 'gtk-cancel', 'cancel', 'gtk-open',
            'accept' );
        my $res = $filechooser->run;
        if ( $res eq 'accept' or $res eq 'accept-filename' )
        {
            if ( $type eq 'input' )
            {
                if (
                    proper_dir_p( $filechooser->get_filename,
                        $type, $anim_or_frame ) == 0
                  )
                {
                    if ( $anim_or_frame eq 'anim' )
                    {
                        $input_dir_anim = $filechooser->get_filename();
                        $input_entry_anim->set_text($input_dir_anim);
                        $filechooser->destroy;

                        $changed_input_anim = 'no';
                        return $input_dir_anim;
                    }
                    else
                    {
                        $input_dir_frame = $filechooser->get_filename();
                        $input_entry_frame->set_text($input_dir_frame);
                        $filechooser->destroy;

                        $changed_input_frame = 'no';
                        return $input_dir_frame;
                    }
                }
                else
                {
                    $filechooser->destroy;
                }
            }
            elsif ( $type eq 'output' )
            {
                if (
                    proper_dir_p( $filechooser->get_filename,
                        $type, $anim_or_frame ) == 0
                  )
                {
                    if ( $anim_or_frame eq 'anim' )
                    {
                        $output_dir_anim = $filechooser->get_filename();
                        $output_entry_anim->set_text($output_dir_anim);
                        $filechooser->destroy;

                        $changed_output_anim = 'no';
                        return $output_dir_anim;
                    }
                    else
                    {
                        $output_dir_frame = $filechooser->get_filename();
                        $output_entry_frame->set_text($output_dir_frame);
                        $filechooser->destroy;

                        $changed_output_frame = 'no';
                        return $output_dir_frame;
                    }
                }
                else
                {
                    $filechooser->destroy;
                }
            }
        }
        else
        {
            $filechooser->destroy;
        }
    }
    else
    {
        if ( $type eq 'input' )
        {
            if ( $anim_or_frame eq 'anim' )
            {
                if (
                    proper_dir_p(
                        $input_entry_anim->get_text(), $type,
                        $anim_or_frame
                    ) == 0
                  )
                {
                    $input_dir_anim = $input_entry_anim->get_text();
                    return $input_dir_anim;
                }
                else
                {
                    $input_entry_anim->set_text($input_dir_anim);
                }
                $changed_input_anim = 'no';
            }
            else
            {
                if (
                    proper_dir_p(
                        $input_entry_frame->get_text(), $type,
                        $anim_or_frame
                    ) == 0
                  )
                {
                    $input_dir_frame = $input_entry_frame->get_text();
                    return $input_dir_frame;
                }
                else
                {
                    $input_entry_frame->set_text($input_dir_frame);
                }
                $changed_input_frame = 'no';
            }
        }
        else
        {
            if ( $anim_or_frame eq 'anim' )
            {
                if (
                    proper_dir_p(
                        $output_entry_anim->get_text(), $type,
                        $anim_or_frame
                    ) == 0
                  )
                {
                    $output_dir_anim = $output_entry_anim->get_text();
                    return $output_dir_anim;
                }
                else
                {
                    $output_entry_anim->set_text($output_dir_anim);
                }
                $changed_output_anim = 'no';
            }
            else
            {
                if (
                    proper_dir_p(
                        $output_entry_frame->get_text(), $type,
                        $anim_or_frame
                    ) == 0
                  )
                {
                    $output_dir_frame = $output_entry_frame->get_text();
                    return $output_dir_frame;
                }
                else
                {
                    $output_entry_frame->set_text($output_dir_frame);
                }
                $changed_output_frame = 'no';
            }
        }
    }

    return 0;
}

sub restore_everything
{
    $current_db = $rootdir . '/amino_acid_properties.db';

    $combobox_anim->get_model->clear();
    $combobox_anim->append_text(q{});
    $combobox_frame->get_model->clear();
    $combobox_frame->append_text(q{});

    insert_properties($combobox_anim);
    insert_properties($combobox_frame);

    $combobox_anim->set_active(0);
    $combobox_frame->set_active(0);

    $input_entry_anim->set_text(q{});
    $output_entry_anim->set_text(q{});
    $input_entry_frame->set_text(q{});
    $output_entry_frame->set_text(q{});
    $threads_slider->set_value(1);
    $no_NC_parameter         = 'off';
    $no_ID_parameter         = 'off';
    $no_legend_parameter     = 'off';
    $del_temp_dirs_parameter = 'off';
    $height_parameter        = 76.56;
    $width_parameter         = 90;
    $resolution_parameter    = 300;
    $legend_title_parameter  = q{};
    $bgcolor_parameter       = '#000000';
    $bgalpha_parameter       = 1;
    $point_size_parameter    = 1;
    $delay_parameter         = 100;
    $nloops_parameter        = 0;
    $keep_ratio              = 'yes';

    return 0;
}

sub select_custom_db
{
    my $filechooser =
      Gtk2::FileChooserDialog->new( 'Select an amino acid database',
        $window, 'open', 'gtk-cancel', 'cancel', 'gtk-open', 'accept' );

    my $filter = Gtk2::FileFilter->new();
    $filter->set_name('SQLite database (*.db, *.sqlite, *.sqlite3)');
    $filter->add_pattern('.db');
    $filter->add_pattern('.DB');
    $filter->add_pattern('.sqlite');
    $filter->add_pattern('.SQLite');
    $filter->add_pattern('.sqlite3');
    $filter->add_pattern('.SQLite3');
    $filter->add_mime_type('application/x-sqlite3');

    $filechooser->add_filter($filter);

    my $res = $filechooser->run;
    my $selected_db;
    if ( $res eq 'accept' or $res eq 'accept-filename' )
    {
        $selected_db = $filechooser->get_filename;
        $filechooser->destroy;
        return check_custom_database($selected_db);
    }

    $filechooser->destroy;
    return 0;
}

sub starting_popup
{
    my $window = Gtk2::Window->new('popup');
    $window->set_border_width(10);

    my $vbox = Gtk2::VBox->new();
    $vbox->add( Gtk2::Label->new() );
    my $logo = Gtk2::Image->new_from_file( $rootdir . '/images/splash.png' );
    $vbox->add($logo);

    my $version_label = Gtk2::Label->new( 'version ' . $VERSION );
    $vbox->add($version_label);

    my $copyright_label = Gtk2::Label->new();
    $copyright_label->set_markup(<<"END");

<small><b>&#169; 2012-15</b> Kontopoulos D.-G., Vlachakis D., Tsiliki G &amp; Kossida S.</small>
END
    $copyright_label->set_justify('center');
    $vbox->add($copyright_label);
    $window->add($vbox);

    $window->set_default_icon_from_file( $rootdir . '/images/logo.png' );
    $window->signal_connect( destroy => sub { Gtk2->main_quit(); } );
    $window->set_position('center');
    $window->show_all();

    Glib::Timeout->add(
        3000,
        sub {
            $window->destroy;
            return 0;
        }
    );
    Gtk2->main;

    return 0;
}

sub success_message_properties
{
    my ( $id, $other_params ) = @_;

    my $success_window = Gtk2::Window->new('popup');
    $success_window->set_position('center');
    $success_window->set_border_width(10);

    my $vbox  = Gtk2::VBox->new( '0', '10' );
    my $hbox1 = Gtk2::HBox->new( '0', '5' );

    # Success logo. #
    my $success = Gtk2::Image->new_from_stock( 'gtk-dialog-info', 'dialog' );
    $hbox1->add($success);

    # Success text. #
    my $success_label = Gtk2::Label->new;
    my $success_text;

    if ( $id eq 'properties_found' )
    {
        $success_text = << "END";
<b>SUCCESS!</b>
$other_params properties were found!
END
    }
    chomp $success_text;

    $success_label->set_markup($success_text);
    $success_label->set_justify('center');
    $hbox1->add($success_label);

    $vbox->add($hbox1);

    # Ok button. #
    my $ok_hbox = Gtk2::HBox->new();
    $ok_hbox->add( Gtk2::Label->new() );

    my $ok_button = Gtk2::Button->new('OK');
    $ok_button->signal_connect( 'clicked' => sub { $success_window->destroy; }
    );
    $ok_hbox->add($ok_button);
    $ok_hbox->add( Gtk2::Label->new() );

    $vbox->add($ok_hbox);

    $success_window->add($vbox);
    $success_window->show_all;
    return 0;
}

sub success_message_run
{
    my ($anim_or_frame) = @_;
    my $success_window = Gtk2::Window->new('popup');
    $success_window->set_position('center');
    $success_window->set_border_width(10);

    my $vbox  = Gtk2::VBox->new( '0', '10' );
    my $hbox1 = Gtk2::HBox->new( '0', '5' );

    # Success logo. #
    my $success = Gtk2::Image->new_from_stock( 'gtk-apply', 'dialog' );
    $hbox1->add($success);

    # Success text. #
    my $success_label = Gtk2::Label->new;
    my $success_text;

    if ( $anim_or_frame eq 'anim' )
    {
        $success_text = << 'END';
<b>SUCCESS!</b>
Would you like to see the resulting animation?
END
    }
    else
    {
        $success_text = << 'END';
<b>SUCCESS!</b>
Would you like to see the resulting structuprint?
END
    }

    chomp $success_text;
    $success_label->set_markup($success_text);
    $success_label->set_justify('center');
    $hbox1->add($success_label);

    $vbox->add($hbox1);

    my $hbox_buttons = Gtk2::HBox->new( '0', '5' );

    my $yes_button = Gtk2::Button->new('Yes');
    $yes_button->signal_connect(
        'clicked' => sub {

            if ( $anim_or_frame eq 'anim' )
            {
                system default_open() . ' "'
                  . $output_dir_anim
                  . '/final_output/animation.gif' . q{" &};

                $output_entry_anim->set_text(q{});
                $output_dir_anim = q{};
            }
            else
            {
                system default_open() . ' "'
                  . $output_dir_frame
                  . '/structuprint.tiff' . q{" &};
            }
            $success_window->destroy;
        }
    );
    $hbox_buttons->add($yes_button);

    my $no_button = Gtk2::Button->new('No');
    $no_button->signal_connect(
        'clicked' => sub {
            if ( $anim_or_frame eq 'anim' )
            {
                $output_entry_anim->set_text(q{});
                $output_dir_anim = q{};
            }
            $success_window->destroy;
        }
    );
    $hbox_buttons->add($no_button);

    $vbox->add($hbox_buttons);

    $success_window->add($vbox);
    $success_window->show_all;
}

sub default_open
{
    if ( $^O eq 'linux' )
    {
        return 'xdg-open';
    }
    elsif ( $^O eq 'MSWin32' )
    {
        return 'start';
    }
    elsif ( $^O eq 'darwin' )
    {
        return 'open';
    }
}
