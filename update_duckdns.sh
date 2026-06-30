#!/bin/bash

DOMAIN="nasbpfsby"
TOKEN="7b8cebbe-7ac7-4f8d-82af-b07d11cba2b6"
LOG_FILE="/var/log/duckdns.log"

echo "$(date): Updating DuckDNS IP..." >> $LOG_FILE

# Update DuckDNS
curl -k "https://www.duckdns.org/update?domains=$DOMAIN&token=$TOKEN&ip=" >> $LOG_FILE 2>&1

echo "" >> $LOG_FILE
