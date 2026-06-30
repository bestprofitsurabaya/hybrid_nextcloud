#!/bin/bash

VERSIONS=("31.0.9" "32.0.0")

for version in "${VERSIONS[@]}"; do
    echo "Updating to Nextcloud $version"
    
    # Update docker-compose
    sed -i "s|image: nextcloud:[0-9]*\.[0-9]*\.[0-9]*|image: nextcloud:$version|" docker-compose.yaml
    
    # Update container
    docker-compose up -d
    
    # Wait for container to be ready
    sleep 30
    
    # Run upgrade
    docker exec nextcloud_app sudo apt update
    docker exec nextcloud_app sudo apt install sudo
    docker exec nextcloud_app sudo -u www-data php /var/www/html/occ upgrade
    docker exec nextcloud_app sudo -u www-data php /var/www/html/occ db:add-missing-indices
    docker exec nextcloud_app sudo -u www-data php /var/www/html/occ maintenance:repair
    
    echo "Completed update to $version"
    sleep 10
done

echo "All updates completed!"
