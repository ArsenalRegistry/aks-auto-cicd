#!/bin/bash

APP_NAME=$1
PASSWORD=$2
SERVER_IP=$3

TOKEN=$(curl -s -k "https://$SERVER_IP/api/v1/session" -H "Content-Type: application/json" -d "{
    \"username\":\"admin\",
    \"password\":\"${PASSWORD}\"
  }" |\
    sed -e 's/{"token":"//' |\
    sed -e 's/"}//')

curl -k -X POST https://${SERVER_IP}/api/v1/applications/${APP_NAME}/sync \
 -H "Authorization: Bearer ${TOKEN}" \
 -H "Content-Type: application/json"

echo "Application ${APP_NAME} synced"