#!/usr/bin/env perl

use strict;
use warnings;

use feature qw(say);

# Import all these modules just to make 
# sure that they are available for packaging.
use Astro::MapProjection;
use Bio::PDB::Structure;
use DBI;
use DBD::SQLite;
use File::Spec;
use File::Copy;
use Getopt::Long;
use Glib;
use Gnome2::Vte;
use Gtk2;
use Gtk2::Gdk::Keysyms;
use Gtk2::Helper;
use Imager;
use Imager::File::TIFF;
use IPC::ShareLite;
use List::Util;
use Math::Round;
use Parallel::ForkManager;
use PAR::Packer;
use Statistics::R;
use Sys::CPU;
use Term::ANSIScreen;
use Term::ProgressBar;

system 'pp -o ../bin/structuprint -c -x ../src/structuprint.pl \
-x ../src/structuprint_frame.pl -x ../src/structuprint_gui.pl';
