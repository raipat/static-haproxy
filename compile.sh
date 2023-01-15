#!/bin/bash
UPGRADE=0
TRAVIS_BUILD_DIR="Portable"
PCK_NAME="haproxy-static"
USE_STATIC_PCRE=1
TARGET=linux-glibc
HAPROXY_MAJOR_VERSION="2.2"
HAPROXY_MINOR_VERSION="26"
PCRE_VERSION="8.45"
OPENSSL_VERSION="1.1.1s"
ZLIB_VERSION="1.2.13"
HAPROXY_VERSION="${HAPROXY_MAJOR_VERSION}.${HAPROXY_MINOR_VERSION}"
PCRE_TARBALL="pcre-${PCRE_VERSION}.tar.gz"
OPENSSL_TARBALL="openssl-${OPENSSL_VERSION}.tar.gz"
ZLIB_TARBALL="zlib-${ZLIB_VERSION}.tar.gz"
HAPROXY_TARBALL="haproxy-${HAPROXY_VERSION}.tar.gz"
#GLIBC_TARBALL="glibc-${GLIBC_VERSION}.tar.gz"
[ $UPGRADE -eq 1 ] && {
    rm -rf haproxy-*
    rm -rf pcre-*
    rm -rf openssl-*
    rm -rf zlib-*
}
CWD=$(pwd)
mkdir -p $TRAVIS_BUILD_DIR
# create a new file to set timestamp, we are not using touch since we need the filesystem to provide time (to handle remote FS)
rm .timestamp || true
cat "" > .timestamp
if [[ ! -d "${PCRE_TARBALL%.tar.gz}" ]]; then
  [ $UPGRADE -eq 1 ] && wget "http://ftp.exim.org/pub/pcre/${PCRE_TARBALL}"
  tar --no-same-owner --mtime=.timestamp -xvzf "${PCRE_TARBALL}" && rm -f "${PCRE_TARBALL}"
  find "${PCRE_TARBALL%.tar.gz}" -print0 |xargs -0 touch -r .timestamp
fi

if [[ ! -d "${OPENSSL_TARBALL%.tar.gz}" ]]; then
  [ $UPGRADE -eq 1 ] && wget "http://www.openssl.org/source/${OPENSSL_TARBALL}"
  tar --no-same-owner --mtime=.timestamp -xvzf "${OPENSSL_TARBALL}" && rm -f "${OPENSSL_TARBALL}"
  find "${OPENSSL_TARBALL%.tar.gz}" -print0 |xargs -0 touch -r .timestamp
fi

if [[ ! -d "${ZLIB_TARBALL%.tar.gz}" ]]; then
  [ $UPGRADE -eq 1 ] && wget "http://zlib.net/${ZLIB_TARBALL}"
  tar --no-same-owner --mtime=.timestamp -xvzf "${ZLIB_TARBALL}" && rm -rf "${ZLIB_TARBALL}"
  find "${ZLIB_TARBALL%.tar.gz}" -print0 |xargs -0 touch -r .timestamp
fi
if [[ ! -d "${HAPROXY_TARBALL%.tar.gz}" ]]; then
  [ $UPGRADE -eq 1 ] && wget "http://www.haproxy.org/download/${HAPROXY_MAJOR_VERSION}/src/${HAPROXY_TARBALL}"
  tar --no-same-owner --mtime=.timestamp -zxvf "${HAPROXY_TARBALL}" && rm -rf "${HAPROXY_TARBALL}"
  find "${HAPROXY_TARBALL%.tar.gz}" -print0 |xargs -0 touch -r .timestamp
fi
#if [[ ! -d "${GLIBC_TARBALL%.tar.gz}" ]]; then
#  wget "http://ftp.download-by.net/gnu/gnu/libc/${GLIBC_TARBALL}"
#  tar --no-same-owner -mtime=.timestamp -zvzf "${GLIBC_TARBALL}" && rm -rf "${GLIBC_TARBALL}"
#  find "${GLIBC_TARBALL%.tar.gz}" -print0 |xargs -0 touch -r .timestamp
#fi
cd $CWD/openssl-${OPENSSL_VERSION}
SSLDIR=$CWD/opensslbin
mkdir -p $SSLDIR
./config --prefix=$SSLDIR no-shared no-ssl2
make && make install_sw
PCREDIR=$CWD/pcrebin
mkdir -p $PCREDIR
cd $CWD/pcre-${PCRE_VERSION}
CFLAGS='-O2 -Wall' ./configure --prefix=$PCREDIR --disable-shared --enable-jit
make && make install
ZLIBDIR=$CWD/zlibbin
mkdir -p $ZLIBDIR
cd $CWD/zlib-${ZLIB_VERSION}
./configure --static --prefix=$ZLIBDIR
make && make install
# patch makefile to allow ZLIBPATHS
#GLIBCDIR=$CWD/glibcbin
#mkdir -p $GLIBCDIR
#mkdir -p $CWD/glibcbuild
#cd $CWD/glibcbuild
#$CWD/glibc-${GLIBC_VERSION}/configure --prefix=$GLIBCDIR --enable-static-nss
#make && make install
mkdir -p $CWD/bin
cd $CWD/haproxy-${HAPROXY_VERSION}
patch -p0 Makefile < $CWD/haproxy_makefile.patch
sed -ibak "s#PREFIX = /usr/local#PREFIX = $CWD/bin#g" Makefile
make TARGET=linux-glibc CPU=native USE_PCRE=1 USE_ZLIB=1 USE_OPENSSL=1 PCREDIR=$CWD/pcrebin ZLIB_LIB=$ZLIBDIR/lib ZLIB_INC=$ZLIBDIR/include SSL_INC=$SSLDIR/include SSL_LIB=$SSLDIR/lib ADDLIB="-lz -lpthread" LDFLAGS="-lc -ldl -Wl,-static -static -static-libgcc -s"
make install
cd $CWD/bin
cp $CWD/zlib-${ZLIB_VERSION}/README ZLIB-LICENSE
cp $CWD/openssl-${OPENSSL_VERSION}/LICENSE OpenSSL-License
cp $CWD/pcre-${PCRE_VERSION}/LICENCE PCRE-LICENSE
cp $CWD/haproxy-${HAPROXY_VERSION}/LICENSE HAPROXY-LICENSE
cat << EOF > README
Statically linked haproxy for production use.
Linked against
   Zlib ${ZLIB_VERSION}
   OpenSSL ${OPENSSL_VERSION}
   Pcre ${PCRE_VERSION}
See http://github.com/askholme/static-haproxy for more info
EOF
tar czf $TRAVIS_BUILD_DIR/$PCK_NAME.tar.gz .
