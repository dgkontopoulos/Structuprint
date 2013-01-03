INSTALLDIR=$(DESTDIR)/opt/structuprint

Scripts: structuprint.pl structuprint_frame.pl
	chmod 755 structuprint.pl
	chmod 755 structuprint_frame.pl

install:
	mkdir -p $(INSTALLDIR)
	cp structuprint.pl $(INSTALLDIR)/
	cp amino_acid_properties.db $(INSTALLDIR)/
	cp props.txt $(INSTALLDIR)/
	
	mkdir -p $(DESTDIR)/tmp/structuprint/
	mkdir -p $(DESTDIR)/usr/
	dpkg -x DEBS/libbio-pdb-structure-perl_0.02-1_all.deb $(DESTDIR)/tmp/structuprint/
	cp -R $(DESTDIR)/tmp/structuprint/usr/* $(DESTDIR)/usr/
	rm -rf $(DESTDIR)/tmp/structuprint/
	
	mkdir -p $(DESTDIR)/tmp/structuprint/
	dpkg -x DEBS/libastro-mapprojection-perl_0.01-1_i386.deb $(DESTDIR)/tmp/structuprint/
	cp -R $(DESTDIR)/tmp/structuprint/usr/* $(DESTDIR)/usr/
	rm -rf $(DESTDIR)/tmp/
	
	mkdir -p $(DESTDIR)/usr/bin/
	cp structuprint $(DESTDIR)/usr/bin/
	chmod +x $(DESTDIR)/usr/bin/structuprint
	cp structuprint_frame $(DESTDIR)/usr/bin/
	chmod +x $(DESTDIR)/usr/bin/structuprint_frame
		
uninstall:
	rm -rf $(INSTALLDIR)
	rm -rf $(DESTDIR)/usr/bin/structuprint
	rm -rf $(DESTDIR)/usr/bin/structuprint_frame
