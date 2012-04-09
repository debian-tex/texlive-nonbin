LANG=C

MASTER?=/var/www/norbert/tlnet
OLDPKG?=$(PWD)/old
OLDSOURCES?=$(PWD)/src
CURRENTDIR=$(PWD)
SOURCES ?= texlive-base texlive-doc texlive-lang texlive-extra
TMPDIR?=/var/tmp

# for update-liclines
catalogue_loc ?= ../../../../texcatalogue/trunk/
tpmdir_loc ?= ../../../../TeXlive2005-Master/texmf*/tpm/

ADDBINDMOUNTS=$(shell if [ -d additionalpackages ] ; then echo ./additionalpackages ; fi)

BUILDBINDMOUNTSCMDS=$(shell if [ -d additionalpackages ] ; then echo --bindmounts \"./additionalpackages ./pbuilder-hookdir\" --hookdir ./pbuilder-hookdir; fi)


bar:
	@echo $(BUILDBINDMOUNTSCMDS)

first:
	@echo "No, I don't do anything without being told exactely what!"

norbert:
	perl tpm2deb-source.pl --master=/src/TeX/texlive-svn/Master make-orig-tar texlive-base texlive-extra texlive-doc texlive-lang
	perl tpm2deb-source.pl --master=/src/TeX/texlive-svn/Master make-deb-source texlive-base texlive-extra texlive-doc texlive-lang

all: sources pbuilder lintian packages debdiff deepdiff installtests sidtests testingtests

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
	for i in texlive*.changes tex-common*.changes ; do \
		TMPDIR=${TMPDIR} lintian $$i > `basename $$i .changes`.lintian.log ; \
	done || true
	mkdir -p log
	mv pool/*.log log
	-perl scripts/generate-lin-report.pl log/*.lintian.log > log/lintian.log

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
	mkdir -p log
	mv pool/*.debdiff log

packages:
	bash scripts/build-infra -p . -nosign pool

installtests:
	-for i in pool/*.deb ; do \
		debname=`basename $$i` ;				\
		debname=`echo $$debname | sed -e 's/_201.*\.deb//'` ;	\
		echo $$debname ... ;					\
		sudo /usr/sbin/cowbuilder --execute --bindmounts "./pool $(ADDBINDMOUNTS)" ./tests/scripts/test2012.sh $$debname 2>&1 | tee log/$$debname.installtest.log ;	\
	done

simpleinstalltests:
	-for i in pool/*.deb ; do \
		debname=`basename $$i` ;				\
		debname=`echo $$debname | sed -e 's/_201.*\.deb//'` ;	\
		echo $$debname ... ;					\
		sudo /usr/sbin/cowbuilder --execute --bindmounts "./pool $(ADDBINDMOUNTS)" ./tests/scripts/simple-test-script.sh $$debname 2>&1 | tee log/$$debname.simpleinstalltest.log ;	\
	done


testbed: sidtests testingtests

sidtests:
	-for i in ./tests/sid/test*.sh ; do \
		sudo /usr/sbin/cowbuilder --execute --bindmounts "./pool" $$i 2>&1 | tee $$i.log ; \
	done

testingtests:
	-for i in ./tests/testing/test*.sh ; do \
		sudo /usr/sbin/cowbuilder --execute \
			--basepath /var/cache/pbuilder/testing.cow \
			--bindmounts "./pool" $$i 2>&1 | tee $$i.log ; \
		mv pool/testing-test-*-files-* ./tests/testing/ ; \
	done


clean:
	rm -rf pool log binary debian-pkg* control-stamp
