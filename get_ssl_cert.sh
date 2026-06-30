#!/bin/bash

# Stop services
cd /home/it-ef/hybrid_nextcloud
docker-compose down

# Start only nginx untuk verifikasi
docker-compose up -d nginx
sleep 10

# Dapatkan SSL certificate
echo "Getting SSL certificate for nasbpfsby.duckdns.org..."
docker-compose run --rm certbot certonly --webroot \
  --webroot-path=/var/www/certbot \
  --email bestprofitsurabaya@gmail.com \
  --agree-tos \
  --no-eff-email \
  --force-renewal \
  -d nasbpfsby.duckdns.org

# Stop nginx
docker-compose down

# Start semua services
docker-compose up -d

echo "SSL certificate obtained successfully!"
