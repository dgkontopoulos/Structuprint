<center><img src='https://github.com/dgkontopoulos/Structuprint/raw/master/src/images/splash.png'></center>

## LATEST VERSION

1.001

## DESCRIPTION

Structuprint is a software tool for two-dimensional representation of protein 
structures' surfaces, capable of generating animations or still images.

Its main purpose is the visualization of the distribution of 
physicochemical descriptors on the exposed residues of a protein. Beyond 
this, it can be used for various structural comparisons, e.g. of 
evolutionarily related proteins.

## SUPPORTED OPERATING SYSTEMS

Structuprint runs out of the box on 5 different GNU/Linux distributions 
(Ubuntu, Debian, Fedora, CentOS, openSUSE), Windows and OS X. For CentOS, the 
`epel-release` package needs to be pre-installed, before attempting to install 
Structuprint. Download links are available from 
<a href='https://github.com/dgkontopoulos/Structuprint/releases'>GitHub releases</a> and also 
from the <a href='https://dgkontopoulos.github.io/Structuprint/'>website</a>.

For all other systems, you will need to manually install Structuprint 
from the source code, along with all of its dependencies:

    make test # Makes sure that all dependencies are installed.
    make
    make install

The Graphical User Interface is only available for GNU/Linux systems. On other operating 
systems you will have to use the Command Line Interface. CPU parallelism is supported 
on GNU/Linux and OS X, but not on Windows.

For more information, see the 
<a href='https://github.com/dgkontopoulos/Structuprint/raw/master/documentation/documentation.pdf'>documentation</a>.

## AUTHORS

\-Dimitrios - Georgios Kontopoulos <<dgkontopoulos@gmail.com>>

\-Dimitrios Vlachakis <<dvlachakis@bioacademy.gr>>

\-Georgia Tsiliki <<gtsiliki@central.ntua.gr>>

\-Sofia Kossida <<sofia.kossida@igh.cnrs.fr>>

## LICENSE

This program is free software: you can redistribute it 
and/or modify it under the terms of the 
<a href="http://www.gnu.org/licenses/gpl-3.0.html">GNU General 
Public License as published by the Free Software 
Foundation, either version 3 of the License, or (at your 
option) any later version</a>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
