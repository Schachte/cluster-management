# Check if running from project root
if [ ! -d "./templates/nginx-proxy/certs" ]; then
    echo "❌ Error: Script must be run from project root directory"
    exit 1
fi

echo "🔐 Adding NGINX certificate to system keychain..."
sudo security add-trusted-cert -d -r trustRoot -k "/Library/Keychains/System.keychain" ./templates/nginx-proxy/certs/nginx.crt
echo "✅ Certificate added successfully!"
