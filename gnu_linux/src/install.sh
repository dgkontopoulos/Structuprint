#!/bin/sh

if ! [ $(id -u) = 0 ]; then
  echo "You must be root to do this."
  exit 1
fi

echo -n "\nChecking for Perl... "
if !((which perl) > /dev/null);
then
  echo "\033[1mERROR!\n\nPerl is not installed! Blasphemy! Please install Perl.\033[0m"
  exit 1
fi
echo "OK"

echo -n "Checking for Astro::MapProjection... "
if !((perl -e 'use Astro::MapProjection') > /dev/null);
then
  echo "\033[1mERROR!\n\nAstro::MapProjection is not installed! Install it from CPAN:\nhttp://search.cpan.org/~smueller/Astro-MapProjection-0.01/lib/Astro/MapProjection.pm\033[0m"
  exit 1
fi
echo "OK"

echo -n "Checking for Bio::PDB::Structure... "
if !((perl -e 'use Bio::PDB::Structure') > /dev/null);
then
  echo "\033[1mERROR!\n\nBio::PDB::Structure is not installed! Install it from CPAN:\nhttp://search.cpan.org/~rulix/Bio-PDB-Structure-0.02/lib/Bio/PDB/Structure.pm\033[0m"
  exit 1
fi
echo "OK"

echo -n "Checking for DBD::SQLite... "
if !((perl -e 'use DBD::SQLite') > /dev/null);
then
  echo "\033[1mERROR!\n\nDBD::SQLite is not installed! Install it from CPAN:\nhttp://search.cpan.org/~adamk/DBD-SQLite-1.37/lib/DBD/SQLite.pm\033[0m"
  exit 1
fi
echo "OK"

echo -n "Checking for DBI... "
if !((perl -e 'use DBI') > /dev/null);
then
  echo "\033[1mERROR!\n\nDBI is not installed! Install it from CPAN:\nhttp://search.cpan.org/~timb/DBI-1.622/DBI.pm\033[0m"
  exit 1
fi
echo "OK"

echo -n "Checking for File::Copy... "
if !((perl -e 'use File::Copy') > /dev/null);
then
  echo "\033[1mERROR!\n\nFile::Copy is not installed! Install it from CPAN:\nhttp://search.cpan.org/~dom/perl-5.12.5/lib/File/Copy.pm\033[0m"
  exit 1
fi
echo "OK"

echo -n "Checking for File::Spec... "
if !((perl -e 'use File::Spec') > /dev/null);
then
  echo "\033[1mERROR!\n\nFile::Spec is not installed! Install it from CPAN:\nhttp://search.cpan.org/~smueller/PathTools-3.33/lib/File/Spec.pm\033[0m"
  exit 1
fi
echo "OK"

echo -n "Checking for List::Util... "
if !((perl -e 'use List::Util') > /dev/null);
then
  echo "\033[1mERROR!\n\nList::Util is not installed! Install it from CPAN:\nhttp://search.cpan.org/~pevans/Scalar-List-Utils-1.27/lib/List/Util.pm\033[0m"
  exit 1
fi
echo "OK"

echo -n "Checking for Math::Round... "
if !((perl -e 'use Math::Round') > /dev/null);
then
  echo "\033[1mERROR!\n\nMath::Round is not installed! Install it from CPAN:\nhttp://search.cpan.org/~grommel/Math-Round-0.06/Round.pm\033[0m"
  exit 1
fi
echo "OK"

echo -n "Checking for R... "
if !((which R) > /dev/null);
then
  echo "\033[1mERROR!\n\nR is not installed! Please install R.\033[0m"
  exit 1
fi
echo "OK"

echo -n "Checking for Statistics::R... "
if !((perl -e 'use Statistics::R') > /dev/null);
then
  echo "\033[1mERROR!\n\nStatistics::R is not installed! Install it from CPAN:\nhttp://search.cpan.org/~fangly/Statistics-R-0.30/lib/Statistics/R.pm\033[0m"
  exit 1
fi
echo "OK"

echo -n "Checking for ggplot2... "
if !((./install_t/ggplot2.R) > /dev/null);
then
  echo "\033[1mERROR!\n\nggplot2 is not installed! Install it from CRAN:\nhttp://cran.r-project.org/web/packages/ggplot2/index.html\033[0m"
  exit 1
fi
echo "OK"

echo ""

mkdir -p /opt/structuprint/

chmod 755 ./structuprint.pl
cp ./structuprint.pl /opt/structuprint/

chmod 755 ./structuprint_frame.pl
cp ./structuprint_frame.pl /opt/structuprint/

cp amino_acid_properties.db /opt/structuprint/

cp props.txt /opt/structuprint/

mkdir -p /usr/bin/
chmod 755 ./structuprint
cp ./structuprint /usr/bin/structuprint

chmod 755 ./structuprint_frame
cp ./structuprint_frame /usr/bin/structuprint_frame

echo "\033[1mStructuprint was successfully installed at '/opt/structuprint'!"
echo "Launch it with 'structuprint' or 'structuprint_frame'.\033[0m"
