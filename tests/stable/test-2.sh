#!/bin/sh

aptargs="--assume-yes --allow-unauthenticated"

echo "=== TeX Live Test System ==="
echo "=== Test stable upgrade: dist-upgrade texlive-full from stable to test ==="
echo ""

echo "=== START INSTALL STABLE VERSION"
apt-get install $aptargs texlive-full
find /etc/texmf | sort > /pool/stable-test-2-files-pre
echo "deb http://ftp.nara.wide.ad.jp/debian/ sid main" > /etc/apt/sources.list
echo "deb file:/ pool/" >> /etc/apt/sources.list
apt-get update $aptargs

echo "=== START INSTALL TEST VERSION"
apt-get dist-upgrade $aptargs
find /etc/texmf | sort > /pool/stable-test-2-files-post
for i in $(find /tmp -name fmtutil\.\* -o -name updmap\.\*) ; do
  if [ -f $i ] ; then
    echo $i
    cat $i
    echo "=================="
  elif [ -d $i ] ; then
    for j in $i/* ; do
      echo $j
      cat $j
      echo "================="
    done
  else
    echo "dont know how to treat $i"
    echo "================"
  fi
done

echo "=== END"
