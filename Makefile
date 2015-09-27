ifdef PREFIX
	INSTALLDIR=$(patsubst %/,%/structuprint,$(PREFIX))
else
	INSTALLDIR=$(DESTDIR)/opt/structuprint
endif

Scripts: src/structuprint.pl src/structuprint_frame.pl src/structuprint_gui.pl
	chmod 755 src/structuprint.pl
	chmod 755 src/structuprint_frame.pl
	chmod 755 src/structuprint_gui.pl

test:
	cd unix_tests && sh run_tests.sh

install:
	mkdir -p $(INSTALLDIR)/images/
	cp src/structuprint.pl $(INSTALLDIR)/structuprint
	cp src/structuprint_frame.pl $(INSTALLDIR)/structuprint_frame
	cp src/structuprint_gui.pl $(INSTALLDIR)/structuprint_gui
	cp src/amino_acid_properties.db $(INSTALLDIR)/
	cp src/props.txt $(INSTALLDIR)/
	cp documentation/documentation.pdf $(INSTALLDIR)/
	cp documentation/properties_codebook.pdf $(INSTALLDIR)/
	cp src/images/* $(INSTALLDIR)/images/
	
	@printf "\n"
	@while true; do \
		read -p "Should I install the .desktop file at /usr/share/applications/ ? (y/n) " reply; \
		if echo "$$reply" | egrep -s '^y|Y'; \
		then \
		    mkdir -p $(DESTDIR)/usr/share/applications/; \
		    cp src/structuprint.desktop $(DESTDIR)/usr/share/applications/; \
		    perl -i -ne 'print if not eof()' $(DESTDIR)/usr/share/applications/structuprint.desktop; \
		    echo "Exec="$(INSTALLDIR)"/structuprint_gui" >> $(DESTDIR)/usr/share/applications/structuprint.desktop; \
		    break 1; \
		elif echo "$$reply" | egrep -s '^n|N'; \
		then \
			break; \
		fi; \
	done

	@printf "\n"
	@while true; do \
		read -p "Should I install the launcher scripts at /usr/bin/ ? (y/n) " reply; \
		if echo "$$reply" | egrep -s '^y|Y'; \
		then \
			mkdir -p $(DESTDIR)/usr/bin/; \
			cp src/structuprint_launcher $(DESTDIR)/usr/bin/structuprint; \
			cp src/structuprint_launcher $(DESTDIR)/usr/bin/structuprint_frame; \
			cp src/structuprint_launcher $(DESTDIR)/usr/bin/structuprint_gui; \
			echo "eval \""$(INSTALLDIR)"/structuprint \$$args\"" >> $(DESTDIR)/usr/bin/structuprint; \
			echo "eval \""$(INSTALLDIR)"/structuprint_frame \$$args\"" >> $(DESTDIR)/usr/bin/structuprint_frame; \
			echo "eval \""$(INSTALLDIR)"/structuprint_gui \$$args\"" >> $(DESTDIR)/usr/bin/structuprint_gui; \
			chmod 755 $(DESTDIR)/usr/bin/structuprint; \
			chmod 755 $(DESTDIR)/usr/bin/structuprint_frame; \
			chmod 755 $(DESTDIR)/usr/bin/structuprint_gui; \
		    break 1; \
		elif echo "$$reply" | egrep -s '^n|N'; \
		then \
			break; \
		fi; \
	done

	@printf "\n"
	@while true; do \
		read -p "Should I install the manpages? (requires pod2man; y/n) " reply; \
		if echo "$$reply" | egrep -s '^y|Y'; \
		then \
			mkdir -p $(DESTDIR)/usr/local/share/man/man1/; \
			pod2man src/structuprint.pl --center "Structuprint Manual Pages" -r "v. 1.001" > structuprint.1 && gzip structuprint.1; \
			pod2man src/structuprint_frame.pl --center "Structuprint Manual Pages" -r "v. 1.001" > structuprint_frame.1 && gzip structuprint_frame.1; \
			mv structuprint.1.gz $(DESTDIR)/usr/local/share/man/man1/; \
			mv structuprint_frame.1.gz $(DESTDIR)/usr/local/share/man/man1/; \
			break 1; \
		elif echo "$$reply" | egrep -s '^n|N'; \
		then \
			break; \
		fi; \
	done

uninstall:
	rm -rf $(INSTALLDIR)
	
	@if [ -f $(DESTDIR)/usr/share/applications/structuprint.desktop ]; \
	then \
		rm $(DESTDIR)/usr/share/applications/structuprint.desktop; \
	fi
	
	@if [ -f $(DESTDIR)/usr/bin/structuprint ]; \
	then \
		rm $(DESTDIR)/usr/bin/structuprint; \
		rm $(DESTDIR)/usr/bin/structuprint_frame; \
		rm $(DESTDIR)/usr/bin/structuprint_gui; \
	fi
	
	@if [ -f $(DESTDIR)/usr/local/share/man/man1/ ]; \
	then \
		rm $(DESTDIR)/usr/local/share/man/man1/structuprint.1.gz; \
		rm $(DESTDIR)/usr/local/share/man/man1/structuprint_frame.1.gz; \
	fi
