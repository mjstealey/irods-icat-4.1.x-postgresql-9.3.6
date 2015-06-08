#!/bin/bash

# run-docker-irods.sh
# Author: Michael Stealey <michael.j.stealey@gmail.com>

echo "*** RUN SCRIPT run-docker-irods.sh ***"

# Configuration Variables - User defined
CONFIG_DIRECTORY='config-files'
IRODS_CONFIG_FILE=${CONFIG_DIRECTORY}'/irods-config.yaml'
RODSUSER_CONFIG_FILE=${CONFIG_DIRECTORY}'/rodsuser-config.yaml'

# Configuration Variables - Internal
APPSTACK_PATH=${PWD}'/appstack'
APPSTACK_DATA_IMG='appstack-data'
APPSTACK_DATA='irods-data'
APPSTACK_POSTGRESQL='irods-db'
APPSTACK_IRODS='irods-icat'

echo "*** update github submodules ***"
git submodule init && git submodule update

# build data image
CHECK_DATA_IMG=`docker images | tr -s ' ' | cut -d ' ' -f 1 | grep ${APPSTACK_DATA_IMG}`
if [[ -z "${CHECK_DATA_IMG}" ]]; then
    echo "*** docker build -t ${APPSTACK_DATA_IMG} . ***"
    docker build -t ${APPSTACK_DATA_IMG} .;
else
    echo "*** IMG: ${APPSTACK_DATA_IMG} already exists ***";
fi

# build docker appstack images
echo "*** build docker irods appstack images ***"
${APPSTACK_PATH}/appstack-build.sh ${APPSTACK_PATH}

# Launch data volume as docker container irods-data
CHECK_DATA_CID=`docker ps -a | tr -s ' ' | grep ${APPSTACK_DATA} | cut -d ' ' -f 1`
if [[ -z "${CHECK_DATA_CID}" ]]; then
    echo "*** docker run ${APPSTACK_DATA_IMG} as ${APPSTACK_DATA} ***"
    docker run -d --name ${APPSTACK_DATA} -v /srv/conf:/conf -v /srv/log:/var/log -v /srv/backup:/var/backup \
        -v /srv/pgsql:/var/lib/pgsql/9.3/data \
        -v /srv/irods:/var/lib/irods -v /srv/etc_irods:/etc/irods \
        -v /srv/.secret:/root/.secret \
        -ti ${APPSTACK_DATA_IMG}
    sleep 1s
    docker exec -ti ${APPSTACK_DATA} sh -c 'cp -r /config-files/*.yaml /conf'
    sleep 1s;
else
    CHECK_DATA_CID=`docker ps | tr -s ' ' | grep ${APPSTACK_DATA} | cut -d ' ' -f 1`
    if [[ -z "${CHECK_DATA_CID}" ]]; then
        echo "*** CONTAINER: ${APPSTACK_DATA} already exists but is not running, restarting the container ***"
        docker start ${APPSTACK_DATA}
        sleep 1s
        docker exec -ti ${APPSTACK_DATA} sh -c 'cp -r /config-files/*.yaml /conf'
        sleep 1s;
    else
        echo "*** CONTAINER: ${APPSTACK_DATA} already exists as CID: ${CHECK_DATA_CID}, container is already running ***";
    fi
fi

# Setup postgreql database
CHECK_POSTGRESQL_CID=`docker ps -a | tr -s ' ' | grep ${APPSTACK_POSTGRESQL} | cut -d ' ' -f 1`
CHECK_POSTGRESQL_DIR=`docker exec -ti ${APPSTACK_DATA} ls /var/lib/pgsql/9.3/data/`
if [[ -z "${CHECK_POSTGRESQL_CID}" ]] && [[ -z "${CHECK_POSTGRESQL_DIR}" ]]; then
    echo "*** docker run postgresql-setup ***"
    docker run --rm --volumes-from ${APPSTACK_DATA} -it postgresql-setup
    sleep 3s;
else
    echo "*** SETUP: ${APPSTACK_POSTGRESQL} already exists or /var/lib/posgql/9.3/data/ has already been populated ***";
fi

# Launch postgres database as docker container irods-db
CHECK_POSTGRESQL_CID=`docker ps -a | tr -s ' ' | grep ${APPSTACK_POSTGRESQL} | cut -d ' ' -f 1`
if [[ -z "${CHECK_POSTGRESQL_CID}" ]]; then
    echo "*** docker run postgresql as ${APPSTACK_POSTGRESQL} ***"
    docker run -u postgres -d --name ${APPSTACK_POSTGRESQL} --volumes-from ${APPSTACK_DATA} postgresql
    sleep 3s;
else
    CHECK_POSTGRESQL_CID=`docker ps | tr -s ' ' | grep ${APPSTACK_POSTGRESQL} | cut -d ' ' -f 1`
    if [[ -z "${CHECK_POSTGRESQL_CID}" ]]; then
        echo "*** CONTAINER: ${APPSTACK_POSTGRESQL} already exists but is not running, restarting the container ***"
        docker start ${APPSTACK_POSTGRESQL}
        sleep 3s;
    else
        echo "*** CONTAINER: ${APPSTACK_POSTGRESQL} already exists as CID: ${CHECK_POSTGRESQL_CID}, container already running ***";
    fi
fi

# Setup irods environment
CHECK_IRODS_CID=`docker ps -a | tr -s ' ' | grep ${APPSTACK_IRODS} | cut -d ' ' -f 1`
CHECK_IRODS_DIR=`docker exec -ti ${APPSTACK_DATA} ls /var/lib/irods/`
if [[ -z "${CHECK_IRODS_CID}" ]] && [[ -z "${CHECK_IRODS_DIR}" ]]; then
    echo "*** docker run irods-icat-setup ***"
    docker run --rm --volumes-from ${APPSTACK_DATA} --link ${APPSTACK_POSTGRESQL}:${APPSTACK_POSTGRESQL} -it irods-icat-setup
    sleep 3s
else
    echo "*** SETUP: ${APPSTACK_IRODS} already exists or /var/lib/irods/ has already been populated ***";
fi

# Lauch irods environment as docker container irods-icat
CHECK_IRODS_CID=`docker ps -a | tr -s ' ' | grep ${APPSTACK_IRODS} | cut -d ' ' -f 1`
if [[ -z "${CHECK_IRODS_CID}" ]]; then
    echo "*** docker run irods-icat as ${APPSTACK_IRODS} ***"
    docker run -d --name ${APPSTACK_IRODS} --volumes-from ${APPSTACK_DATA} --link ${APPSTACK_POSTGRESQL}:${APPSTACK_POSTGRESQL} irods-icat
    sleep 10s;
else
    CHECK_IRODS_CID=`docker ps | tr -s ' ' | grep ${APPSTACK_IRODS} | cut -d ' ' -f 1`
    if [[ -z "${CHECK_IRODS_CID}" ]]; then
        echo "*** CONTAINER: ${APPSTACK_IRODS} already exists but is not running, restarting the container ***"
        docker start ${APPSTACK_IRODS}
        sleep 10s;
    else
        echo "*** CONTAINER: ${APPSTACK_IRODS} already exists as CID: ${CHECK_IRODS_CID}, container already running ***";
    fi
fi

# Check for iRODS hsproxy user and configure if it does not exist
echo "*** setup proxy user if it does not exist ***"
./configure-docker-irods.sh

echo "*** FINISHED SCRIPT run-docker-irods.sh ***"
exit;