#!/usr/bin/env perl

use strict;
use warnings;

use feature qw(say);

use DBI;
use File::Copy qw(copy);
use File::Path qw(make_path remove_tree);

get_deb_systems();
get_rpm_systems();

#######################################################
# S    U    B    R    O    U    T    I    N    E    S #
#######################################################

sub build_deb
{
    my ($row) = @_;

    my $os_name     = $row->[0];
    my $arch        = $row->[1];
    my $app_version = $row->[11];

    # Create the directory structure for deb packaging.
    remove_tree('./tmp/') or die $!;

    make_path('./tmp/structuprint/debian/source') or die $!;

    # Match files with their contents.
    my %file_contents = (
        'debian/source/format' => $row->[2],
        'debian/changelog'     => $row->[3],
        'debian/compat'        => $row->[4],
        'debian/control'       => $row->[5],
        'debian/copyright'     => $row->[6],
        'debian/rules'         => $row->[7],
        'Makefile'             => $row->[8],
    );

    # Open each file and write its respective contents.
    foreach ( keys %file_contents )
    {
        open my $fh, '>', './tmp/structuprint/' . $_ or die $!;
        print {$fh} $file_contents{$_};
        close $fh;
    }

    # Prepare the debs of any Perl modules required for this build.
    if ( defined $row->[9] )
    {
        mkdir './tmp/structuprint/DEBS' or die $!;
        open my $fh, '>', './tmp/structuprint/DEBS/Perl_debs.tar.gz' or die $!;
        print {$fh} $row->[9];
        close $fh;

        system
'tar xzf "./tmp/structuprint/DEBS/Perl_debs.tar.gz" -C "./tmp/structuprint/DEBS/"';
    }

    # Prepare any prebuilt R packages required for this build.
    if ( defined $row->[10] )
    {
        mkdir './tmp/structuprint/R_packages' or die $!;
        open my $fh, '>', './tmp/structuprint/R_packages/R_pkgs.tar.gz'
          or die $!;
        print {$fh} $row->[10];
        close $fh;

        system
'tar xzf "./tmp/structuprint/R_packages/R_pkgs.tar.gz" -C "./tmp/structuprint/R_packages/"';
    }
    
    if ( defined $row->[12] )
    {
        open my $fh, '>', './tmp/structuprint/structuprint'
          or die $!;
        print {$fh} $row->[12];
        close $fh;
    }

    copy_src_files_deb($arch);

    local $ENV{'DEB_BUILD_OPTIONS'} = 'nostrip';

    if ( $arch eq '64' )
    {
        system 'cd ./tmp/structuprint/ && debuild -us -uc';
    }
    elsif ( $arch eq '32' )
    {
        system 'cd ./tmp/structuprint/ && debuild -ai386 -us -uc';
    }

    system 'mv ./tmp/*.deb '
      . '../packages/structuprint_'
      . $app_version . q{_}
      . $os_name . q{_}
      . $arch . '.deb';

    # Remove the temporary directory structure.
    remove_tree('./tmp/') or die $!;

    # Re-create the tmp directory.
    mkdir './tmp/' or die $!;

    return 0;
}

sub build_rpm
{
    my ($row) = @_;

    my $os_name     = $row->[0];
    my $arch        = $row->[1];
    my $app_version = $row->[4];

    # Create the directory structure for deb packaging.
    remove_tree('./tmp/') or die $!;

    make_path('./tmp/BUILD')                                  or die $!;
    make_path('./tmp/RPMS')                                   or die $!;
    make_path( './tmp/SOURCES/structuprint-' . $app_version ) or die $!;
    make_path('./tmp/SPECS')                                  or die $!;
    make_path('./tmp/SRPMS')                                  or die $!;
    
    # Write the spec file.
    open my $fh, '>', './tmp/SPECS/structuprint.spec' or die $!;
    print {$fh} $row->[2];
    close $fh;

    # Prepare any prebuilt R packages required for this build.
    if ( defined $row->[3] )
    {
        open my $fh, '>',
          './tmp/SOURCES/structuprint-' . $app_version . '/R_pkgs.tar.gz'
          or die $!;
        print {$fh} $row->[3];
        close $fh;

        system
"tar xzf './tmp/SOURCES/structuprint-$app_version/R_pkgs.tar.gz' -C './tmp/SOURCES/structuprint-$app_version/'";

        unlink './tmp/SOURCES/structuprint-' . $app_version . '/R_pkgs.tar.gz'
          or die $!;
    }
    
    if ( defined $row->[5] )
    {
		open my $fh, '>', './tmp/SOURCES/structuprint-' . $app_version . '/structuprint' or die $!;
		print {$fh} $row->[5];
		close $fh;
	}

    copy_src_files_rpm($app_version);
    exit;

    # Remove the temporary directory structure.
    remove_tree('./tmp/') or die $!;

    # Re-create the tmp directory.
    mkdir './tmp/' or die $!;

    return 0;
}

sub copy_src_files_deb
{
    my ($arch) = @_;

    # Add any other files.
    foreach (
        'amino_acid_properties.db', 'props.txt',
        'structuprint.desktop',     'structuprint_launcher'
      )
    {
        copy "../src/$_", "./tmp/structuprint/$_" or die $!;
    }

    copy '../documentation/documentation.pdf',
      './tmp/structuprint/documentation.pdf'
      or die $!;
    copy '../documentation/properties_codebook.pdf',
      './tmp/structuprint/properties_codebook.pdf'
      or die $!;

    mkdir './tmp/structuprint/images' or die $!;
    copy '../src/images/logo.png', './tmp/structuprint/images/logo.png'
      or die $!;
    copy '../src/images/splash.png', './tmp/structuprint/images/splash.png'
      or die $!;

    return 0;
}

sub copy_src_files_rpm
{
    my ($app_version) = @_;

    my $distr_dir = './tmp/SOURCES/structuprint-' . $app_version;

    # Add any other files.
    foreach (
        'amino_acid_properties.db', 'props.txt',
        'structuprint.desktop',     'structuprint_launcher',
        'structuprint.pl',          'structuprint_frame.pl',
      )
    {
        copy "../src/$_", "$distr_dir/$_" or die $!;
    }

    copy '../documentation/documentation.pdf', $distr_dir . '/documentation.pdf'
      or die $!;
    copy '../documentation/properties_codebook.pdf',
      $distr_dir . '/properties_codebook.pdf'
      or die $!;

    mkdir $distr_dir . '/images' or die $!;
    copy '../src/images/logo.png', $distr_dir . '/images/logo.png'
      or die $!;
    copy '../src/images/splash.png', $distr_dir . '/images/splash.png'
      or die $!;

    system
"tar cf ./tmp/SOURCES/structuprint-$app_version.tar -C ./tmp/SOURCES/ structuprint-$app_version";
    system "gzip ./tmp/SOURCES/structuprint-$app_version.tar";

    remove_tree( './tmp/SOURCES/structuprint-' . $app_version ) or die $!;
    return 0;
}

sub get_deb_systems
{
    my $dbh = DBI->connect( 'dbi:SQLite:./supported_systems.sqlite', q{}, q{} );

    my $sth = $dbh->prepare('SELECT * FROM DEB');
    $sth->execute();

    my $systems = $sth->fetchall_arrayref;
    foreach my $row ( @{$systems} )
    {
        my $os_name     = $row->[0];
        my $arch        = $row->[1];
        my $app_version = $row->[11];

        my $deb_file =
            '../packages/structuprint_'
          . $app_version . q{_}
          . $os_name . q{_}
          . $arch . '.deb';
        unless ( -e $deb_file )
        {
            build_deb($row);
        }
    }

    return 0;
}

sub get_rpm_systems
{
    my $dbh = DBI->connect( 'dbi:SQLite:./supported_systems.sqlite', q{}, q{} );

    my $sth = $dbh->prepare('SELECT * FROM RPM');
    $sth->execute();

    my $systems = $sth->fetchall_arrayref;
    foreach my $row ( @{$systems} )
    {
        my $os_name     = $row->[0];
        my $arch        = $row->[1];
        my $app_version = $row->[4];

        my $rpm_file =
            '../packages/structuprint_'
          . $app_version . q{_}
          . $os_name . q{_}
          . $arch . '.rpm';
        unless ( -e $rpm_file )
        {
            build_rpm($row);
        }
    }
    return 0;
}

sub handle_entry
{
    my ($file) = @_;

    open my $fh, '<', './supported_systems/' . $file or die $!;

    my @lines;
    while (<$fh>)
    {
        push @lines, $_;
    }

    close $fh;

    if ( $lines[0] =~ /Ubuntu|Debian/i )
    {
        build_deb();
    }
    elsif ( $lines[0] =~ /Fedora|OpenSuse/i )
    {
        build_rpm();
    }
}

sub installed_program_p
{
    my ($app) = @_;

    print "Checking for $app... ";
    if ( grep { -x "$_/$app" } split /:/, $ENV{PATH} )
    {
        say 'OK';
        return 'installed';
    }
    else
    {
        say "\n\t$app is not installed! Aborting.";
        return 0;
    }
}

sub installed_ubuntu_package_p
{
    my ($package) = @_;

    print "Checking for $package... ";
    if ( `dpkg -l | grep $package` eq q{} )
    {
        say "\n\t$package is not installed! Aborting.";
        return 0;
    }
    else
    {
        say 'OK';
        return 'installed';
    }
}

sub install_perl_deps
{
    say "\nInstalling Perl dependencies...\n";

    my $command = <<'END';
cpanm --mirror-only --mirror https://stratopan.com/dgkontopoulos/Structuprint/build
Astro::MapProjection
DBI
DBD::SQLite
File::Spec
File::Copy
Getopt::Long
Imager
IPC::ShareLite
List::Util
Math::Round
Parallel::ForkManager
Statistics::R
Term::ProgressBar
END

    $command =~ s/\n/ /g;
    system $command;
    system 'cpanm deps/Bio-PDB-Structure-0.02.tar.gz';

    return 0;
}
