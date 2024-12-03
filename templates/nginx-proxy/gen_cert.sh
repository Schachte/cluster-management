#!/bin/bash

# Create directories if they don't exist
mkdir -p certs

# Generate OpenSSL config file
cat >certs/cert.conf <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = Organization
CN = dev.local

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = node1.dev
DNS.2 = node2.dev
DNS.3 = node3.dev
DNS.4 = *.node1.dev
DNS.5 = *.node2.dev
DNS.6 = *.node3.dev
DNS.7 = localhost
IP.1 = 127.0.0.1
EOF

# Generate self-signed certificate
openssl req -x509 \
    -nodes \
    -days 365 \
    -newkey rsa:2048 \
    -keyout certs/nginx.key \
    -out certs/nginx.crt \
    -config certs/cert.conf \
    -extensions v3_req

# Set proper permissions
chmod 644 certs/nginx.crt
chmod 600 certs/nginx.key

# Verify the certificate
echo -e "\nVerifying certificate:"
openssl x509 -in certs/nginx.crt -text -noout | grep "Subject\|DNS\|IP"

# Add to system keychain (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "\nAdding certificate to system keychain..."
    sudo security add-trusted-cert -d -r trustRoot -k "/Library/Keychains/System.keychain" certs/nginx.crt
fi

# Add hosts entries (requires sudo)
echo -e "\nWould you like to add entries to /etc/hosts? (y/n)"
read -r add_hosts

if [[ $add_hosts == "y" ]]; then
    echo -e "\nAdding hosts entries..."
    sudo bash -c 'cat >> /etc/hosts << EOL

# Development nodes
127.0.0.1 node1.dev
127.0.0.1 node2.dev
127.0.0.1 node3.dev
EOL'
    echo "Hosts entries added!"
fi

echo -e "\nCertificate generation complete!"
