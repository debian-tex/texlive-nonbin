LANG=C

TLROOT?=$(HOME)/Development/TeX/texlive.git
MASTER?=/var/www/norbert/tlnet
OLDPKG?=$(PWD)/old
OLDSOURCES?=$(PWD)/src
CURRENTDIR=$(PWD)
SOURCES ?= texlive-base texlive-lang texlive-extra
TMPDIR?=/var/tmp

STABLECOW = /var/cache/pbuilder/jessie-8.0-amd64.cow
TESTINGCOW = /var/cache/pbuilder/debian-8.0-jessie-TESTING.cow

# for update-liclines
catalogue_loc ?= ../../../../texcatalogue/trunk/

ADDBINDMOUNTS=$(shell if [ -d additionalpackages ] ; then echo ./additionalpackages ; fi)

BUILDBINDMOUNTSCMDS=$(shell if [ -d additionalpackages ] ; then echo --bindmounts \"./additionalpackages ./pbuilder-hookdir\" --hookdir ./pbuilder-hookdir; fi)


bar:
	@echo $(BUILDBINDMOUNTSCMDS)

first:
	@echo "No, I don't do anything without being told exactely what!"

norbert:
	perl tpm2deb-source.pl --master=$(TLROOT)/Master make-orig-tar texlive-base texlive-extra texlive-lang
	perl tpm2deb-source.pl --master=$(TLROOT)/Master make-deb-source texlive-base texlive-extra texlive-lang

all: sources pbuilder lintian packages debdiff deepdiff alltests

simpleall: sources pbuilder lintian packages debdiff deepdiff

origtar:
	perl tpm2deb-source.pl make-orig-tar --master=$(MASTER) $(SOURCES)

srcpkg:
	perl tpm2deb-source.pl make-deb-source --oldsource=$(OLDSOURCES) --master=$(MASTER) $(SOURCES)

sources:
	perl tpm2deb-source.pl make-deb-source --oldsource=$(OLDSOURCES) --master=$(MASTER) $(SOURCES) \
		2>&1 | tee texlive.sourcebuild.log
	mkdir -p pool
	mv *.dsc *.diff.gz *.orig.tar.gz pool
	mkdir -p log
	mv *.log log

build:
	cd pool && \
	for i in *.dsc ; do \
		dpkg-source -x $$i ; \
		cd `echo $$i | sed -e 's/_2005.*$$/-2005/'` ; \
		dpkg-buildpackage -us -uc -b -rfakeroot 2>&1 | tee `basename $$i .dsc`.build.log ; \
		dpkg-genchanges > ../`basename $i .dsc`_i386.changes ; \
		cd .. ; \
	done

pbuilder: 
	mkdir -p log
	for i in pool/*.dsc ; do \
		sudo /usr/sbin/cowbuilder --build --buildresult ./pool/ \
			$(BUILDBINDMOUNTSCMDS)	\
			$$i 2>&1 | tee log/`basename $$i .dsc`.pbuilder.log ; \
	done

linda:
	cd pool && \
	for i in *.changes ; do \
		linda -f lintian $$i > `basename $$i .changes`.linda.log ; \
	done
	mkdir -p log
	mv pool/*.log log
	perl scripts/generate-lin-report.pl log/*.linda.log > log/linda.log

lintian:
	cd pool && \
	for i in *.changes ; do \
		TMPDIR=${TMPDIR} lintian $$i > `basename $$i .changes`.lintian.log ; \
	done || true
	mkdir -p log
	mv pool/*.log log
	-perl scripts/generate-lin-report.pl log/*.lintian.log > log/lintian.log

adequate:
	cd pool && for i in *.deb ; do pkg=`echo $$i | sed -e 's/_.*//'`; adequate $$pkg >> ../log/adequate.log ; done

deepdiff:
	cd pool && \
	for i in *.deb ; do \
		bn=`echo $$i | sed -e 's/_.*//'` ; \
		oldfile=`ls $(OLDPKG)/$${bn}_*.deb | tail -1` ; \
		bash ../scripts/deep-debdiff.sh $$oldfile $$i > $$bn.deepdiff ; \
	done || true
	mkdir -p log
	mv pool/*.deepdiff log

debdiff:
	cd pool && \
	for i in *.deb ; do \
		bn=`echo $$i | sed -e 's/_.*//'` ; \
		oldfile=`ls $(OLDPKG)/$${bn}_*.deb | tail -1` ; \
		debdiff $$oldfile $$i > $$bn.debdiff ; \
	done || true
	cd pool && \
	for i in *.debdiff ; do \
		grep -v share/doc $$i | \
		grep -v texlive/texmf/doc | \
		grep -v texlive/texmf-dist/doc > $$i.nodoc; \
	done || true
	mkdir -p log
	mv pool/*.debdiff pool/*.nodoc log

update-scripts-file:
	cat $(TLROOT)/Build/source/texk/texlive/linked_scripts/scripts.lst $(TLROOT)/Build/source/texk/texlive/tl_scripts/scripts.lst  > all/debian/scripts.lst

packages:
	bash scripts/build-infra -p . -nosign pool
	make duplicate-check

alltests: installtests stable-tests testing-tests sid-tests

installtests:
	-for i in pool/*.deb ; do \
		debname=`basename $$i` ;				\
		debname=`echo $$debname | sed -e 's/_201.*\.deb//'` ;	\
		echo $$debname ... ;					\
		sudo /usr/sbin/cowbuilder --execute --bindmounts "./pool $(ADDBINDMOUNTS)" ./tests/scripts/test-script.sh $$debname 2>&1 | tee log/$$debname.installtest.log ;	\
	done

simpleinstalltests:
	-for i in pool/*.deb ; do \
		debname=`basename $$i` ;				\
		debname=`echo $$debname | sed -e 's/_201.*\.deb//'` ;	\
		echo $$debname ... ;					\
		sudo /usr/sbin/cowbuilder --execute --bindmounts "./pool $(ADDBINDMOUNTS)" ./tests/scripts/simple-test-script.sh $$debname 2>&1 | tee log/$$debname.simpleinstalltest.log ;	\
	done

sid1-tests:
	mkdir -p ./tests/log
	-for i in ./tests/sid/test-1.sh ; do \
		rm -f ./tests/log/sid-`basename $$i .sh`.log ; \
		sudo /usr/sbin/cowbuilder --execute \
			--bindmounts "./pool" $$i 2>&1 | \
			tee ./tests/log/sid-`basename $$i .sh`.log ; \
	done

overwrite-tests: sid-overwrite testing-overwrite stable-overwrite

sid-overwrite:
	mkdir -p ./tests/log
	rm -f ./tests/log/sid-test-forceoverwrite.log
	sudo  /usr/sbin/cowbuilder --execute \
	  --bindmounts "./pool" ./tests/sid/test-forceoverwrite.sh 2>&1 | \
	  tee ./tests/log/sid-test-forceoverwrite.log

testing-overwrite:
	mkdir -p ./tests/log
	rm -f ./tests/log/testing-test-forceoverwrite.log
	sudo  /usr/sbin/cowbuilder --execute \
	  --basepath $(TESTINGCOW) \
	  --bindmounts "./pool" ./tests/testing/test-forceoverwrite.sh 2>&1 | \
	  tee ./tests/log/testing-test-forceoverwrite.log

stable-overwrite:
	mkdir -p ./tests/log
	rm -f ./tests/log/stable-test-forceoverwrite.log
	sudo  /usr/sbin/cowbuilder --execute \
	  --basepath $(STABLECOW) \
	  --bindmounts "./pool" ./tests/stable/test-forceoverwrite.sh 2>&1 | \
	  tee ./tests/log/stable-test-forceoverwrite.log

sid-tests:
	mkdir -p ./tests/log
	-for i in ./tests/sid/test-?.sh ; do \
		rm -f ./tests/log/sid-`basename $$i .sh`.log ; \
		sudo /usr/sbin/cowbuilder --execute \
			--bindmounts "./pool" $$i 2>&1 | \
			tee ./tests/log/sid-`basename $$i .sh`.log ; \
	done

testing1-tests:
	mkdir -p ./tests/log
	-for i in ./tests/testing/test-1.sh ; do \
		rm -f ./tests/log/testing-`basename $$i .sh`.log ; \
		rm -f ./tests/log/testing-`basename $$i .sh`-files-* ; \
		sudo /usr/sbin/cowbuilder --execute \
			--basepath $(TESTINGCOW) \
			--bindmounts "./pool" $$i 2>&1 | \
			tee ./tests/log/testing-`basename $$i .sh`.log ; \
		mv pool/testing-test-*-files-* ./tests/log/ ; \

testing-tests:
	mkdir -p ./tests/log
	-for i in ./tests/testing/test-?.sh ; do \
		rm -f ./tests/log/testing-`basename $$i .sh`.log ; \
		rm -f ./tests/log/testing-`basename $$i .sh`-files-* ; \
		sudo /usr/sbin/cowbuilder --execute \
			--basepath $(TESTINGCOW) \
			--bindmounts "./pool" $$i 2>&1 | \
			tee ./tests/log/testing-`basename $$i .sh`.log ; \
		mv pool/testing-test-*-files-* ./tests/log/ ; \
	done

stable-tests:
	mkdir -p ./tests/log
	-for i in ./tests/stable/test-?.sh ; do \
		rm -f ./tests/log/stable-`basename $$i .sh`.log ; \
		rm -f ./tests/log/stable-`basename $$i .sh`-files-* ; \
		sudo /usr/sbin/cowbuilder --execute \
			--basepath $(STABLECOW) \
			--bindmounts "./pool" $$i 2>&1 | \
			tee ./tests/log/stable-`basename $$i .sh`.log ; \
		mv pool/stable-test-*-files-* ./tests/log/ ; \
	done

duplicate-check:
	@if zcat pool/Contents-i386.gz | awk '{print$$2}' | grep , >/dev/null ; then echo "Duplicate file inclusion detected!" ; zcat pool/Contents-i386.gz | awk '{print$$2}' | grep , ; return 1 ; else return 0 ; fi


clean:
	rm -rf pool log binary debian-pkg* control-stamp
