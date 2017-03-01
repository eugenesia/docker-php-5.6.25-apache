################## Env setting ####################

export PHPIZE_DEPS='autoconf file g++ gcc libc-dev make pkg-config re2c'

apt-get update
apt-get install -y $PHPIZE_DEPS ca-certificates curl libedit2 libsqlite3-0 libxml2 xz-utils --no-install-recommends

export PHP_INI_DIR=/usr/local/etc/php
export APACHE_CONFDIR=/etc/apache2
export APACHE_ENVVARS=$APACHE_CONFDIR/envvars


set -ex;
sed -ri 's/^export ([^=]+)=(.*)$/: ${\1:=\2}\nexport \1/' "$APACHE_ENVVARS"

. "$APACHE_ENVVARS"

##########################


for dir in "$APACHE_LOCK_DIR" "$APACHE_RUN_DIR" "$APACHE_LOG_DIR" /var/www/html; do
  rm -rvf "$dir"
  mkdir -p "$dir"
  chown -R "$APACHE_RUN_USER:$APACHE_RUN_GROUP" "$dir";
done



a2dismod mpm_event && a2enmod mpm_prefork



############## Env setting ###############

. "$APACHE_ENVVARS"
ln -sfT /dev/stderr "$APACHE_LOG_DIR/error.log"
ln -sfT /dev/stdout "$APACHE_LOG_DIR/access.log"
ln -sfT /dev/stdout "$APACHE_LOG_DIR/other_vhosts_access.log"

##################################




# PHP files should be handled by PHP, and should be preferred over any other file type
{ \
echo '<FilesMatch \.php$>'; \
echo -e '\tSetHandler application/x-httpd-php'; \
echo '</FilesMatch>'; \
echo; \
echo 'DirectoryIndex disabled'; \
echo 'DirectoryIndex index.php index.html'; \
echo; \
echo '<Directory /var/www/>'; \
echo -e '\tOptions -Indexes'; \
echo -e '\tAllowOverride All'; \
echo '</Directory>'; \
} | tee "$APACHE_CONFDIR/conf-available/docker-php.conf"

a2enconf docker-php


################## Env setting ####################

export PHP_EXTRA_BUILD_DEPS=apache2-dev
export PHP_EXTRA_CONFIGURE_ARGS=--with-apxs2


# Apply stack smash protection to functions using local buffers and alloca()
# Make PHP's main executable position-independent (improves ASLR security mechanism, and has no performance impact on x86_64)
# Enable optimization (-O2)
# Enable linker optimization (this sorts the hash buckets to improve cache locality, and is non-default)
# Adds GNU HASH segments to generated executables (this is used if present, and is much faster than sysv hash; in this configuration, sysv hash is also generated)
# https://github.com/docker-library/php/issues/272
export PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2"
export PHP_CPPFLAGS="$PHP_CFLAGS"
export PHP_LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie"


export PHP_VERSION=5.1.6
export PHP_URL="http://museum.php.net/php5/php-5.1.6.tar.gz"
export PHP_ASC_URL="http://museum.php.net/php5/php-5.1.6.tar.gz"


########################





set -xe; \
  \
  fetchDeps='wget';
  apt-get update; \
  apt-get install -y --no-install-recommends $fetchDeps; \
  rm -rf /var/lib/apt/lists/*; \
  \
  mkdir -p /usr/src; \
  cd /usr/src; \
  \
  wget -O php.tar.xz "$PHP_URL"; \
  \
  if [ -n "$PHP_ASC_URL" ]; then \
    wget -O php.tar.gz "$PHP_ASC_URL"; \
  fi;



# IN HOST
# docker cp docker-php-source loving_ptolemy:/usr/local/bin/
# Remember to modify docker-php-source change php.tar.xz to php.tar.gz


set -xe;
# Added bison flex libeditline0
export buildDeps="$PHP_EXTRA_BUILD_DEPS libcurl4-openssl-dev libedit-dev libsqlite3-dev libssl-dev libxml2-dev bison flex libeditline0"
apt-get update
apt-get install -y $buildDeps --no-install-recommends

export CFLAGS="$PHP_CFLAGS" CPPFLAGS="$PHP_CPPFLAGS" LDFLAGS="$PHP_LDFLAGS"
docker-php-source extract
cd /usr/src/php

# --enable-ftp is included here because ftp_ssl_connect() needs ftp to be compiled statically (see https://github.com/docker-library/php/issues/236)
# --enable-mbstring is included here because otherwise there's no way to get pecl to use it properly (see https://github.com/docker-library/php/issues/195)
# --enable-mysqlnd is included here because it's harder to compile after the fact than extensions are (since it's a plugin for several extensions, not an extension in itself)

# Error during configure:
# configure: error: Please reinstall libedit - I cannot find readline.h
# Bug report: https://bugs.php.net/bug.php?id=50209
# Solution: apt-get install libreadline-dev (--with-libedit still works)
# Added info about readline.h from 'dpkg -L libedit-dev'
./configure --with-config-file-path="$PHP_INI_DIR" --with-config-file-scan-dir="$PHP_INI_DIR/conf.d" --disable-cgi --enable-ftp --enable-mbstring --enable-mysqlnd --with-curl --with-libedit --with-openssl --with-zlib $PHP_EXTRA_CONFIGURE_ARGS


make -j "$(nproc)"
make install 
{ find /usr/local/bin /usr/local/sbin -type f -executable -exec strip --strip-all '{}' + || true; }
make clean



