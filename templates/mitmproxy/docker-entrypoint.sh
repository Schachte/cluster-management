#!/bin/sh
set -e

# Generate SSL certificate if it doesn't exist
if [ ! -f /etc/nginx/ssl/nginx.key ] || [ ! -f /etc/nginx/ssl/nginx.crt ]; then
    echo "Generating SSL certificate..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/nginx.key \
        -out /etc/nginx/ssl/nginx.crt \
        -subj "/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

    # Set proper permissions
    chmod 644 /etc/nginx/ssl/nginx.crt
    chmod 600 /etc/nginx/ssl/nginx.key
fi

# Forward all arguments to original entrypoint
exec /docker-entrypoint.sh "$@"
