## NAME

__Structuprint__

## DESCRIPTION

A utility for analysis of MD simulations (and single PDB structures as well), offering a novel 2D 
visualisation technique. Its output may be a single frame or a full-blown animation, depending on 
input.

Tutorials are available at the <a href="https://github.com/dgkontopoulos/Structuprint/wiki/_pages">GitHub wiki</a>.

## DEPENDENCIES

\-the <b>Perl</b> interpreter, >= 5.10

\-<b>Astro::MapProjection</b>, >= 0.01 (Perl module)

\-<b>Bio::PDB::Structure</b>, >= 0.01 (Perl module)

\-<b>DBD::SQLite</b>, >= 1.37 (Perl module)

\-<b>DBI</b>, >= 1.622 (Perl module)

\-<b>File::Spec</b>, >= 3.33 (Perl module)

\-<b>File::Copy</b>, >= 2.18 (Perl module)

\-<b>Gtk2</b>, >= 1.247 (Perl module) <b>[for GNU/Linux only]</b>

\-<b>List::Util</b>, >= 1.25 (Perl module)

\-<b>Math::Round</b>, >= 0.06 (Perl module)

\-<b>Statistics::R</b>, >= 0.30 (Perl module)

\-the <b>R</b> interpreter, >= 2.15.1

\-<b>ggplot2</b>, >= 0.9.3 (R package)

\-<b>ImageMagick</b>

\-<b>Gifsicle</b>

\-<b>xterm [for GNU/Linux only]</b>


## SUPPORTED OPERATING SYSTEMS

<b>Structuprint</b> runs out of the box on the following GNU/Linux distributions: 
<b>Debian 7</b>, <b>Ubuntu 13.04</b>, <b>Linux Mint 15</b>, <b>Fedora 19</b>. 

It will run on other GNU/Linux distros, as well as on BSD and OS X systems, 
as long as you manually install missing dependencies. The installation script 
(install.sh) will check for missing software and proceed with the installation, if 
everything is OK.

It can also run on Windows systems (via setup.exe), as long as Perl and R 
are correctly installed.

The GUI version is only available for GNU/Linux systems. On other operating 
systems you'll have to use the command line version.

<center><b>See the <a href="https://github.com/dgkontopoulos/Structuprint/wiki/_pages">installation 
instructions in the GitHub wiki</a> for more details!</b></center>

## SCREENSHOTS

<center><img src="http://dgkontopoulos.github.io/Structuprint/images/example_gnu_linux_frame_gui.png">
<br><i>Creating a structuprint frame using the GUI on Fedora 19.</i>
<br><br><img src="http://dgkontopoulos.github.io/Structuprint/images/example_osx_anim.png">
<br><i>Creating a structuprint animation using the command line on OS X v10.8.</i>
</center>

## EXAMPLE

<center><img src="http://dgkontopoulos.github.io/Structuprint/images/anim_351_to_400.gif" width="80%" height="80%">
<br>_Refresh the page to restart the animation._</center>

## AUTHORS

\-Dimitrios Vlachakis <<dvlachakis@bioacademy.gr>>

\-Georgia Tsiliki <<gtsiliki@bioacademy.gr>>

\-Dimitrios - Georgios Kontopoulos <<dgkontopoulos@gmail.com>>

\-Sophia Kossida <<skossida@bioacademy.gr>>

## LICENSE

This program is free software: you can redistribute it 
and/or modify it under the terms of the GNU General 
Public License as published by the Free Software 
Foundation, either version 2 of the License, or (at your 
option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

For more information, see
<a href="http://www.gnu.org/licenses/" style="text-decoration:none">
http://www.gnu.org/licenses/<a>.
