FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends make perl pkg-config libdbi-perl libcam-pdf-perl gcc libgtk2-perl libgnome2-perl libvte-dev libtiff-dev libgif-dev libsys-cpu-perl software-properties-common libgnomeui-dev r-base

RUN add-apt-repository ppa:marutter/rrutter && add-apt-repository ppa:marutter/c2d4u && apt-get update \
  && apt-get install -y r-cran-ggplot2

RUN cpan -f IPC::Run && cpan Statistics::R Astro::MapProjection DBD::SQLite Gnome2 Gnome2::Vte Glib Imager Gtk2 Gtk2::Gdk::Keysyms Gtk2::Helper Parallel::ForkManager Math::Round IPC::ShareLite Imager::File::TIFF Imager::File::GIF Sys::CPU Term::ANSIScreen Term::ProgressBar Bio::PDB::Structure::Atom

ADD . /src

RUN cd /src && make test 
RUN cd /src && make && make install

ENTRYPOINT /opt/structuprint/structuprint