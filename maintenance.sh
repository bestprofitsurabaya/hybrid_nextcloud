#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Konfigurasi Direktori & DuckDNS
APP_DIR="/home/it-ef/hybrid_nextcloud"
DUCKDNS_DOMAIN="nasbpfsby"
DUCKDNS_TOKEN="7b8cebbe-7ac7-4f8d-82af-b07d11cba2b6"
DUCKDNS_LOG="/var/log/duckdns.log"

cd $APP_DIR

case "$1" in
    start|stop|restart)
        ACTION=$1
        if [ "$ACTION" == "start" ]; then docker-compose up -d; fi
        if [ "$ACTION" == "stop" ]; then docker-compose down; fi
        if [ "$ACTION" == "restart" ]; then docker-compose restart; fi
        echo -e "${GREEN}? Services $ACTION completed${NC}"
        ;;
        
    status)
        echo -e "${BLUE}?? Nextcloud Status:${NC}"
        docker-compose ps
        echo -e "\n${BLUE}?? Service Health:${NC}"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep nextcloud
        ;;
        
    logs)
        if [ -z "$2" ]; then docker-compose logs --tail=50; else docker-compose logs --tail=50 "$2"; fi
        ;;
        
    backup)
        echo -e "${BLUE}?? Creating backup...${NC}"
        BACKUP_FILE="/srv/backup/nextcloud/nextcloud_$(date +%Y%m%d_%H%M%S).tar.gz"
        mkdir -p /srv/backup/nextcloud
        
        docker exec nextcloud_db mysqldump -u nextcloud -pnextcloud@bpfsby44 nextcloud > /tmp/nextcloud_db.sql
        
        tar -czf "$BACKUP_FILE" \
            -C /srv/nextcloud data \
            -C $APP_DIR docker-compose.yaml nginx letsencrypt ssl \
            -C /tmp nextcloud_db.sql 2>/dev/null
        
        rm /tmp/nextcloud_db.sql
        echo -e "${GREEN}? Backup created: $BACKUP_FILE${NC}"
        ;;
        
    sync-dns)
        echo -e "${BLUE}?? Updating DuckDNS IP...${NC}"
        echo "$(date): Updating DuckDNS IP..." >> $DUCKDNS_LOG
        curl -k "https://www.duckdns.org/update?domains=$DUCKDNS_DOMAIN&token=$DUCKDNS_TOKEN&ip=" >> $DUCKDNS_LOG 2>&1
        echo "" >> $DUCKDNS_LOG
        echo -e "${GREEN}? DuckDNS IP updated${NC}"
        ;;
        
    cert-renew)
        echo -e "${YELLOW}?? Starting SSL Renewal Process...${NC}"
        # Selalu update DNS sebelum renew SSL untuk menghindari error validasi Let's Encrypt
        $0 sync-dns 
        
        echo -e "${BLUE}?? Renewing SSL certificate...${NC}"
        docker-compose run --rm --entrypoint "" certbot certbot renew --webroot --webroot-path=/var/www/html --quiet
        
        echo -e "${BLUE}?? Reloading Nginx...${NC}"
        docker-compose exec nginx nginx -s reload
        echo -e "${GREEN}? Certificate renewal and webserver reload completed${NC}"
        ;;
        
    occ)
        shift
        echo -e "${BLUE}?? Running OCC command: $@${NC}"
        docker exec -it -u www-data nextcloud_app php /var/www/html/occ "$@"
        ;;
        
    update)
        # Jika ada versi spesifik yang dimasukkan, contoh: ./maintenance.sh update 32.0.1
        TARGET_VERSION=${2:-"latest"} 
        
        echo -e "${YELLOW}??  Updating Nextcloud...${NC}"
        
        if [ "$TARGET_VERSION" != "latest" ]; then
            echo -e "${BLUE}1. Modifying docker-compose.yaml to version $TARGET_VERSION...${NC}"
            sed -i "s|image: nextcloud:.*|image: nextcloud:$TARGET_VERSION|" docker-compose.yaml
        fi

        echo -e "${BLUE}2. Creating safety backup...${NC}"
        $0 backup
        
        echo -e "${BLUE}3. Pulling new images & restarting...${NC}"
        docker-compose pull
        docker-compose down
        docker-compose up -d
        
        echo -e "${YELLOW}? Waiting 30 seconds for database & services to initialize...${NC}"
        sleep 30
        
        echo -e "${BLUE}4. Executing Nextcloud internal upgrades...${NC}"
        docker exec -u www-data nextcloud_app php /var/www/html/occ upgrade
        docker exec -u www-data nextcloud_app php /var/www/html/occ db:add-missing-indices
        docker exec -u www-data nextcloud_app php /var/www/html/occ maintenance:repair
        
        # Keluar dari maintenance mode jika tersangkut
        docker exec -u www-data nextcloud_app php /var/www/html/occ maintenance:mode --off
        
        echo -e "${GREEN}? Update to $TARGET_VERSION completed perfectly!${NC}"
        ;;
        
    *)
        echo "Usage: $0 {start|stop|restart|status|logs [service]|backup|sync-dns|cert-renew|occ <command>|update [version]}"
        echo ""
        echo "Examples:"
        echo "  $0 backup             - Create database & config backup"
        echo "  $0 sync-dns           - Update DuckDNS IP only"
        echo "  $0 cert-renew         - Update DuckDNS IP, Renew SSL, and reload Nginx"
        echo "  $0 update             - Pull latest images and run all OCC upgrade tasks"
        echo "  $0 update 32.0.1      - Change version in docker-compose and upgrade"
        ;;
esac