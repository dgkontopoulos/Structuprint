#!perl
use strict;
use warnings FATAL => 'all';
use Test::More;

use feature qw(say);

plan tests => 24;

BEGIN
{
    use_ok( 'Astro::MapProjection', qw(miller_projection) )
      || print 'Could not load the used module! ';

    use_ok('DBI') || print 'Could not load the used module! ';

    use_ok('DBD::SQLite') || print 'Could not load the used module! ';

    use_ok('File::Spec') || print 'Could not load the used module! ';

    use_ok( 'File::Copy', qw(copy) )
      || print 'Could not load the used module! ';

    use_ok('Getopt::Long') || print 'Could not load the used module! ';

    use_ok( 'Glib', qw(TRUE FALSE) )
      || print 'Could not load the used module! ';

    use_ok('Gnome2::Vte') || print 'Could not load the used module! ';

    use_ok('Gtk2') || print 'Could not load the used module! ';

    use_ok('Gtk2::Gdk::Keysyms') || print 'Could not load the used module! ';

    use_ok('Gtk2::Helper') || print 'Could not load the used module! ';

    use_ok('Imager') || print 'Could not load the used module! ';

    use_ok('Imager::File::GIF') || print 'Could not load the used module! ';

    use_ok('Imager::File::TIFF') || print 'Could not load the used module! ';

    use_ok('IPC::ShareLite') || print 'Could not load the used module! ';

    use_ok( 'List::Util', qw(min max) )
      || print 'Could not load the used module! ';

    use_ok( 'Math::Round', qw(round nearest nhimult) )
      || print 'Could not load the used module! ';

    use_ok('Parallel::ForkManager') || print 'Could not load the used module! ';

    use_ok( 'Pod::Usage', qw(pod2usage) )
      || print 'Could not load the used module! ';

    use_ok('Statistics::R') || print 'Could not load the used module! ';

    use_ok('Sys::CPU') || print 'Could not load the used module! ';

    use_ok('Term::ANSIScreen') || print 'Could not load the used module! ';

    use_ok('Term::ProgressBar') || print 'Could not load the required module! ';
}

eval { require Bio::PDB::Structure };
if ($@)
{
    require_ok('Bio::PDB::Structure::Atom')
      || print 'Could not load the used module! ';
}
else
{
    require_ok('Bio::PDB::Structure')
      || print 'Could not load the used module! ';
}
