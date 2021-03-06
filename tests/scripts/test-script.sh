#!/bin/bash -x

aptargs="--assume-yes --allow-unauthenticated"

debname="$1"

#
# report_errors should cat out all the /tmp/texlive.* files for debugging
# and then exit
#
report_errors() {
    for i in /tmp/texlive.* /tmp/fmtutil* /tmp/updmap* /tmp/mktexlsr* ; do
	echo "======= ERROR FILE $i ==========="
	cat $i
	echo "======= END OF ERROR FILE $i ==========="
    done
    exit 1
}

if [ -d /additionalpackages ] ; then
	echo "deb file:/ additionalpackages/" >> /etc/apt/sources.list
	gunzip -c /additionalpackages/Packages.gz > /var/lib/apt/lists/_additionalpackages_Packages
fi


# first install tex-common for now until texinfo is fixed
apt-get install $aptargs tex-common

# install original package
apt-get install $aptargs $debname || report_errors

#
# install the sources.list line
echo "deb file:/ pool/" >> /etc/apt/sources.list
if [ -d /check ] ; then
	echo "deb file:/ check/" >> /etc/apt/sources.list
fi

#
# update aptitudes lists
# without network we have a problem
#aptitude update
gunzip -c /pool/Packages.gz > /var/lib/apt/lists/_pool_Packages
if [ -d /check ] ; then
	gunzip -c /check/Packages.gz > /var/lib/apt/lists/_check_Packages
fi

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

