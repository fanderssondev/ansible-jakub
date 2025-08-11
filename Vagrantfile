Vagrant.configure("2") do |config|
  config.vm.box = "rockylinux/9"
  config.vm.hostname = "rocky9b"
  config.vm.network "private_network", ip: "192.168.56.102", name: "vboxnet0"
  config.vm.network "public_network", bridge: "wlp1s0"

  # Disable sync folders (workaround)
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # VM resources
  config.vm.provider "virtualbox" do |vb|
    vb.name = "rocky9b"
    vb.memory = 4096
    vb.cpus = 2
  end

  # Create user 'ansible' with password 'admin' and wheel group membership
  config.vm.provision "shell", inline: <<-SHELL
    # Create user if not exists
    sudo id -u ansible &>/dev/null || sudo useradd -m -G wheel ansible
    echo "ansible:admin" | sudo chpasswd

    # Ensure .ssh directory exists
    sudo mkdir -p /home/ansible/.ssh
    sudo chmod 700 /home/ansible/.ssh
    sudo chown ansible:ansible /home/ansible/.ssh

    # Add public key to authorized_keys
    echo "#{File.read('/home/fredrik/.ssh/ansible.local.lab.pub').strip}" | sudo tee /home/ansible/.ssh/authorized_keys
    sudo chmod 600 /home/ansible/.ssh/authorized_keys
    sudo chown ansible:ansible /home/ansible/.ssh/authorized_keys  
  SHELL

  # Run your Ansible playbook inside VM
  config.vm.provision "ansible" do |ansible|
    ansible.limit = "rocky9b"
    ansible.playbook = "playbook.yml"
    ansible.inventory_path = "inventory.yml"
    ansible.config_file = "ansible.cfg"
  end
end
