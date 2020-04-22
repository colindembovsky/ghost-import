#!/bin/bash

# for testing in fish console
# set -x RG "cac-ghost"
# set -x SKU "B2"
# set -x REGION "westus2"
# set -x PLAN_NAME "cacghostplan"
# set -x GHOST_WEBAPP_NAME "cacghost"
# set -x ISSO_WEBAPP_NAME "cacisso"
# set -x ACR_NAME "cacregistry"
# set -x GHOST_CDN "blog.colinsalmcorner.com"
# set -x GHOST_WWW "0"
# set -x ISSO_CDN "comments.colinsalmcorner.com"
# set -x ISSO_WWW "0"
# set -x MYSQL_SERVER_NAME "cacmysql"
# set -x MYSQL_ADMIN "admin_cac"
# set -x MYSQL_SKU "B_Gen5_1"
# set -x EMAIL "colin@home.com"
# set -x STAGING "1"
# set -x MYSQL_PASS "SomeL0ngP@ssw0rd"

echo "Creating resource group $RG in REGION $REGION"
az group create -n $RG -l $REGION

echo "Create container registry"
az acr create -g $RG -n $ACR_NAME --sku Basic --admin-enabled true

echo "Creating MYSQL server $MYSQL_SERVER_NAME"
az mysql server create -g $RG -n $MYSQL_SERVER_NAME \
    --admin-user $MYSQL_ADMIN \
    --admin-password $MYSQL_PASS --sku-name $MYSQL_SKU \
    --ssl-enforcement Disabled \
    --location $REGION

echo "Configure firewall for Azure services"
az mysql server firewall-rule create --resource-group $RG --server $MYSQL_SERVER_NAME \
        --name AllowAzureIP \
        --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0

echo "Creating ghost Database"
az mysql db create -g $RG -s $MYSQL_SERVER_NAME -n ghost

echo "Creating comments Database"
az mysql db create -g $RG -s $MYSQL_SERVER_NAME -n comments

echo "Creating app service plan $PLAN_NAME with sku $SKU"
az appservice plan create -g $RG -n $PLAN_NAME --sku $SKU --is-linux

echo "Creating webapp $GHOST_WEBAPP_NAME with nginx image"
acrPassword=$(az acr credential show -g $RG -n $ACR_NAME --query "[passwords[?name=='password'].value]" --output tsv)
az webapp create -g $RG -n $GHOST_WEBAPP_NAME -p $PLAN_NAME \
    --multicontainer-config-type "compose" \
    --multicontainer-config-file "../ghost/ghost-nginx.yml"

echo "Setting registry for $GHOST_WEBAPP_NAME"
az webapp config container set -g $RG -n $GHOST_WEBAPP_NAME \
    --docker-registry-server-url "https://$ACR_NAME.azurecr.io" \
    --docker-registry-server-user $ACR_NAME \
    --docker-registry-server-password $acrPassword \
    --multicontainer-config-type "compose" \
    --multicontainer-config-file "../ghost/ghost-nginx.yml"

echo "Enabling docker container logging"
az webapp log config -g $RG -n $GHOST_WEBAPP_NAME \
    --application-logging true \
    --detailed-error-messages true \
    --web-server-logging filesystem \
    --docker-container-logging filesystem \
    --level verbose

echo "Set custom DNS $GHOST_CDN for $GHOST_WEBAPP_NAME"
az webapp config hostname add --webapp-name $GHOST_WEBAPP_NAME -g $RG --hostname $GHOST_CDN

echo "Setting ghost and nginx env settings"
az webapp config appsettings set -g $RG -n $GHOST_WEBAPP_NAME --settings \
    url=https://$GHOST_CDN \
    CDN=$GHOST_CDN \
    WWW=$GHOST_WWW \
    EMAIL=$EMAIL \
    STAGING=$STAGING \
    AZ_CLIENT_ID=$AZ_CLIENT_ID \
    AZ_CLIENT_KEY=$AZ_CLIENT_KEY \
    AZ_TENANT_ID=$AZ_TENANT_ID \
    PFX_PASSWORD=$PFX_PASSWORD \
    WEB_APP_NAME=$GHOST_WEBAPP_NAME \
    RESOURCE_GROUP=$RG \
    database__client=mysql \
    database__connection__database=ghost \
    database__connection__host=$MYSQL_SERVER_NAME.mysql.database.azure.com \
    database__connection__user=$MYSQL_ADMIN@$MYSQL_SERVER_NAME \
    database__connection__password=$MYSQL_PASS \
    WEBSITES_ENABLE_APP_SERVICE_STORAGE=true

echo "Hit $GHOST_CDN to start site"
curl https://$GHOST_CDN

echo "Creating webapp $ISSO_WEBAPP_NAME"
az webapp create -g $RG -n $ISSO_WEBAPP_NAME -p $PLAN_NAME \
    --multicontainer-config-type "compose" \
    --multicontainer-config-file "../isso/isso-nginx.yml"

echo "Setting registry for $ISSO_WEBAPP_NAME"
az webapp config container set -g $RG -n $ISSO_WEBAPP_NAME \
    --docker-registry-server-url "https://$ACR_NAME.azurecr.io" \
    --docker-registry-server-user $ACR_NAME \
    --docker-registry-server-password $acrPassword \
    --multicontainer-config-type "compose" \
    --multicontainer-config-file "../isso/isso-nginx.yml"

echo "Enabling docker container logging"
az webapp log config -g $RG -n $ISSO_WEBAPP_NAME \
    --application-logging true \
    --detailed-error-messages true \
    --web-server-logging filesystem \
    --docker-container-logging filesystem \
    --level information

echo "Setting isso and nginx env settings"
az webapp config appsettings set -g $RG -n $ISSO_WEBAPP_NAME --settings \
    CDN=$ISSO_CDN \
    WWW=$ISSO_WWW \
    EMAIL=$EMAIL \
    STAGING=$STAGING \
    AZ_CLIENT_ID=$AZ_CLIENT_ID \
    AZ_CLIENT_KEY=$AZ_CLIENT_KEY \
    AZ_TENANT_ID=$AZ_TENANT_ID \
    PFX_PASSWORD=$PFX_PASSWORD \
    WEB_APP_NAME=$ISSO_WEBAPP_NAME \
    RESOURCE_GROUP=$RG \
    MYSQL_HOST=$MYSQL_SERVER_NAME.mysql.database.azure.com \
    MYSQL_DB=comments \
    MYSQL_USERNAME=$MYSQL_ADMIN@$MYSQL_SERVER_NAME \
    MYSQL_PASSWORD=$MYSQL_PASS \
    WEBSITES_ENABLE_APP_SERVICE_STORAGE=true

echo "Hit $ISSO_CDN to start site"
curl https://$ISSO_CDN/js/embed.min.js