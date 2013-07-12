INSTALLDIR=$(DESTDIR)/opt/structuprint

Scripts: structuprint.pl structuprint_frame.pl
	chmod 755 structuprint.pl
	chmod 755 structuprint_frame.pl
	chmod 755 structuprint_gui.pl

install:
	mkdir -p $(INSTALLDIR)/images/
	cp structuprint.pl $(INSTALLDIR)/
	cp structuprint_frame.pl $(INSTALLDIR)/
	cp structuprint_gui.pl $(INSTALLDIR)/
	cp amino_acid_properties.db $(INSTALLDIR)/
	cp props.txt $(INSTALLDIR)/
	cp codebook.pdf $(INSTALLDIR)/
	cp images/* $(INSTALLDIR)/images/
	
	mkdir -p $(DESTDIR)/usr/share/applications/
	cp structuprint.desktop $(DESTDIR)/usr/share/applications/

	mkdir -p $(DESTDIR)/tmp/structuprint/
	dpkg -x DEBS/libbio-pdb-structure-perl_0.02-1_all.deb $(DESTDIR)/tmp/structuprint/
	cp -R $(DESTDIR)/tmp/structuprint/usr/* $(DESTDIR)/usr/
	rm -rf $(DESTDIR)/tmp/structuprint/

	mkdir -p $(DESTDIR)/tmp/structuprint/
	dpkg -x DEBS/libastro-mapprojection-perl_0.01-1_amd64.deb $(DESTDIR)/tmp/structuprint/
	cp -R $(DESTDIR)/tmp/structuprint/usr/* $(DESTDIR)/usr/
	rm -rf $(DESTDIR)/tmp/
	
	tar -xzvf R_libs.tar.gz
	mkdir -p $(INSTALLDIR)/R_libs/
	cp -R R_libs/* $(INSTALLDIR)/R_libs/
	rm -rf R_libs/

	mkdir -p $(DESTDIR)/usr/bin/
	cp structuprint $(DESTDIR)/usr/bin/
	chmod +x $(DESTDIR)/usr/bin/structuprint
	cp structuprint_frame $(DESTDIR)/usr/bin/
	chmod +x $(DESTDIR)/usr/bin/structuprint_frame
		
uninstall:
	rm -rf $(INSTALLDIR)
	rm -rf $(DESTDIR)/usr/bin/structuprint
	rm -rf $(DESTDIR)/usr/bin/structuprint_frame
	rm -rf $(DESTDIR)/usr/share/applications/structuprint.desktop
