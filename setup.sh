#!/usr/bin/env bash

sudo aptitude update
sudo aptitude safe-upgrade

# Install some stuff
sudo aptitude install htop vim build-essential curl git-core libtcmalloc-minimal0 zlib1g-dev libssl-dev libreadline5-dev strace ltrace tcpdump bash-completion libgmp3-dev libglut3-dev fail2ban denyhosts tree rake python-software-properties

# Setup firewall
sudo aptitude install ufw
sudo ufw allow http
sudo ufw allow ssh
sudo ufw enable

# Install ghc
wget http://haskell.org/ghc/dist/7.0.3/ghc-7.0.3-x86_64-unknown-linux.tar.bz2
tar xjf ghc-7.0.3-x86_64-unknown-linux.tar.bz2
pushd ghc-7.0.3
./configure && sudo make install
popd

# Install haskell-platform
wget http://lambda.galois.com/hp-tmp/2011.2.0.1/haskell-platform-2011.2.0.1.tar.gz
tar zxf haskell-platform-2011.2.0.1.tar.gz
pushd haskell-platform-2011.2.0.1
./configure && make && sudo make install
popd

# Install haskell stuff
cabal update
sudo cabal install pandoc

# Install redis
wget http://redis.googlecode.com/files/redis-2.2.107-scripting.tar.gz
tar zxf redis-2.2.107-scripting.tar.gz
pushd redis-2.2.107-scripting
make && sudo make install
popd

redis_dir=/tmp/redis
redis_mem=$((64 * 1024 * 1024))

cat | sudo tee /etc/redis.conf <<END
bind 127.0.0.1
dir $redis_dir
maxmemory $redis_mem
appendonly yes
END

cat | sudo tee /etc/init/redis.conf <<END
description "redis"

start on runlevel [2345]
stop on runlevel [06]

respawn

pre-start script
  if [ ! -d $redis_dir ]; then
    mkdir -p $redis_dir
    chown -R darkhelmet:darkhelmet $redis_dir
  fi
end script

exec sudo -u darkhelmet /usr/local/bin/redis-server /etc/redis.conf
END

sudo start redis

# Install Java
echo "deb http://archive.canonical.com/ lucid partner" | sudo tee /etc/apt/sources.list.d/java.list
sudo aptitude update
echo 'sun-java6-bin shared/accepted-sun-dlj-v1-1 boolean true' | sudo debconf-set-selections
sudo aptitude install sun-java6-jdk

jruby_version=1.6.1

# Install jruby
wget http://jruby.org.s3.amazonaws.com/downloads/1.6.1/jruby-bin-$jruby_version.tar.gz
tar zxf jruby-bin-$jruby_version.tar.gz
sudo mv jruby-$jruby_version /opt/jruby

sudo add-apt-repository ppa:nginx
sudo aptitude update
sudo aptitude install nginx

cat | sudo tee /etc/nginx/nginx.conf <<END
user www-data;
worker_processes 4;
pid /var/run/nginx.pid;

events {
  worker_connections 1024;
}

http {
  keepalive_timeout 65;
	server_tokens off;

	include /etc/nginx/mime.types;
	default_type application/octet-stream;

	##
	# Logging Settings
	##

	access_log /var/log/nginx/access.log;
	error_log /var/log/nginx/error.log;

	##
	# Gzip Settings
	##

	gzip on;
	gzip_disable "msie6";

  gzip_vary on;
  gzip_proxied any;
  gzip_comp_level 6;
  gzip_buffers 16 8k;
  gzip_http_version 1.1;
  gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;

	##
	# Virtual Host Configs
	##

  server {
    listen 80;

    location / {
      proxy_set_header  X-Real-IP \$remote_addr;
      proxy_set_header  X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header  Host \$http_host;
      proxy_redirect    off;
      proxy_pass        http://127.0.0.1:3000;
    }
  }
}
END

sudo /etc/init.d/nginx restart

cat | sudo tee /etc/init/kindlebility.conf <<END
description "kindlebility"

start on runlevel [2345]
stop on runlevel [06]

chdir /home/darkhelmet/kindlebility3

respawn

exec sudo -u darkhelmet ./production.sh
END
