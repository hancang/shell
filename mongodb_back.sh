#/bin/bash


user_name=
password=
daytime=`date +%Y%m%d`
backup_dir='/data/mongodb_backup'
export AWS_ACCESS_KEY_ID=""
export AWS_SECRET_ACCESS_KEY=""
CLUSTER_NAME='mongodb_realtag'
date_time=`date +%Y%m%d`
date_7_day_ago=`date -d "6 day ago" +%Y%m%d`
AWS_S3_PATH="s3://a/mongodb_back/${CLUSTER_NAME}"
S3_REGION='ap-southeast-1'
S3_endpoint="http://s3.ap-southeast-1.amazonaws.com"


single_db_backup(){
# first par is db
# secondary par is collection
#
if [ "DB_${1}" != "DB_" ];then
    mkdir -p ${backup_dir}/${1}_backup/${db}_${2}_${daytime}/
    mongodump --uri=${mongodb_uri} \
        --username=${user_name} \
        --password=${password} \
        --authenticationDatabase=admin \
        --db=${1} \
        --collection=${2} \
        --readPreference=secondaryPreferred \
        --out=/data/mongodb_backup/${1}_backup/${db}_${2}_${daytime}/

        cd ${backup_dir}/${1}_backup
        if [ -d ${db}_${2}_${daytime} ];then
            tar czvf ${db}_${2}_${daytime}.tar.gz ${db}_${2}_${daytime}
            sleep 10
        fi
        if [ -f ${db}_${2}_${daytime}.tar.gz ];then
            upload_tar_files ${db}_${2}_${daytime}.tar.gz
            echo "upload sucess"
            sleep 10 
            echo "delete s3 7 days before file"
            delete_s3_tar
            sleep 10 
            rm -r -f ${db}_${2}_${daytime}.tar.gz
        else
            echo "no ${db}_${2}_${daytime}.tar.gz active"
        fi
else
    echo "no db and collection "
fi

}

full_db_backup(){
    mkdir -p ${backup_dir}/full_backup/full_${daytime}/
    mongodump --uri=${mongodb_uri} \
        --username=${user_name} \
        --password=${password} \
        --authenticationDatabase=admin \
        --numParallelCollections=12 \
        --readPreference=secondaryPreferred \
        --out=${backup_dir}/full_backup/full_${daytime}/
    cd ${backup_dir}/full_backup
    if [ -d full_${daytime} ];then
        tar czvf full_${daytime}.tar.gz full_${daytime}
    else
        echo 
    fi
    if [ -f full_${daytime}.tar.gz ];then
        sleep 10
        upload_tar_files full_${daytime}.tar.gz
        sleep 10 
        delete_s3_tar
        rm -f -r 
    else
        echo "no full_${daytime}.tar.gz"
    fi
}

get_last_oplog_timestamp(){
    echo "db.oplog.rs.find.sort({$natural : -1})"|mongo ${mongodb_uri} \
        --username=${user_name} \
        --password=${password} \
        --authenticationDatabase=admin \
}

inc_db_backup(){
    last_time_long=${1}
    last_time_inc=${2}
    mongodump --uri=${mongodb_uri} \
        --username=${user_name} \
        --password=${password} \
        --authenticationDatabase=admin \
        --query="{ts:{$gt:{$timestamp:{t:${last_time_long},i:${last_time_inc}}}}}" \
        --db="local" \
        --collection="oplog.rs" \
        --readPreference=secondaryPreferred \
        --out=/data/mongodb_backup/${1}_backup/local_oplog/
}


upload_tar_files(){
# first is tar package
# secondary is full or inc
    if [ "db_${1}" != "db_" ];then
	    aws s3 cp ${1} ${AWS_S3_PATH}/${date_time}/
    else
	    echo "no package is give"
    fi
}

delete_s3_tar(){
    aws s3 rm --recursive ${AWS_S3_PATH}/${date_7_day_ago}
}

get_s3_files_list(){
    aws s3 list ${AWS_S3_PATH}/${daytime}/${1}
}

restore_full_mongodb(){
   get_s3_files_list ${1}
   tar xzvf ${1}.tar.gz
    mongorestore  --uri=${mongodb_uri} \
        --username=${user_name} \
        --password=${password} \
        --authenticationDatabase=admin \
        --numParallelCollections=12 \
        \\ --noIndexRestore
        --numParallelCollections=10
        -numInsertionWorkersPerCollection=5
        --bypassDocumentValidation
        ./${1}
}

restore_oplog_mongodb(){
    get_s3_files_list ${1}
   tar xzvf ${1}.tar.gz
    mongorestore  --oplogReplay \
        --uri=${mongodb_uri} \
        --username=${user_name} \
        --password=${password} \
        --authenticationDatabase=admin \
        # --numParallelCollections=12 \
        # --noIndexRestore
        # --numParallelCollections=10
        # -numInsertionWorkersPerCollection=5
        # --bypassDocumentValidation
        ./${1} 
}