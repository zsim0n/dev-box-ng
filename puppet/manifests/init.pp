Exec {
  path => ['/bin', '/sbin', '/usr/bin', '/usr/sbin', '/usr/local/bin'],
}

Package {
  ensure => 'present',
}

class { 'apt':
  update => {
    frequency => 'always',
  },
}

exec { 'apt-get update':
  command => '/usr/bin/apt-get update -y',
}

# ensure base packages
$packages = ['build-essential', 'keychain', 'git','curl', 'libxml2', 'libxml2-dev', 'libxslt1-dev', 'pwgen', 'mytop','xsltproc']

package { $packages:
  require => Exec['apt-get update'],
}
# dotfiles

exec { 'dotfiles':
  command => '/usr/bin/git clone https://github.com/zsim0n/dotfiles.git && cd /home/vagrant/dotfiles && chmod +x ./bootstrap.sh && ./bootstrap.sh -f && rm -Rf /home/vagrant/dotfiles',
  cwd  => '/home/vagrant',
  user => 'vagrant',
  require => Exec['apt-get update']
}


# Java is required
class { 'java': }

# Elasticsearch

class { 'elasticsearch':
  manage_repo  => true,
  repo_version => '1.5',
}

elasticsearch::instance { 'es-01':
  config => { 
  'cluster.name' => 'vagrant_elasticsearch',
  'index.number_of_replicas' => '0',
  'index.number_of_shards'   => '1',
  'network.host' => '0.0.0.0'
  },        # Configuration hash
  init_defaults => { }, # Init defaults hash
  before => Exec['kibana-start']
}

elasticsearch::plugin{'royrusso/elasticsearch-HQ':
  module_dir => 'HQ',
  instances  => 'es-01'
}

# Logstash

class { 'logstash':
#  autoupgrade  => true,
  ensure       => 'present',
  manage_repo  => true,
  repo_version => '1.4',
  status => 'disabled',
  require      => [ Class['java'], Class['elasticsearch']],
}


file { '/etc/profile.d/logstash-path.sh':
    mode    => 644,
    content => 'PATH=$PATH:/opt/logstash/bin',
    require => Class['logstash'],
}

# mysql

class { 'mysql':
  root_password => 'mask',
}

mysql::grant { 'vagrant':
  mysql_user       => 'vagrant',
  mysql_password   => 'vagrant',
  mysql_privileges => 'ALL',
  mysql_db         => '*',
}

file { '/home/vagrant/.my.cnf' :
  ensure  => present,
  content => template('/vagrant/puppet/templates/my.cnf.erb'),
  owner   => 'vagrant',
  group   => 'vagrant',
}

# Kibana

file { '/home/vagrant/kibana':
  ensure => 'directory',
  group  => 'vagrant',
  owner  => 'vagrant',
}

exec { 'kibana-download':
  command => '/usr/bin/curl -L https://download.elasticsearch.org/kibana/kibana/kibana-4.0.2-linux-x64.tar.gz | /bin/tar xvz -C /home/vagrant/kibana',
  require => [ Package['curl'], File['/home/vagrant/kibana'],Class['elasticsearch'] ],
  timeout     => 1800
}

exec {'kibana-start':
  command => '/bin/sleep 10 && /home/vagrant/kibana/kibana-4.0.2-linux-x64/bin/kibana & ',
  require => [ Exec['kibana-download']]
}

# nodejs
$npm_packages = ['yo', 'serve','bower','grunt-cli']

class {'nodejs': 
} ->
package { $npm_packages:
  provider => 'npm',
}

# apache
class { 'apache':
  process_user => 'vagrant',
  require      => Exec['apt-get update'],
}

apache::dotconf { 'custom':
  content => 'EnableSendfile Off',
}

apache::module { 'rewrite': }

apache::vhost { '000-default':
  priority                 => '',
  docroot                  => '/var/www',
  directory                => '/var/www',
  directory_allow_override => 'All',
  aliases                  => ['/adminer /usr/share/adminer'],
}

file { '/var/lock/apache2':
  ensure => directory,
  owner  => vagrant
}

exec { 'ApacheUserChange' :
  command => "sed -i 's/export APACHE_RUN_USER=.*/export APACHE_RUN_USER=vagrant/ ; s/export APACHE_RUN_GROUP=.*/export APACHE_RUN_GROUP=vagrant/' /etc/apache2/envvars",
  require => [ Package['apache'], File['/var/lock/apache2'] ],
  notify  => Service['apache'],
}

package {'apache2-utils':
  require => Package['apache'],
}

# php

$phpModules = [ 'fpm','imagick', 'xdebug', 'curl', 'mysql', 'cli', 'intl', 'mcrypt', 'memcache','gd', 'xsl']

class { 'php':
  service         => 'apache',
  install_options => [],
  notify          => Service['apache'],
  require         => [ Package['apache'], Exec['apt-get update'] ],
}

php::module { $phpModules: }

# php-mcrypt fix
exec { 'enable_mcrypt':
  command => 'php5enmod mcrypt',
  require => Package['php5-mcrypt'],
  notify  => Service['apache'],
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

augeas { 'php5-apache-ini':
  context => '/files/etc/php5/apache2/php.ini',
  changes => $php_changes,
  require => Package['php5'],
  notify  => Service['apache'],
}

augeas { 'php5-cli-ini':
  context => '/files/etc/php5/cli/php.ini',
  changes => $php_changes,
  require => Package['php5'],
  notify  => Service['apache'],
}

# php-xdebug
augeas { 'php5-xdebug':
  context => '/files/etc/php5/mods-available/xdebug.ini',
  changes => ['set XDebug/xdebug.remote_enable 1',
                'set XDebug/xdebug.profiler_enable 1',
                'set XDebug/xdebug.profiler_output_dir "/tmp"',
                'set XDebug/xdebug.max_nesting_level 400'],
  require => Package['php5-xdebug'],
  notify  => Service['apache'],
}

#  var/www symlink

file { '/vagrant':
  ensure  => 'directory',
  require => Package['php5'],
  before  => File[ '/var/www'],
}

file { '/var/www':
  ensure  => 'link',
  target  => '/vagrant',
  require => File['/vagrant'],
  notify  => Service['apache'],
  force   => true,
}

# drush

package { 'drush':
  require => Package['php5'],
}

exec { "drush dl drush --destination='/usr/share'":
  require => Package['drush'],
}

exec { 'wget https://raw.githubusercontent.com/drush-ops/drush/master/drush.complete.sh':
  cwd     => '/etc/bash_completion.d',
  creates => '/etc/bash_completion.d/drush.complete.sh',
  require => Package['drush'],
}

# wp-cli

exec { 'wpcli_install':
  command => 'curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && sudo mv wp-cli.phar /usr/local/bin/wp && sudo chmod a+x /usr/local/bin/wp',
  require => Package['curl', 'php5'],
}

# composer

exec { 'composer_install':
  command => 'curl -sS https://getcomposer.org/installer | php && sudo mv composer.phar /usr/local/bin/composer && sudo chmod a+x /usr/local/bin/composer',
  require => Package['curl', 'php5'],
}

# adminer

file { '/usr/share/adminer':
  ensure  => directory,
  replace => no,
  owner   => 'vagrant',
  group   => 'www-data',
  mode    => '0775',
  recurse => true,
  require => Package['php5'],
}

exec{ 'wget http://www.adminer.org/latest.php -O /usr/share/adminer/index.php':
  require => File['/usr/share/adminer'],
  creates => '/usr/share/adminer/index.php',
  returns => [ 0, 4 ],
}

# ruby & rbenv

rbenv::install { 'vagrant':
  group => 'vagrant',
  home  => '/home/vagrant',
  rc    => '.bash_profile',
}

rbenv::compile { '2.2.2':
  user   => 'vagrant',
  home   => '/home/vagrant',
  global => true,
}

rbenv::gem { 'jekyll':
  user => 'vagrant',
  ruby => '2.2.2',
}

rbenv::gem { 'compass':
  user => 'vagrant',
  ruby => '2.2.2',
}

rbenv::gem { 'yaml-lint':
  user => 'vagrant',
  ruby => '2.2.2',
}

rbenv::gem { 'mailcatcher':
  user   => 'vagrant',
  ruby   => '2.2.2',
  source => 'https://github.com/sj26/mailcatcher',
}

file { '/etc/init/mailcatcher.conf':
  ensure  => 'file',
  content => template('/vagrant/puppet/templates/mailcatcher.conf.erb'),
  mode    => '0755',
  require => Rbenv::Gem['mailcatcher'],
  notify  => Service['mailcatcher'],
}

file { '/var/log/mailcatcher':
  ensure  => 'directory',
  owner   => 'vagrant',
  group   => 'vagrant',
  mode    => '0755',
}

service { 'mailcatcher':
  ensure     => 'running',
  provider   => 'upstart',
  hasstatus  => true,
  hasrestart => true,
  require    => File['/etc/init/mailcatcher.conf'],
}

