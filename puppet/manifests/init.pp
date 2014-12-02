Exec {
  path => ['/usr/sbin', '/usr/bin', '/sbin', '/bin', '/usr/local/bin']
}

Package {
  ensure => 'present'
}

exec { 'apt-update':
  command => '/usr/bin/apt-get update -qq',
}

# ensure base packages
$packages = ['build-essential', 'keychain', 'git','curl', 'libxml2', 'libxml2-dev', 'libxslt1-dev']

package { $packages:
  require => Exec['apt-update'],
}

# node

class { 'nodejs':
  manage_repo => true,
  require => Exec['apt-update'],
}

exec { 'npm-post-install':
  command => 'npm install -g npm && sudo npm -g config set prefix /home/vagrant/npm',
  require => Class['nodejs'],
}

file {'/etc/profile.d/nodejs.sh':
  ensure => 'absent',
  require => Class['nodejs'],
}

profile::script { 'npm':
  priority => '050',
  content => template('/vagrant/puppet/templates/npm.sh.erb'),
  require => Exec['npm-post-install'],
}

define install_npm_package {
  exec { "npm install -g $name":
    cwd => '/home/vagrant',
    user => 'vagrant',
    require => Profile::Script['npm'],
  }
}
$npm_packages = ['yo','generator-angular', 'generator-bootstrap', 'generator-meanjs','generator-gruntfile','serve']

install_npm_package { $npm_packages : }

# php

$phpModules = [ 'fpm','imagick', 'xdebug', 'curl', 'mysql', 'cli', 'intl', 'mcrypt', 'memcache','gd']

class { 'php':
  service => 'apache',
  notify  => Service["apache"],
  require => Exec['apt-update'],
}

php::module { $phpModules: }

# php-mcrypt fix
exec { 'enable_mcrypt':
  command => 'php5enmod mcrypt',
  require => Package['php5-mcrypt'],
  notify  => Service["apache"],
}

$php_changes = [
	'set Date/date.timezone "Europe/Copenhagen"',
    'set PHP/memory_limit 128M',
    'set PHP/post_max_size 128M',
    'set PHP/upload_max_filesize 128M',
    'set PHP/error_reporting "E_ALL | E_STRICT"',
    'set PHP/display_errors On',
    'set PHP/display_startup_errors On',
    'set PHP/max_execution_time 600',
    'set PHP/max_input_tim 600',
    'set PHP/html_errors On',
    'set PHP/short_open_tag Off',
    'set PHP/zend.multibyte On',
    'rm PHP/error_log',
    'set "mail\ function/sendmail_path" "/usr/bin/env catchmail -f some@box-ng.dev"',
    'set "mail\ function/smtp_port" 1025',
    'set Phar/phar.readonly Off'
]

augeas {  'php5-apache-ini':
  context   => '/files/etc/php5/apache2/php.ini',
  changes   => $php_changes,
  require => Package["php5"],
  notify  => Service["apache"],
}

augeas {  'php5-cli-ini':
  context   => '/files/etc/php5/cli/php.ini',
  changes   => $php_changes,
  require => Package["php5"],
  notify  => Service["apache"],
}

# php-xdebug
augeas { 'php5-xdebug':
  context   => '/files/etc/php5/mods-available/xdebug.ini',
  changes   => ['set XDebug/xdebug.remote_enable 1',
                'set XDebug/xdebug.remote_port 9000',
                'set XDebug/xdebug.profiler_enable 1',
                'set XDebug/xdebug.profiler_output_dir "/tmp"',
                'set XDebug/xdebug.max_nesting_level 255'],
  require => Package["php5-xdebug"],
  notify  => Service["apache"],

}

#  var/www symlinking
file { "/vagrant/src":
  ensure  => "directory",
  require => Package["php5"],
  before => File[ '/var/www'],
}

file { '/var/www':
  ensure  => "link",
  target  => "/vagrant/src",
  require => File['/vagrant/src'],
  notify  => Service["apache"],
  force   => true,
}

# apache
class { 'apache':
  process_user => 'vagrant',
}

apache::module { 'rewrite': }

apache::vhost { '000-default':
   priority                  => '',
   docroot                   => '/var/www',
   directory                 => '/var/www',
   directory_allow_override  => 'All',
   aliases 					 => ['/adminer /usr/share/adminer']
}

# mysql 

class { "mysql":
  root_password => 'mask',
}

mysql::grant { 'vagrant':
  mysql_user => 'vagrant',
  mysql_password => 'vagrant',
  mysql_privileges => 'ALL',
  mysql_db => '*',
}

file { '/home/vagrant/.my.cnf' :
	ensure => present,
    content => template('/vagrant/puppet/templates/my.cnf.erb'),
    owner => 'vagrant',
    group => 'vagrant',  
}

# drush

package {'drush':
  require => Package['php'],
}

exec { "drush dl drush --destination='/usr/share'":
  require => Package['drush'],
}

exec { 'wget https://raw.githubusercontent.com/drush-ops/drush/master/drush.complete.sh':
  cwd => '/etc/bash_completion.d',
  creates => "/etc/bash_completion.d/drush.complete.sh",
  require => Package['drush'],
}

# composer

exec { 'composer_install':
  command => 'curl -sS https://getcomposer.org/installer | php && sudo mv composer.phar /usr/local/bin/composer && sudo chmod a+x /usr/local/bin/composer',
  require => Package['curl', 'php'],
}

# adminer

file { '/usr/share/adminer':
  replace => no,
  ensure  => directory,
  owner => 'vagrant',
  group => 'www-data',
  mode    => 775,
  recurse => true,
  require => Package['php']
}

exec{ 'wget http://www.adminer.org/latest.php -O /usr/share/adminer/index.php':
  require => File['/usr/share/adminer'],
  creates => "/usr/share/adminer/index.php",
  returns => [ 0, 4 ],
}


# ruby & rbenv

rbenv::install { "vagrant":
  group => 'vagrant',
  home  => '/home/vagrant',
  rc   => ".bash_profile",
}

rbenv::compile { "2.1.4":
  user => "vagrant",
  home => "/home/vagrant",
  global => true,
}

rbenv::gem { "jekyll":
  user => "vagrant",
  ruby => "2.1.4",
}

package { 'compass':
  ensure   => 'installed',
  provider => 'gem',
}

# mailcatcher

  package { 'mailcatcher':
    ensure   => 'present',
    provider => 'gem',
  }

  file {'/etc/init/mailcatcher.conf':
    ensure  => 'file',
    content => template('/vagrant/puppet/templates/mailcatcher.conf.erb'),
    mode    => '0755',
    require => Package['mailcatcher'],
    notify  => Service['mailcatcher'],
  }

  file {'/var/log/mailcatcher':
    ensure  => 'directory',
    owner   => 'vagrant',
    group   => 'vagrant',
    mode    => '0755',
  }
  
  service {'mailcatcher':
    ensure     => 'running',
    provider   => 'upstart',
    hasstatus  => true,
    hasrestart => true,
    require    => File['/etc/init/mailcatcher.conf'],
  }

# dotfiles

exec { "git clone https://github.com/zsim0n/dotfiles.git && cd /home/vagrant/dotfiles && chmod +x ./bootstrap.sh && ./bootstrap.sh -f && rm -Rf /home/vagrant/dotfiles":
  cwd => '/home/vagrant',
  user => 'vagrant',
}

# mondgodb

class {'::mongodb::globals':
  manage_package_repo => true,
}->
class {'::mongodb::server': 
  config => '/etc/mongod.conf',
}->
class {'::mongodb::client': }

