#!/bin/bash

# Create directories if they don't exist
mkdir -p certs

# Generate Root CA configuration
cat >certs/ca.conf <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = Development CA
CN = Development Root CA

[v3_ca]
basicConstraints = critical, CA:TRUE
keyUsage = critical, digitalSignature, keyEncipherment, keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF

# Generate Server certificate configuration
cat >certs/server.conf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = Development
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

# 1. Generate Root CA private key
openssl genrsa -out certs/ca.key 4096

# 2. Generate Root CA certificate
openssl req -x509 -new -nodes \
    -key certs/ca.key \
    -sha256 -days 3650 \
    -out certs/ca.crt \
    -config certs/ca.conf \
    -extensions v3_ca

# 3. Generate server private key
openssl genrsa -out certs/nginx.key 2048

# 4. Generate server Certificate Signing Request (CSR)
openssl req -new \
    -key certs/nginx.key \
    -out certs/nginx.csr \
    -config certs/server.conf

# 5. Generate server certificate signed by our CA
openssl x509 -req \
    -in certs/nginx.csr \
    -CA certs/ca.crt \
    -CAkey certs/ca.key \
    -CAcreateserial \
    -out certs/nginx.crt \
    -days 365 \
    -sha256 \
    -extfile certs/server.conf \
    -extensions v3_req

# Set proper permissions
chmod 644 certs/ca.crt certs/nginx.crt
chmod 600 certs/ca.key certs/nginx.key

# Verify the certificates
echo -e "\nVerifying root CA certificate:"
openssl x509 -in certs/ca.crt -text -noout | grep "Subject\|CA"

echo -e "\nVerifying server certificate:"
openssl x509 -in certs/nginx.crt -text -noout | grep "Subject\|DNS\|IP"

# Create installation page
cat >certs/install.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Install Certificates</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
</head>
<body>
    <h1>Install Development Certificates</h1>
    <p><strong>1. First install the Root CA:</strong><br>
    <a href="ca.crt" download>Download Root CA Certificate</a></p>
    <p><strong>2. Then install the server certificate:</strong><br>
    <a href="nginx.crt" download>Download Server Certificate</a></p>
</body>
</html>
EOF

# Add to system keychain (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "\nAdding certificates to system keychain..."
    sudo security add-trusted-cert -d -r trustRoot -k "/Library/Keychains/System.keychain" certs/ca.crt
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
echo -e "To serve the installation page: cd certs && python3 -m http.server 8000"
