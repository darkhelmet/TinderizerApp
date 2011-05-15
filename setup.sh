#!/usr/bin/env bash

sudo aptitude update
sudo aptitude safe-upgrade

# Install some stuff
sudo aptitude install htop vim build-essential curl git-core libtcmalloc-minimal0 zlib1g-dev libssl-dev libreadline5-dev strace ltrace tcpdump bash-completion libgmp3-dev libglut3-dev fail2ban denyhosts tree

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

exec sudo -u darkhelmet redis-server /etc/redis.conf
END

# Install sbt
echo 'java -Xmx512M -jar `dirname $0`/sbt-launch.jar "$@"' | sudo tee /usr/local/bin/sbt
sudo chmod +x /usr/local/bin/sbt
sudo curl http://simple-build-tool.googlecode.com/files/sbt-launch-0.7.7.jar -o /usr/local/bin/sbt-launch.jar
