Summary:	Command line tool for 2D surface plotting of PDB structures
Name:		structuprint
Version:	0.01
Release:	1%{?dist}
License:	GPLv2+
Group:		Applications/Science
Source:		structuprint-0.01.tar.gz
Requires:	perl, perl-DBI, perl-DBD-SQLite, perl-Math-Round, perl-PathTools, perl-IPC-Run, perl-Scalar-List-Utils, perl-Regexp-Common, R
buildroot:	/opt/structuprint/

%description
Structuprint is a command line tool for 2D surface 
plotting of PDB structures. Its output can be a single 
PNG frame or a full-blown GIF animation consisting of 
tens of frames.

%prep
%setup -q

%build
chmod 755 structuprint.pl

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/opt/structuprint/
cp structuprint.pl %{buildroot}/opt/structuprint/
cp amino_acid_properties.db %{buildroot}/opt/structuprint/
tar -xzvf R_libs.tar.gz
cp -R R_libs/* %{buildroot}/opt/structuprint/R_libs/
cp props.txt %{buildroot}/opt/structuprint/

mkdir -p %{buildroot}/usr/bin/
cp structuprint %{buildroot}/usr/bin/
chmod +x %{buildroot}/usr/bin/structuprint

mkdir -p %{buildroot}/tmp/structuprint/
mkdir -p %{buildroot}/usr/
cp RPMs/* %{buildroot}/tmp/structuprint/
cd %{buildroot}/tmp/structuprint/ && rpm2cpio libastro-mapprojection-perl-0.01-2.x86_64.rpm | cpio -dimv
cp -R %{buildroot}/tmp/structuprint/usr/* %{buildroot}/usr/
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

%files
/usr/bin/structuprint
/opt/structuprint/*
/usr/lib/perl/5.14/perllocal.pod
/usr/lib/perl5/Astro/MapProjection.pm
/usr/lib/perl5/auto/Astro/MapProjection/.packlist
/usr/lib/perl5/auto/Astro/MapProjection/MapProjection.bs
/usr/lib/perl5/auto/Astro/MapProjection/MapProjection.so
/usr/lib/perl5/auto/Bio/PDB/Structure/.packlist
/usr/share/doc/libastro-mapprojection-perl/README
/usr/share/doc/libastro-mapprojection-perl/changelog.Debian.gz
/usr/share/doc/libastro-mapprojection-perl/copyright
/usr/share/doc/libbio-pdb-structure-perl/changelog.Debian.gz
/usr/share/doc/libbio-pdb-structure-perl/copyright
/usr/share/man/man3/Astro::MapProjection.3pm.gz
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
