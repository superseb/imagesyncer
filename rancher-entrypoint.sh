#!/bin/bash
if [ "${RANCHER_DEBUG}" == "true" ]; then
    set -x
fi

echo "Starting"

# Create CATTLE_URL for v2-beta
CATTLE_URL_V2=`echo $CATTLE_URL | sed -e 's_/v1_/v2-beta_'`

# Get environment name
ENV_NAME=`curl -s -k 169.254.169.250/latest/self/stack/environment_name`

# Get id from environment name
ENV_ID=`curl -u $CATTLE_ACCESS_KEY:$CATTLE_SECRET_KEY -s -k $CATTLE_URL_V2/projects?name=$ENV_NAME | jq -r .data[].id`

# Check for default registry setting (private registry)
REGISTRY=`curl -s -k $CATTLE_URL_V2/settings/registry.default | jq -r .value`

while true; do
    # Find all images in services
    IMAGES=`curl -u $CATTLE_ACCESS_KEY:$CATTLE_SECRET_KEY -s -k $CATTLE_URL_V2/services?system=false\&accountId=$ENV_ID\&limit=-1  | jq -r .data[].launchConfig.imageUuid`
    
    echo -e "Found images\n${IMAGES}"
    
    # Loop through all images and pull
    for IMAGE in $IMAGES; do
        # Strip 'docker:' prefix in imageUuid
        PULLIMAGE=`echo $IMAGE | sed -e 's/^docker://'`
    
        # Check system cpu usage before proceeding
        if [ "${CHECK_CPU_USAGE}" == "true" ]; then
            while [ `top -bn2 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' | tail -1 | xargs printf "%1.f\n"` -gt $CPU_USAGE_MAX ]; do
                echo "CPU usage higher than ${CPU_USAGE_MAX}%, sleeping ${CPU_USAGE_SLEEP}s"
                sleep $CPU_USAGE_SLEEP
            done
        fi
    
        if [ -z $REGISTRY ] || [ $REGISTRY == "null" ]; then
            echo "Executing docker pull ${PULLIMAGE}"
            docker pull ${PULLIMAGE}
        else
            echo "Executing docker pull ${REGISTRY}/${PULLIMAGE}"
            docker pull ${REGISTRY}/${PULLIMAGE}
        fi 
        if [ "${RANDOM_SLEEP}" == "true" ]; then
            HOST_COUNT=`curl -s -H "Accept: application/json" 169.254.169.250/latest/hosts | jq -r '[.[] ]| length'`
            HOST_COUNT_SOURCE="$(($HOST_COUNT * 10))"
            SLEEP=$((RANDOM % $HOST_COUNT_SOURCE))
            echo "Random sleep: ${SLEEP}s"
            sleep $SLEEP
        fi
    done
    echo "Check interval: ${CHECK_INTERVAL}s"
    sleep $CHECK_INTERVAL
done
