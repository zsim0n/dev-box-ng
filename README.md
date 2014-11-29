dev-box-ng
===========

A minimalistic  developer environment built on vagrant

## Prerequisites

The project has been tested on

* OS X 10.9 (Mavericks)

* [VirtualBox 4.3.18](https://www.virtualbox.org/wiki/Downloads)

* [Vagrant 1.6.5](http://downloads.vagrantup.com/)

## Base box
There is a tailor made [base box](https://vagrantcloud.com/zsim0n/awesome-trusty) built  with [packer.io](https://packer.io/) for better performance or fewer headache. (Packer project can be found [here](https://github.com/zsim0n/packer-io-box))

* build-essentials, libs, dev libs
* virtual box guest addition 4.3.18
* git
* Ruby 1.9.3-p547
    * gems
    * bundler
    * puppet
    * libratian-puppet
    * augeas
* mc
* vim
* sqlite 
* wge
* curl

## Provisioning
The box using ssh.agent.forwarding, and provisions ssh keys from user's home.

The work folder is `./src`

The box allocates 4 CPU and 2GB RAM by default

Port forwards and locations:

* 80 -> 8080 (http)
* 443 -> 8443 (https)
* 1080 -> 1880 (mailcatcher)
* http://localhost/adminer

## Bootstrap.sh
Simple shell provisioner that invokes librarian-puppet and puppet

## init.pp
Packages installed with puppet provisioner:

* Base packages
    * keychain,nodejs,curl
* LAMP stack
    * apache, php 5.5, mysql (vagrant:vagrant)
* PHP modules
    * imagick, xdebug, curl, mysql, cli, intl, mcrypt, memcache, gd
    * php.ini for development
    * drush
    * composer
    * mailcatcher
    * adminer
    * [zsim0n/dotfiles](https://github.com/zsim0n/dotfiles) 

## Vagrant Plugins

Some  [Vagrant Plugins](https://github.com/mitchellh/vagrant/wiki/Available-Vagrant-Plugins) are in use for better experience

* [vagrant-vbguest](https://github.com/dotless-de/vagrant-vbguest)
* [vagrant-list](https://github.com/joshmcarthur/vagrant-list)


Installing vagrant plugin

```
   $ vagrant plugin install [plugin name]
```

## How To Use
    host $ git clone https://github.com/zsim0n/php-dev-box.git
    host $ cd php-dev-box
    host $ vagrant up

That's it.

## Vagrant

Check the [Vagrant documentation](http://docs.vagrantup.com/v2/) for more information on Vagrant.

## License

Released under the MIT License, Copyright (c) 2014–<i>ω</i> Zoltan Simon.