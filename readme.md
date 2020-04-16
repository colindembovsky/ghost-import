# Convert from Colin's ALM Corner MiniBlog to Ghost
Repo for converting posts from MiniBlog to Ghost

## Creating Docker Image
```
# dev
docker build . --build-arg issoUrl=http://192.168.1.13:3002 -t cacregistry.azurecr.io/ghost:dev

# prod image
docker build . --build-arg issoUrl=http://cacisso.azurewebsites.net --build-arg mode=production -t cacregistry.azurecr.io/ghost:prod

# running in dev
az storage account keys list -g $rg -n $saName --query [0].value -o tsv
$azkey="<az storage key>"

docker run -d --name ghost -e url=http://192.168.1.13:3001 -e AZURE_STORAGE_CONNECTION_STRING=$azkey -p 3001:2368 cacregistry.azurecr.io/ghost:dev
```

## Upload image files
```
$key="<az storage key>"
az storage blob upload-batch --connection-string $key -d ghostcontent --destination-path images/files -s ../files/
```

## Import posts
```
# download posts from old storage account to folder 'exported'
yarn install
yarn go
```

This creates `import.json`. Navigate to ghost/labs page and import this file.

## Infrastructure
1. Resource Group
1. Storage account
    - create container `ghostcontent`
    - create folder `images`
    - update images folder to public (read) access
1. Create CDN (MSFT standard) for storage account
1. Update CDN URL in the `index.ts` file (near bottom) to account for URL updates for images