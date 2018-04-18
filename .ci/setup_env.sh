set -e

SSL_VER=$OPENSSL.$CISCOSSL
CISCOSSL_INSTALL=/usr/local/cisco
#---------
# Download
#---------
OPENSSL_DOWNLOAD=$DOWNLOAD_CACHE/openssl-$OPENSSL
OPENRESTY_DOWNLOAD=$DOWNLOAD_CACHE/openresty-$OPENRESTY
LUAROCKS_DOWNLOAD=$DOWNLOAD_CACHE/luarocks-$LUAROCKS

mkdir -p $OPENSSL_DOWNLOAD $OPENRESTY_DOWNLOAD $LUAROCKS_DOWNLOAD

# We will install our side-by-side ciscoSSL
# But first we remove the libssl-dev that is no longer useful to us
sudo apt-get remove libssl-dev
sudo dpkg -i ./pkg/ciscossl_$SSL_VER-1_amd64.deb
sudo dpkg -i ./pkg/ciscossl-dev_$SSL_VER-1_amd64.deb

# if [ ! "$(ls -A $OPENSSL_DOWNLOAD)" ]; then
#   pushd $OPENSSL_DOWNLOAD
#     touch ciscossl_downloaded
#   popd
# fi

if [ ! "$(ls -A $OPENRESTY_DOWNLOAD)" ]; then
  pushd $DOWNLOAD_CACHE
    curl -L https://openresty.org/download/openresty-$OPENRESTY.tar.gz | tar xz
  popd
fi

if [ ! "$(ls -A $LUAROCKS_DOWNLOAD)" ]; then
  git clone https://github.com/keplerproject/luarocks.git $LUAROCKS_DOWNLOAD
fi

#--------
# Install
#--------
OPENSSL_INSTALL=$INSTALL_CACHE/openssl-$OPENSSL
OPENRESTY_INSTALL=$INSTALL_CACHE/openresty-$OPENRESTY
LUAROCKS_INSTALL=$INSTALL_CACHE/luarocks-$LUAROCKS

mkdir -p $OPENSSL_INSTALL $OPENRESTY_INSTALL $LUAROCKS_INSTALL

# if [ ! "$(ls -A $OPENSSL_INSTALL)" ]; then
#  pushd $OPENSSL_INSTALL
#     touch ciscossl_installed
#  popd
# fi

if [ ! "$(ls -A $OPENRESTY_INSTALL)" ]; then
  OPENRESTY_OPTS=(
    "--prefix=$OPENRESTY_INSTALL"
    # "--with-openssl=$OPENSSL_DOWNLOAD"
    "--with-cc-opt=-I${CISCOSSL_INSTALL}/include/"
    "--with-ld-opt=-L${CISCOSSL_INSTALL}/lib/"
    "--with-ipv6"
    "--with-pcre-jit"
    "--with-http_ssl_module"
    "--with-http_realip_module"
    "--with-http_stub_status_module"
    "--with-http_v2_module"
  )

  pushd $OPENRESTY_DOWNLOAD
    ./configure ${OPENRESTY_OPTS[*]}
    make
    make install
  popd
fi

if [ ! "$(ls -A $LUAROCKS_INSTALL)" ]; then
  pushd $LUAROCKS_DOWNLOAD
    git checkout v$LUAROCKS
    ./configure \
      --prefix=$LUAROCKS_INSTALL \
      --lua-suffix=jit \
      --with-lua=$OPENRESTY_INSTALL/luajit \
      --with-lua-include=$OPENRESTY_INSTALL/luajit/include/luajit-2.1
    make build
    make install
  popd
fi

export OPENSSL_DIR=$CISCOSSL_INSTALL  # for LuaSec install

export PATH=$PATH:$OPENRESTY_INSTALL/nginx/sbin:$OPENRESTY_INSTALL/bin:$LUAROCKS_INSTALL/bin

eval `luarocks path`

# -------------------------------------
# Install ccm & setup Cassandra cluster
# -------------------------------------
if [[ "$TEST_SUITE" != "unit" ]] && [[ "$TEST_SUITE" != "lint" ]]; then
  pip install --user PyYAML six ccm
  ccm create test -v $CASSANDRA -n 1 -d
  ccm start -v
  ccm status
fi

nginx -V
resty -V
luarocks --version
