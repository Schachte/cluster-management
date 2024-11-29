#!/bin/bash

# Function to check and clean existing VM
handle_existing_vm() {
    local vm_name=$1

    if multipass list | grep -q "$vm_name"; then
        echo "🔍 Found existing VM: $vm_name"
        echo "🛑 Stopping $vm_name..."
        multipass stop "$vm_name"
        echo "🗑️ Deleting $vm_name..."
        multipass delete "$vm_name"
        echo "🧹 Purging deleted VMs..."
        multipass purge
    fi
}

create_vm() {
    local vm_name=$1
    local ip=$2

    echo "🚀 Creating VM: $vm_name"
    handle_existing_vm "$vm_name"
    multipass launch --name "$vm_name" --cpus 2 --memory 2G --disk 10G

    echo "⏳ Waiting for VM to be ready..."
    sleep 10

    echo "🔧 Configuring network for $vm_name..."
    multipass exec "$vm_name" -- sudo bash -c "
        cat > /etc/netplan/99-custom.yaml << EOF
network:
    version: 2
    ethernets:
        enp0s1:
            addresses: [${ip}/24]
            nameservers:
                addresses: [8.8.8.8, 8.8.4.4]
EOF
        
        netplan apply
    "
    echo "✅ VM $vm_name created successfully with IP $ip"
}

create_users() {
    echo "👥 Starting user creation process..."
    # Get list of all running instances
    instances=($(multipass list --format csv | tail -n +2 | cut -d',' -f1))

    for instance in "${instances[@]}"; do
        echo "👤 Creating user schachte on $instance..."

        # Create user and add to sudo group
        multipass exec "$instance" -- sudo bash -c '
        # Create user if not exists
        if ! id "schachte" &>/dev/null; then
            useradd -m -s /bin/bash schachte
            echo "schachte:password123" | chpasswd
            usermod -aG sudo schachte
            echo "schachte ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/schachte
            mkdir -p /home/schachte/.ssh
            chmod 700 /home/schachte/.ssh
            chown -R schachte:schachte /home/schachte/.ssh
            echo "✅ User schachte created successfully"
        else
            echo "ℹ️  User schachte already exists"
        fi
    '

        # If you want to add your SSH key
        if [ -f "$HOME/.ssh/cluster.pub" ]; then
            echo "🔑 Adding SSH key to $instance..."
            cat "$HOME/.ssh/cluster.pub" | multipass exec "$instance" -- sudo bash -c 'cat > /home/schachte/.ssh/authorized_keys && chown schachte:schachte /home/schachte/.ssh/authorized_keys && chmod 600 /home/schachte/.ssh/authorized_keys'
        fi
    done

    echo "🔍 Testing user creation..."

    # Test user creation on each instance
    for instance in "${instances[@]}"; do
        echo "🧪 Testing user on $instance:"
        multipass exec "$instance" -- sudo -u schachte whoami
    done
}

# VM names and IPs
vm_names=("dev-node-1" "dev-node-2" "dev-node-3")

# Doesn't do anything, just a placeholder (Mac issues)
vm_ips=("192.168.1.97" "192.168.1.98" "192.168.1.99")

echo "🎮 Starting VM creation process..."

# Create VMs
for i in "${!vm_names[@]}"; do
    create_vm "${vm_names[$i]}" "${vm_ips[$i]}"
done

create_users

echo -e "\n📋 Final VM list:"
multipass list

echo "🎉 All VMs created and configured successfully!"
