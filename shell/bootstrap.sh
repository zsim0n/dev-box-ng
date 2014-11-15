#!/bin/bash -eux

PUPPET_DIR='/vagrant/puppet'
gem update

cd $PUPPET_DIR

if [ `gem query --local | grep librarian-puppet | wc -l` -eq 0 ]; then
  librarian-puppet install --clean
else
  librarian-puppet update
fi

exec puppet apply \
    --hiera_config $PUPPET_DIR/hiera.yaml \
    --modulepath $PUPPET_DIR/modules \
    --debug \
    $PUPPET_DIR/manifests/init.pp
