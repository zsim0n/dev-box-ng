# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"
ENV['VAGRANT_DEFAULT_PROVIDER'] = 'virtualbox'

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.ssh.forward_agent = true
  config.ssh.insert_key = false
  config.ssh.private_key_path = ["#{Dir.home}/.ssh/id_rsa","#{Dir.home}/.vagrant.d/insecure_private_key"]

  config.vm.box = "zsim0n/awesome-trusty"
  config.vm.hostname = "box-ng.dev"

  config.vm.network "private_network", ip: "172.16.16.22"

  config.vm.provision :file do |file|
    file.source      = "#{Dir.home}/.ssh/id_rsa"
    file.destination = '/home/vagrant/.ssh/id_rsa'
  end
  
  config.vm.provision :file do |file|
    file.source      = "#{Dir.home}/.ssh/id_rsa.pub"
    file.destination = '/home/vagrant/.ssh/authorized_keys'
  end
  config.vm.provision :file do |file|
    file.source      = "#{Dir.home}/.ssh/id_rsa.pub"
    file.destination = '/home/vagrant/.ssh/id_rsa.pub'
  end

  config.vm.synced_folder '.', '/vagrant', type: 'nfs',  mount_options: ['rw', 'vers=3', 'tcp', 'fsc' ,'actimeo=2']

  config.vm.provision :shell, :path => 'shell/bootstrap.sh'

  config.vm.provider "virtualbox" do |v|
    v.customize ["modifyvm", :id, "--memory", 4096]
    v.customize ["modifyvm", :id, "--cpus", 4]
  end
end
