#!/bin/sh
aptargs="--without-recommends --assume-yes -o Aptitude::CmdLine::Ignore-Trust-Violations=yes"
echo "=== TeX Live Test System ==="
echo "=== Test stable upgrade: dist-upgrade ptex-bin from stable to test ==="
aptitude install $aptargs ptex-bin
find /etc/texmf | sort > /pool/stable-test-3-files-pre
echo ""
echo "deb http://ftp.nara.wide.ad.jp/debian/ sid main" > /etc/apt/sources.list
echo "deb file:/ pool/" >> /etc/apt/sources.list
aptitude update $aptargs
echo "=== START INSTALL TEST VERSION"
aptitude dist-upgrade $aptargs
find /etc/texmf | sort > /pool/stable-test-3-files-post
for i in $(find /tmp -name fmtutil\.\* -o -name updmap\.\*) ; do
  echo $i
  cat $i
  echo "=================="
done
echo "=== END"
