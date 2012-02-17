#!/bin/bash -x

aptargs="--assume-yes --without-recommends"

debname="$1"

#
case $debname in
  texlive-latex-extra)
    debname="texlive-latex-extra texlive-latex-recommended texlive-fonts-recommended"
    ;;
  texlive-fonts-recommended)
    debname="texlive-latex-base texlive-fonts-recommended"
    ;;
  texlive-fonts-extra)
    debname="texlive-latex-base texlive-fonts-recommended texlive-latex-recommended texlive-fonts-extra"
    ;;
  texlive-lang-*)
    debname="texlive-base $debname"
    ;;
  texlive-music)
    debname="texlive-base $debname"
    ;;
esac

#
# report_errors should cat out all the /tmp/texlive.* files for debugging
# and then exit
#
report_errors() {
    for i in /tmp/texlive.* ; do
	echo "======= ERROR FILE $i ==========="
	cat $i
	echo "======= END OF ERROR FILE $i ==========="
    done
    exit 1
}


# first install tex-common for now until texinfo is fixed
aptitude install $aptargs tex-common

# install original package
aptitude install $aptargs $debname || report_errors

if [ -d /additionalpackages ] ; then
	echo "deb file:/ additionalpackages/" >> /etc/apt/sources.list
	gunzip -c /additionalpackages/Packages.gz > /var/lib/apt/lists/_additionalpackages_Packages
fi


#
# install the sources.list line
echo "deb file:/ pool/" >> /etc/apt/sources.list
if [ -d /check ] ; then
	echo "deb file:/ check/" >> /etc/apt/sources.list
fi

# add my gpg key
apt-key add /pool/norbert.gpg

#
# update aptitudes lists
# without network we have a problem
aptitude update
#gunzip -c /pool/Packages.gz > /var/lib/apt/lists/_pool_Packages
#if [ -d /check ] ; then
#	gunzip -c /check/Packages.gz > /var/lib/apt/lists/_check_Packages
#fi

# shit for a stupid bug in sid in apt, bastards
aptitude -t sid install $aptargs tzdata
#
# now run the tests
#
# upgrade test
aptitude -t sid dist-upgrade $aptargs || report_errors

echo "SUCCESS"

