# -*- mode: ruby -*-
# vi: set ft=ruby :

# Configuration variables - can be overridden by environment variables
VM_NAME = ENV['VM_NAME'] || "rocky9b"
VM_IP = ENV['VM_IP'] || "192.168.56.102"
VM_MEMORY = ENV['VM_MEMORY'] || 4096
VM_CPUS = ENV['VM_CPUS'] || 2
BRIDGE_INTERFACE = ENV['BRIDGE_INTERFACE'] || "wlp1s0"
ANSIBLE_USER = ENV['ANSIBLE_USER'] || "ansible"

# 1Password item IDs
ONEPASSWORD_CREDS_ID = "cu36afxxckm4mgnnkiltkne44u"  # Login credentials
ONEPASSWORD_SSH_KEY_ID = "kp7dx7dk3qq7h565ivc2fjslle"  # SSH key

# Function to fetch credentials from 1Password (only when needed)
def fetch_1password_credentials
  # Check if 1Password CLI is available
  unless system("command -v op > /dev/null 2>&1")
    puts "Error: 1Password CLI (op) is not installed"
    puts "Please install: https://developer.1password.com/docs/cli/get-started/"
    exit 1
  end

  # Check authentication
  unless system("op whoami > /dev/null 2>&1")
    puts "Error: Not authenticated with 1Password CLI"
    puts "Please run: op signin"
    exit 1
  end

  puts "Fetching credentials from 1Password..."
  
  # username = `op item get #{ONEPASSWORD_CREDS_ID} --fields username 2>/dev/null`.strip
  # password = `op item get #{ONEPASSWORD_CREDS_ID} --reveal --fields password 2>/dev/null`.strip
  # ssh_key = `op item get #{ONEPASSWORD_SSH_KEY_ID} --fields 'public key' 2>/dev/null`.strip

  username = "op://dev/.ansible_user_sudo_passwd/username"
  password = "op://dev/.ansible_user_sudo_passwd/password"
  ssh_key = "op://dev/ansible.local.lab/public key"
  
  if username.empty? || password.empty? || ssh_key.empty?
    puts "Error: Could not retrieve all required data from 1Password"
    puts "Check your 1Password item IDs and ensure you're authenticated"
    exit 1
  end
  
  puts "Successfully retrieved credentials from 1Password"
  return {
    username: username,
    password: password,
    ssh_key: ssh_key
  }
end

# Only fetch credentials for provisioning commands
NEEDS_CREDENTIALS = ARGV.any? { |arg| ['up', 'provision', 'reload'].include?(arg) }
CREDENTIALS = NEEDS_CREDENTIALS ? fetch_1password_credentials() : { username: ANSIBLE_USER, password: '', ssh_key: '' }

Vagrant.configure("2") do |config|
  config.vm.box = "rockylinux/9"
  config.vm.hostname = VM_NAME
  config.vm.network "private_network", ip: VM_IP, name: "vboxnet0"
  
  # Only add public network if bridge interface is specified
  if BRIDGE_INTERFACE && !BRIDGE_INTERFACE.empty?
    config.vm.network "public_network", bridge: BRIDGE_INTERFACE
  end

  # Disable default sync folder for better security and performance
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # VM resources
  config.vm.provider "virtualbox" do |vb|
    vb.name = VM_NAME
    vb.memory = VM_MEMORY.to_i
    vb.cpus = VM_CPUS.to_i
    
    # Additional VirtualBox optimizations
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
    vb.customize ["modifyvm", :id, "--vram", "16"]
  end

  # Only add provisioning if we have credentials
  if NEEDS_CREDENTIALS
    # Create ansible user with credentials from 1Password
    config.vm.provision "shell", inline: <<-SHELL
      ANSIBLE_USERNAME="#{CREDENTIALS[:username]}"
      ANSIBLE_PASSWORD="#{CREDENTIALS[:password]}"
      SSH_PUBLIC_KEY="#{CREDENTIALS[:ssh_key]}"
      
      echo "Setting up user: $ANSIBLE_USERNAME"

      # Create user if not exists
      if ! id -u "$ANSIBLE_USERNAME" &>/dev/null; then
        sudo useradd -m -G wheel -s /bin/bash "$ANSIBLE_USERNAME"
        echo "$ANSIBLE_USERNAME:$ANSIBLE_PASSWORD" | sudo chpasswd
        echo "Created user: $ANSIBLE_USERNAME"
      else
        echo "User $ANSIBLE_USERNAME already exists"
      fi

      # Setup SSH directory with proper permissions
      sudo mkdir -p "/home/$ANSIBLE_USERNAME/.ssh"
      sudo chmod 700 "/home/$ANSIBLE_USERNAME/.ssh"
      sudo chown "$ANSIBLE_USERNAME:$ANSIBLE_USERNAME" "/home/$ANSIBLE_USERNAME/.ssh"

      # Add public key to authorized_keys
      echo "$SSH_PUBLIC_KEY" | sudo tee "/home/$ANSIBLE_USERNAME/.ssh/authorized_keys" > /dev/null
      sudo chmod 600 "/home/$ANSIBLE_USERNAME/.ssh/authorized_keys"
      sudo chown "$ANSIBLE_USERNAME:$ANSIBLE_USERNAME" "/home/$ANSIBLE_USERNAME/.ssh/authorized_keys"
      echo "Added SSH public key for user: $ANSIBLE_USERNAME"

      # Configure sudoers for passwordless sudo
      echo "$ANSIBLE_USERNAME ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/$ANSIBLE_USERNAME" > /dev/null
      sudo chmod 440 "/etc/sudoers.d/$ANSIBLE_USERNAME"
      
      echo "User setup completed successfully"
      
      # Clear sensitive variables from memory
      unset ANSIBLE_PASSWORD SSH_PUBLIC_KEY
    SHELL
  end
end