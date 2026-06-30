#!/bin/bash

cd /home/it-ef/hybrid_nextcloud

echo "Checking SSL certificate renewal..."
docker-compose run --rm certbot renew --webroot --webroot-path=/var/www/certbot

# Reload nginx untuk apply certificate baru
docker-compose exec nginx nginx -s reload

echo "SSL renewal check completed!"
