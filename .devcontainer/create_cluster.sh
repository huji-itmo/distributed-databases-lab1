
export CLUSTER_FOLDER="/home/huji/yhv53"

export DATA_FOLDER="$CLUSTER_FOLDER/data"
export LOG_FILE="$CLUSTER_FOLDER/postgresql.log"

mkdir -p $DATA_FOLDER

if pg_lsclusters | grep -q "16.*main"; then
    echo "Кластер 16/main уже существует. Удаляем..."
    pg_dropcluster 16 main --stop
fi

pg_createcluster \
    -d $DATA_FOLDER \
    -l $LOG_FILE \
    --locale ru_RU.CP1251 \
    --encoding=WIN1251 \
    16 main 

bash .devcontainer/postgres_config.sh

# service postgresql start
