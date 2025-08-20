default:
    @just --list

# default VM
default_vm := "rocky9b"

# default verbosity for ansible-playbook (empty by default)
default_verbosity := ""

# Bring up a VM (or multiple)
up:
    vagrant up

# SSH into a VM
ssh vm=default_vm:
    vagrant ssh {{vm}}

# Halt a VM
halt vm=default_vm:
    vagrant halt {{vm}}

# Destroy a VM
destroy vm="":
    sed -i '/^192\.168\.56\.102/d' ~/.ssh/known_hosts
    vagrant destroy -f {{vm}}

# Run ansible-playbook against a VM
# Usage: just ansible rocky9a -vv
run-playbook vm=default_vm verbosity=default_verbosity:
    ansible-playbook -i inventory.yml playbook.yml -l {{vm}} {{verbosity}}

# Run ansible-playbook against multiple VMs (comma-separated list)
# Usage: just ansible-multi "rocky9a,rocky9b" -v
ansible-multi vms verbosity=default_verbosity:
    ansible-playbook -i inventory.yml playbook.yml -l {{vms}} {{verbosity}}
