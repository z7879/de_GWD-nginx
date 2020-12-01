#!/bin/bash
NGINX_VERSION="1.19.5"
GO_VERSION="1.15.5"

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install --no-install-recommends --no-install-suggests -y ca-certificates wget curl unzip git build-essential cmake autoconf libtool libpcre3-dev zlib1g-dev libatomic-ops-dev



wget -N https://dl.google.com/go/go$GO_VERSION.linux-arm64.tar.gz
tar -xvf go*linux-arm64.tar.gz
sudo rm -rf go*linux-arm64.tar.gz

sudo mv -f go /usr/local
export GOROOT=/usr/local/go
export GOPATH=$HOME/work
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH



curl https://sh.rustup.rs -sSf | bash -s -- -y
export PATH="$HOME/.cargo/bin:$PATH"


sudo mkdir -p "/etc/nginx/conf.d"
sudo mkdir -p /var/log/nginx
sudo mkdir -p /var/cache/nginx/client_temp
sudo mkdir -p /var/cache/nginx/proxy_temp
sudo mkdir -p /var/cache/nginx/fastcgi_temp
sudo mkdir -p /var/cache/nginx/scgi_temp
sudo mkdir -p /var/cache/nginx/uwsgi_temp

git clone --recursive https://github.com/cloudflare/quiche

git clone https://github.com/cloudflare/zlib.git
cd zlib
make -f Makefile.in distclean
cd ..

git clone https://github.com/google/ngx_brotli.git
cd ngx_brotli
git submodule update --init
cd ..

wget https://ftp.pcre.org/pub/pcre/pcre-8.44.tar.gz
tar -zxvf pcre-8.44.tar.gz

wget https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz
tar zxvf nginx-$NGINX_VERSION.tar.gz
sed -i 's/CFLAGS="$CFLAGS -g"/#CFLAGS="$CFLAGS -g"/' nginx-$NGINX_VERSION/auto/cc/gcc
mv -f nginx-$NGINX_VERSION nginx
cd nginx
curl https://raw.githubusercontent.com/kn007/patch/master/nginx_with_quic.patch | patch -p1
curl https://raw.githubusercontent.com/kn007/patch/master/Enable_BoringSSL_OCSP.patch | patch -p1
./configure \
  --prefix=/etc/nginx \
  --sbin-path=/usr/sbin/nginx \
  --conf-path=/etc/nginx/nginx.conf \
  --error-log-path=/var/log/nginx/error.log \
  --http-log-path=/var/log/nginx/access.log \
  --pid-path=/run/nginx.pid \
  --lock-path=/run/nginx.lock \
  --http-client-body-temp-path=/var/cache/nginx/client_temp \
  --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
  --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
  --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
  --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
  --user=www-data \
  --group=www-data \
  --with-compat \
  --with-file-aio \
  --with-threads \
  --with-libatomic \
  --with-mail \
  --with-mail_ssl_module \
  --with-http_realip_module \
  --with-http_ssl_module \
  --with-http_addition_module \
  --with-http_sub_module \
  --with-http_dav_module \
  --with-http_stub_status_module \
  --with-http_flv_module \
  --with-http_mp4_module \
  --with-http_gunzip_module \
  --with-http_slice_module \
  --with-http_gzip_static_module \
  --with-http_auth_request_module \
  --with-http_random_index_module \
  --with-http_secure_link_module \
  --with-http_degradation_module \
  --with-http_v2_module \
  --with-http_v3_module \
  --with-http_v2_hpack_enc \
  --with-stream \
  --with-stream_realip_module \
  --with-stream_ssl_module \
  --with-stream_ssl_preread_module \
  --with-zlib=../zlib \
  --with-pcre=../pcre-8.44 \
  --with-pcre-jit \
  --with-quiche=../quiche \
  --with-openssl=../quiche/deps/boringssl \
  --with-cc-opt='-DTCP_FASTOPEN=23 -g -O2 -pipe -Wall -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC' \
  --with-ld-opt='-Wl,-Bsymbolic-functions -Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie' \
  --add-module=../ngx_brotli
make -j $(nproc --all)
