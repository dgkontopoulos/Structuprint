#!/usr/bin/env perl

use strict;
use warnings;

my $test_output = `Rscript install_t/ggplot2.R`;

my $current_version;
my @current_version;
if ( $test_output =~ /‘(\d)[.](\d)[.](\d)/ )
{
    $current_version = "$1.$2.$3";
    push @current_version, $1;
    push @current_version, $2;
    push @current_version, $3;
}
else
{
    print '1';
    exit;
}

my $needed_version = '0.9.3';
my @needed_version = ( '0', '9', '3' );

for ( 0 .. $#current_version )
{
    if ( $current_version[$_] > $needed_version[$_] )
    {
        print '0';
        exit;
    }
    elsif ( $current_version[$_] < $needed_version[$_] )
    {
        print '1';
        exit;
    }
}
print '0';

