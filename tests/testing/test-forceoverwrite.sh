#!/bin/sh

aptargs="--assume-yes --allow-unauthenticated"

echo "=== TeX Live Test System ==="
echo "=== Test testing upgrade/overwrite: dist-upgrade/overwrite texlive-full from testing to test ==="
echo ""

echo "=== START INSTALL TESTING VERSION"
apt-get install $aptargs texlive-full
echo "deb http://ftp.nara.wide.ad.jp/debian/ sid main" > /etc/apt/sources.list
echo "deb file:/ pool/" >> /etc/apt/sources.list
apt-get update $aptargs

echo "=== START INSTALL TEST VERSION"
apt-get -o Dpkg::Options::="--force-overwrite" dist-upgrade $aptargs
for i in $(find /tmp -name fmtutil\.\* -o -name updmap\.\*) ; do
  echo $i
  cat $i
  echo "=================="
done

echo "=== END"
