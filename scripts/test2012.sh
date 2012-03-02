#!/bin/bash -x

aptargs="--assume-yes --allow-unauthenticated --no-install-recommends"

debname="$1"

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

# install original package
apt-get install $aptargs $debname || report_errors

#
# install the sources.list line
echo "deb file:/ tl2012-pre/" >> /etc/apt/sources.list
gunzip -c /tl2012-pre/Packages.gz > /var/lib/apt/lists/_tl2012-pre_Packages

#
# now run the tests
#
# install cycle
#
#aptitude purge $aptargs '~ntexlive'
# upgrade test
apt-get dist-upgrade $aptargs || report_errors
# remove
apt-get remove $aptargs $debname || report_errors
# install after remove
apt-get install $aptargs $debname || report_errors
# purge
apt-get remove --purge $aptargs $debname || report_errors
# install new from purged state
apt-get install $aptargs $debname || report_errors
# check for left over files?

echo "SUCCESS"

