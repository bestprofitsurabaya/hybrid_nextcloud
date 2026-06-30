#!/bin/bash

# Configuration
DOMAIN="nasbpfsby.duckdns.org"
EMAIL="bestprofitsurabaya@gmail.com"
DUCK_DNS_TOKEN="7b8cebbe-7ac7-4f8d-82af-b07d11cba2b6"

echo "?? Setting up Let's Encrypt for $DOMAIN"

# 1. Update DuckDNS IP
echo "?? Updating DuckDNS IP..."
curl -k "https://www.duckdns.org/update?domains=$DOMAIN&token=$DUCK_DNS_TOKEN&ip="

# 2. Setup SSL directory dengan permission yang benar
echo "?? Setting up SSL directory..."
sudo mkdir -p /home/it-ef/hybrid_nextcloud/ssl
sudo chown -R it-ef:it-ef /home/it-ef/hybrid_nextcloud/ssl
chmod 755 /home/it-ef/hybrid_nextcloud/ssl

# 3. Generate self-signed certificate sebagai fallback
echo "?? Generating self-signed fallback certificate..."
cd /home/it-ef/hybrid_nextcloud/ssl

# Hapus file lama jika ada
rm -f selfsigned.key selfsigned.crt

# Generate certificate baru
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout selfsigned.key \
    -out selfsigned.crt \
    -subj "/C=ID/ST=Indonesia/L=Jakarta/O=Company/CN=$DOMAIN" \
    -addext "subjectAltName = DNS:$DOMAIN, DNS:localhost, IP:192.168.2.26, IP:172.60.199.23"

# Set permission yang benar
chmod 600 selfsigned.key
chmod 644 selfsigned.crt

echo "? Self-signed certificate generated"

# 4. Start services
echo "?? Starting services..."
cd /home/it-ef/hybrid_nextcloud
docker-compose down
docker-compose up -d

# 5. Tunggu services siap
echo "? Waiting for services to be ready..."
sleep 30

# 6. Test koneksi ke container
echo "?? Testing container connectivity..."
docker exec nextcloud_nginx nginx -t

# 7. Dapatkan Let's Encrypt certificate
echo "?? Obtaining Let's Encrypt certificate..."
docker-compose exec -T certbot certbot certonly --webroot \
    -w /var/www/html \
    -d $DOMAIN \
    --email $EMAIL \
    --agree-tos \
    --non-interactive \
    --no-eff-email \
    --force-renewal

# 8. Reload nginx untuk menggunakan certificate baru
echo "?? Reloading nginx..."
docker-compose exec nginx nginx -s reload

# 9. Setup auto-renewal di cron
echo "? Setting up auto-renewal cron job..."
sudo tee /etc/cron.d/nextcloud-cert-renew << EOF
# Renew Let's Encrypt certificates every Monday at 2:30 AM
30 2 * * 1 root cd /home/it-ef/hybrid_nextcloud && docker-compose exec certbot certbot renew --quiet --post-hook "docker-compose exec nginx nginx -s reload" >> /var/log/nextcloud-cert-renew.log 2>&1
EOF

echo "? Setup completed!"
echo "?? Your Nextcloud is available at: https://$DOMAIN"