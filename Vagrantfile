# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "zsim0n/awesome-trusty"
  config.vm.hostname = "dev-box-ng.dev"
  config.vm.network "private_network", ip: "172.16.16.22"
  config.vm.synced_folder '.', '/vagrant', type: 'nfs',  mount_options: ['rw', 'vers=3', 'tcp', 'fsc' ,'actimeo=2']
  config.vm.provision :shell, :path => 'shell/bootstrap.sh'
  config.vm.provider "virtualbox" do |v|
    v.customize ["modifyvm", :id, "--memory", 4096]
    v.customize ["modifyvm", :id, "--cpus", 4]
  end
end

