#!/bin/sh

# Exit on failure
set -e

########
# Perl #
########
printf "Checking for perl... "
sleep 1
command -v perl >/dev/null 2>&1 ||
{
	printf "\nThe perl executable was not found! Exiting.\n"
	exit 1
}
printf "OK\n"

################
# Perl modules #
################
printf "Checking for required Perl modules... "
sleep 1
perl load_Perl_modules.pl | while read line;
do
	if echo "$line" | egrep -s '^not ok'
	then
		printf "\nTest failed! Exiting.\n"
		exit 1
	fi
done
printf "OK\n"

#####
# R #
#####
printf "Checking for R... "
sleep 1
command -v R > /dev/null 2>&1 ||
{
	printf "\nThe R executable was not found! Exiting.\n"
	exit 1
}
printf "OK\n"

##############
# R packages #
##############
printf "Checking for required R packages... "
sleep 1
if echo $(R --slave < load_R_packages.R 2>&1) | egrep -s 'Error'
then
	exit 1
fi
printf "OK\n"
