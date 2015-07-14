# -*- mode: ruby -*-
# vi: set ft=ruby :

# To install store sample data
sample_data = "false"
nuke_n_pave = "true"

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/trusty64"
  config.vm.hostname = "magento.io"

  config.vm.provision :shell, :path => "scripts/bootstrap.sh", :args => [sample_data, nuke_n_pave]

  # Requires: vagrant plugin install vagrant-vbguest
  config.vbguest.auto_update = false

  # Visit the site at http://192.168.50.44
  config.vm.network :private_network, ip: "192.168.50.44"

  config.vm.network :forwarded_port, guest: 80, host: 8080

  # Requires: vagrant plugin install vagrant-vbguest
  config.vbguest.auto_update = false

  # Required for passing ssh keys
  config.ssh.forward_agent = true

  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--memory", "1024"]
    vb.name = "magento.io"
  end

end
