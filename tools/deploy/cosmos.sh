# cosmos
echo creating cosmos account, db, collection, diagsettings

cosmos_group_name=$DEFAULT_GROUP_NAME
cosmos_account_name=$COSMOS_ACCOUNT_NAME
cosmos_account_kind=GlobalDocumentDB
cosmos_account_consistency=BoundedStaleness
cosmos_account_consistency_maxinterval=10
cosmos_db_name=$COSMOS_DB_NAME
cosmos_collection_name=$COSMOS_COLLECTION_NAME

cosmos_diagsettings_name=cosmos-diagsettings

## account
cosmos_account_id=$(az cosmosdb show \
    --name $cosmos_account_name \
    --resource-group $cosmos_group_name \
    --query id --output tsv \
    2> /dev/null \
    )

if [ -z "$cosmos_account_id" ]; then
    cosmos_account_id=$(az cosmosdb create \
        --name $cosmos_account_name \
        --resource-group $cosmos_group_name \
        --kind $cosmos_account_kind \
        --default-consistency-level $cosmos_account_consistency \
        --max-interval $cosmos_account_consistency_maxinterval \
        --query id --output tsv \
        )
    echo created: $cosmos_account_id
else
    echo found: $cosmos_account_id
fi

cosmos_account_key=$(az cosmosdb list-keys \
        --name $cosmos_account_name \
        --resource-group $cosmos_group_name \
        --query primaryMasterKey --output tsv \
        )

## db
cosmos_db_exists=$(az cosmosdb database exists \
    --db-name $cosmos_db_name \
    --name $cosmos_account_name \
    --resource-group-name $cosmos_group_name \
    --key $cosmos_account_key \
    --output tsv \
    2> /dev/null \
    )

if [ "x$cosmos_db_exists" == "xfalse" ]; then
    cosmos_db_id=$(az cosmosdb database create \
        --db-name $cosmos_db_name \
        --name $cosmos_account_name \
        --resource-group-name $cosmos_group_name \
        --key $cosmos_account_key \
        --query id --output tsv \
        )
    echo created: $cosmos_db_id
else
    cosmos_db_id=$(az cosmosdb database show \
        --db-name $cosmos_db_name \
        --name $cosmos_account_name \
        --resource-group-name $cosmos_group_name \
        --key $cosmos_account_key \
        --query id --output tsv \
        )
    echo found: $cosmos_db_id
fi

## collection
cosmos_collection_exists=$(az cosmosdb collection exists \
    --collection-name $cosmos_collection_name \
    --db-name $cosmos_db_name \
    --name $cosmos_account_name \
    --resource-group-name $cosmos_group_name \
    --key $cosmos_account_key \
    --output tsv \
    2> /dev/null \
    )

if [ "x$cosmos_collection_exists" == "xfalse" ]; then
    cosmos_collection_id=$(az cosmosdb collection create \
        --collection-name $cosmos_collection_name \
        --db-name $cosmos_db_name \
        --name $cosmos_account_name \
        --resource-group-name $cosmos_group_name \
        --key $cosmos_account_key \
        --query 'collection.id' --output tsv \
        )
    echo created: $cosmos_collection_id
else
    cosmos_collection_id=$(az cosmosdb collection show \
        --collection-name $cosmos_collection_name \
        --db-name $cosmos_db_name \
        --name $cosmos_account_name \
        --resource-group-name $cosmos_group_name \
        --key $cosmos_account_key \
        --query 'collection.id' --output tsv \
        )
    echo found: $cosmos_collection_id
fi
    
## diagsettings
cosmos_logs_json=$(cat "$ROOT_DIR/specs/cosmosdb.logs")
cosmos_metrics_json=$(cat "$ROOT_DIR/specs/cosmosdb.metrics")

resource_uri=$cosmos_account_id
settings_name=$cosmos_diagsettings_name
logs_json=$cosmos_logs_json
metrics_json=$cosmos_metrics_json
az monitor diagnostic-settings create \
    --resource $resource_uri \
    --name $settings_name \
    --event-hub $MONITOR_HUB_NAME \
    --event-hub-rule $MONITOR_SASPOLICY_ID \
    --logs "$logs_json" \
    --metrics "$metrics_json" \
    --query id --output tsv

