Summary:	Utility for 2D visualisation of PDB structures
Name:		structuprint
Version:	1.01
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/Science
Source:		structuprint-1.01.tar.gz
Requires:	perl, perl-DBI, perl-DBD-SQLite, perl-Gtk2, perl-Math-Round, perl-PathTools, perl-IPC-Run, perl-Scalar-List-Utils, perl-Regexp-Common, R, ImageMagick, gifsicle, xterm
buildroot:	/opt/structuprint/

%description
Structuprint is a utility for analysis of MD simulations 
(and single PDB structures as well), offering a novel 2D 
visualisation technique. Its output may be a single frame 
or a full-blown animation, depending on input.

%prep
%setup -q

%build
chmod 755 structuprint.pl
chmod 755 structuprint_frame.pl
chmod 755 structuprint_gui.pl

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/opt/structuprint/R_libs/
cp structuprint.pl %{buildroot}/opt/structuprint/
cp structuprint_frame.pl %{buildroot}/opt/structuprint/
cp structuprint_gui.pl %{buildroot}/opt/structuprint/
cp amino_acid_properties.db %{buildroot}/opt/structuprint/
tar -xzvf R_libs.tar.gz
cp -R R_libs/* %{buildroot}/opt/structuprint/R_libs/
cp props.txt %{buildroot}/opt/structuprint/
cp codebook.pdf %{buildroot}/opt/structuprint/
mkdir -p %{buildroot}/opt/structuprint/images/
cp -R images/* %{buildroot}/opt/structuprint/images/

mkdir -p %{buildroot}/usr/share/applications/
cp structuprint.desktop %{buildroot}/usr/share/applications/

mkdir -p %{buildroot}/usr/bin/
cp structuprint %{buildroot}/usr/bin/
chmod +x %{buildroot}/usr/bin/structuprint
cp structuprint_frame %{buildroot}/usr/bin/
chmod +x %{buildroot}/usr/bin/structuprint_frame

mkdir -p %{buildroot}/tmp/structuprint/
cp RPMs/* %{buildroot}/tmp/structuprint/
cd %{buildroot}/tmp/structuprint/ && rpm2cpio libastro-mapprojection-perl-0.01-2.i386.rpm | cpio -dimv
cp -R %{buildroot}/tmp/structuprint/usr/* %{buildroot}/usr/

mkdir -p %{buildroot}/usr/lib/perl5/Astro/
mkdir -p %{buildroot}/usr/lib/perl5/auto/Astro/MapProjection/

cp %{buildroot}/usr/lib/perl5/vendor_perl/5.16.0/i586-linux-thread-multi/auto/Astro/MapProjection/* %{buildroot}/usr/lib/perl5/auto/Astro/MapProjection/
cp %{buildroot}/usr/lib/perl5/vendor_perl/5.16.0/i586-linux-thread-multi/Astro/* %{buildroot}/usr/lib/perl5/Astro/

rm -rf %{buildroot}/tmp/structuprint/usr/
cd %{buildroot}/tmp/structuprint/ && rpm2cpio libbio-pdb-structure-perl-0.02-2.noarch.rpm | cpio -dimv
cp -R %{buildroot}/tmp/structuprint/usr/* %{buildroot}/usr/
rm -rf %{buildroot}/tmp/structuprint/usr/
cd %{buildroot}/tmp/structuprint/ && rpm2cpio libstatistics-r-perl-0.30-2.noarch.rpm | cpio -dimv
cp -R %{buildroot}/tmp/structuprint/usr/* %{buildroot}/usr/
rm -rf %{buildroot}/tmp/structuprint/
rm -rf %{buildroot}/tmp/	

%clean
rm -rf %{buildroot}/opt/structuprint/
rm -rf %{buildroot}/usr/bin/structuprint
rm -rf %{buildroot}/usr/bin/structuprint_frame

%files
/usr/bin/structuprint
/usr/bin/structuprint_frame
/opt/structuprint/*
/usr/lib/perl5/Astro/*
/usr/lib/perl5/auto/Astro/MapProjection/*
/usr/lib/perl/5.14/perllocal.pod
/usr/lib/perl5/vendor_perl/5.16.0/i586-linux-thread-multi/Astro/MapProjection.pm
/usr/lib/perl5/vendor_perl/5.16.0/i586-linux-thread-multi/auto/Astro/MapProjection/MapProjection.bs
/usr/lib/perl5/vendor_perl/5.16.0/i586-linux-thread-multi/auto/Astro/MapProjection/MapProjection.so
/usr/share/doc/packages/perl-Astro-MapProjection/Changes
/usr/share/doc/packages/perl-Astro-MapProjection/README
/usr/share/man/man3/Astro::MapProjection.3pm.gz
/usr/share/doc/libbio-pdb-structure-perl/changelog.Debian.gz
/usr/share/doc/libbio-pdb-structure-perl/copyright
/usr/share/man/man3/Astro::MapProjection.3pm.gz
/usr/lib/perl5/auto/Bio/PDB/Structure/.packlist
/usr/share/man/man3/Bio::PDB::Structure.3pm.gz
/usr/share/perl5/Bio/PDB/Structure.pm
/usr/share/doc/libstatistics-r-perl/README.gz
/usr/share/doc/libstatistics-r-perl/changelog.Debian.gz
/usr/share/doc/libstatistics-r-perl/copyright
/usr/share/man/man3/Statistics::R.3pm.gz
/usr/share/man/man3/Statistics::R::Legacy.3pm.gz
/usr/share/man/man3/Statistics::R::Win32.3pm.gz
/usr/share/perl5/Statistics/R.pm
/usr/share/perl5/Statistics/R/Legacy.pm
/usr/share/perl5/Statistics/R/Win32.pm
/usr/share/applications/structuprint.desktop
