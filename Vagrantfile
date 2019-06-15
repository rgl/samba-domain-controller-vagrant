ENV['VAGRANT_NO_PARALLEL'] = 'yes'

Vagrant.configure('2') do |config|
  config.vm.provider :libvirt do |lv|
    lv.memory = 2*1024
    lv.cpus = 2
    lv.cpu_mode = 'host-passthrough'
    lv.keymap = 'pt'
  end

  config.vm.provider :virtualbox do |vb|
    vb.linked_clone = true
    vb.memory = 2*1024
    vb.cpus = 2
  end

  config.vm.define :dc do |config|
    config.vm.box = 'ubuntu-18.04-amd64'
    config.vm.provider :libvirt do |lv|
      config.vm.synced_folder '.', '/vagrant', type: 'nfs'
    end
    config.vm.hostname = 'dc.example.com'
    config.vm.network 'private_network', ip: '192.168.56.2', libvirt__forward_mode: 'route', libvirt__dhcp_enabled: false
    config.vm.provision :shell, path: 'provision-base.sh'
    config.vm.provision :shell, path: 'provision-samba.sh'
    config.vm.provision :shell, path: 'provision-example-users.sh'
    config.vm.provision :reload
  end

  config.vm.define :windows do |config|
    config.vm.box = 'windows-2019-amd64'
    config.vm.provider :libvirt do |lv|
      lv.memory = 4*1024
      config.vm.synced_folder '.', '/vagrant', type: 'smb', smb_username: ENV['USER'], smb_password: ENV['VAGRANT_SMB_PASSWORD']
    end
    config.vm.provider :virtualbox do |vb|
      vb.memory = 4*1024
    end
      config.vm.hostname = 'windows'
    config.vm.network 'private_network', ip: '192.168.56.3', libvirt__forward_mode: 'route', libvirt__dhcp_enabled: false
    # config.vm.provision 'windows-sysprep'
    config.vm.provision :shell, path: 'windows/locale.ps1'
    config.vm.provision :shell, path: 'windows/add-to-domain.ps1'
    config.vm.provision :shell, reboot: true
    config.vm.provision :shell, path: 'windows/provision-firewall.ps1'
    config.vm.provision :shell, path: 'windows/provision-remote-administration-tools.ps1'
    # TODO install Apache Directory Studio
    config.vm.provision :shell, path: 'windows/summary.ps1'
  end
end