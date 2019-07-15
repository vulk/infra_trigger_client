#!/bin/bash

#Trigger K8s Pipeline
K8S_PIPELINE_ID=$(curl --request POST \
                         --form token="$K8S_TRIGGER_TOKEN" \
                         --form ref="$K8S_REF" \
                         "$BASE_URL"/api/v4/projects/14/trigger/pipeline | jq '.id')

#Trigger Infra Provisioning Pipeline
INFRA_PIPELINE_ID=$(curl --request POST \
                         --form token="$INFRA_TRIGGER_TOKEN" \
                         --form ref="$INFRA_REF" \
                         "$BASE_URL"/api/v4/projects/63/trigger/pipeline | jq '.id')

while [ "$PIPELINE_STATUS" != "success" ]; do
    K8S_PIPELINE_STATUS=$(curl --header "PRIVATE-TOKEN: $TOKEN" "$BASE_URL/api/v4/projects/14/pipelines/$K8S_PIPELINE_ID" | jq -r '.status')
    INFRA_PIPELINE_STATUS=$(curl --header "PRIVATE-TOKEN: $TOKEN" "$BASE_URL/api/v4/projects/63/pipelines/$INFRA_PIPELINE_ID" | jq -r '.status')
    echo "K8s pipeline_status: $K8S_PIPELINE_STATUS"
    echo "Infra pipeline_status: $INFRA_PIPELINE_STATUS"
    sleep 2

    if [ "$K8S_PIPELINE_STATUS" = "success" ] && [ "$INFRA_PIPELINE_STATUS" = "success" ]; then
        break
    fi
done

#Trigger Kubespray Pipeline
KUBESPRAY_PIPELINE_ID=$(curl --request POST \
                       --form token="$KUBESPRAY_TRIGGER_TOKEN" \
                       --form ref="$KUBESPRAY_REF" \
                       --form "variables[INFRA_PIPELINE_ID]=$INFRA_PIPELINE_ID" \
                       --form "variables[K8S_PIPELINE_ID]=$K8S_PIPELINE_ID" \
                       "$BASE_URL"/api/v4/projects/65/trigger/pipeline | jq '.id')

while [ "$KUBESPRAY_PIPELINE_STATUS" != "success" ]; do
    KUBESPRAY_PIPELINE_STATUS=$(curl --header "PRIVATE-TOKEN: $TOKEN" "$BASE_URL/api/v4/projects/65/pipelines/$KUBESPRAY_PIPELINE_ID" | jq -r '.status')
    echo "Kubespray pipeline_status: $KUBESPRAY_PIPELINE_STATUS"
    sleep 2
done


