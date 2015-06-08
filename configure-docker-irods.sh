#!/bin/bash

# configure-docker-irods.sh
# Author: Michael Stealey <michael.j.stealey@gmail.com>

CONFIG_DIRECTORY='config-files'
IRODS_CONFIG_FILE=${CONFIG_DIRECTORY}'/irods-config.yaml'
RODSUSER_CONFIG_FILE=${CONFIG_DIRECTORY}'/hs-irods-user-config.yaml'

# read hs-irods-user-config.yaml into environment
sed -e "s/:[^:\/\/]/=/g;s/$//g;s/ *=/=/g" $RODSUSER_CONFIG_FILE > $CONFIG_DIRECTORY/hs-irods-user.config.sh
while read line; do export $line; done < <(cat $CONFIG_DIRECTORY/hs-irods-user.config.sh)
# read irods-config.yaml into environment
sed -e "s/:[^:\/\/]/=/g;s/$//g;s/ *=/=/g" $IRODS_CONFIG_FILE > $CONFIG_DIRECTORY/irods-config.sh
while read line; do export $line; done < <(cat $CONFIG_DIRECTORY/irods-config.sh)

# check zone name
CHECK_IRODS_ZONE=`docker exec -ti hs-irods-icat sudo -u ${SERVICE_ACCT_USERNAME} iadmin lz`
if [[ "${CHECK_IRODS_ZONE%?}" != "${HYDORSHARE_IRODS_ZONE}" ]]; then
    echo "*** Found Zone: ${HYDORSHARE_IRODS_ZONE} ***"
    echo "*** Please change the file: irods-config.yml and rerun script "
    echo "  IRODS_ZONE: ${HYDORSHARE_IRODS_ZONE}"
    echo "";
else
    echo "*** Found Zone: ${HYDORSHARE_IRODS_ZONE} ***";
fi

# check resource name
CHECK_IRODS_RESOURCE=$(docker exec -ti hs-irods-icat sudo -u ${SERVICE_ACCT_USERNAME} iadmin lr | grep ${HYDROSHARE_IRODS_RESOURCE})
if [[ -z "${CHECK_IRODS_RESOURCE%?}" ]]; then
    echo "*** Create Resource: ${RODSUSER_IRODS_RESOURCE} ***"
    docker exec -ti hs-irods-icat sudo -u ${SERVICE_ACCT_USERNAME} iadmin mkresc ${RODSUSER_IRODS_RESOURCE} 'unixfilesystem' localhost:${VAULT_DIRECTORY}
    # start iRODS server as user irods
    docker exec -ti hs-irods-icat sudo -u ${SERVICE_ACCT_USERNAME} sed -i 's/"irods_host".*/"irods_host": "localhost",/g' /var/lib/irods/.irods/irods_environment.json
    docker exec -ti hs-irods-icat sudo -u ${SERVICE_ACCT_USERNAME} sed -i 's/"default_resource_name".*/"default_resource_name": "'${RODSUSER_IRODS_RESOURCE}'",/g' /etc/irods/server_config.json
    for line in `docker exec -ti hs-irods-icat sudo -u irods ilsresc`; do
        echo "*** iadmin modresc ${line%?} host HOSTNAME ***"
        docker exec -ti hs-irods-icat sudo -u ${SERVICE_ACCT_USERNAME} iadmin modresc ${line%?} host localhost;
    done
    docker exec -ti hs-irods-icat sudo -u ${SERVICE_ACCT_USERNAME} /var/lib/irods/iRODS/irodsctl restart
else
    echo "*** Found Resource: ${RODSUSER_IRODS_RESOURCE} ***";
fi

# check user name
CHECK_IRODS_USER=$(docker exec -ti hs-irods-icat sudo -u ${SERVICE_ACCT_USERNAME} iadmin lu | grep ${RODSUSER_IRODS_USERNAME})
if [[ -z "${CHECK_IRODS_USER%?}" ]]; then
    echo "*** Create User: ${RODSUSER_IRODS_USERNAME} ***"
    docker exec -ti hs-irods-icat sudo -u ${SERVICE_ACCT_USERNAME} iadmin mkuser ${RODSUSER_IRODS_USERNAME} rodsuser
    docker exec -ti hs-irods-icat sudo -u ${SERVICE_ACCT_USERNAME} iadmin moduser ${RODSUSER_IRODS_USERNAME} password ${RODSUSER_IRODS_AUTH};
else
    echo "*** Found User: ${RODSUSER_IRODS_USERNAME} ***";
fi
exit;