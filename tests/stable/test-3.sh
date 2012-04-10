#!/bin/sh

aptargs="--assume-yes --allow-unauthenticated --no-install-recommends"

echo "=== TeX Live Test System ==="
echo "=== Test stable upgrade: dist-upgrade ptex-bin from stable to test ==="
echo ""

echo "=== START INSTALL STABLE VERSION"
apt-get install $aptargs ptex-bin
find /etc/texmf | sort > /pool/stable-test-3-files-pre
echo "deb http://ftp.nara.wide.ad.jp/debian/ sid main" > /etc/apt/sources.list
echo "deb file:/ pool/" >> /etc/apt/sources.list
apt-get update $aptargs

echo "=== START INSTALL TEST VERSION"
apt-get dist-upgrade $aptargs
find /etc/texmf | sort > /pool/stable-test-3-files-post
for i in $(find /tmp -name fmtutil\.\* -o -name updmap\.\*) ; do
  echo $i
  cat $i
  echo "=================="
done

echo "=== END"
