#!/usr/bin/env bash
# Legt die beiden ECS-Services (Fargate) an. Voraussetzung: provision.sh wurde ausgeführt.
# Die Services starten mit 0 Tasks und einer Platzhalter-Task-Definition; die Pipeline
# (deploy-Job) registriert danach die echte Task-Definition und setzt desired-count auf 1.
set -euo pipefail
export AWS_PAGER=""

# shellcheck disable=SC1091
source "$(dirname "$0")/state.env"
P=refcard05
CLUSTER="${P}-cluster"

placeholder_taskdef() { # fe|be cpu mem
  aws ecs register-task-definition --family "${P}-$1" --network-mode awsvpc \
    --requires-compatibilities FARGATE --cpu "$2" --memory "$3" \
    --execution-role-arn "arn:aws:iam::${ACCOUNT}:role/LabRole" \
    --container-definitions "[{\"name\":\"${P}-$1\",\"image\":\"${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com/${P}-$1:latest\",\"essential\":true,\"portMappings\":[{\"containerPort\":$4}]}]" \
    --query 'taskDefinition.taskDefinitionArn' --output text
}

service() { # fe|be taskdef-arn tg-arn port
  if [[ "$(aws ecs describe-services --cluster "$CLUSTER" --services "${P}-$1-service" \
        --query 'services[?status==`ACTIVE`].serviceName' --output text)" == "${P}-$1-service" ]]; then
    echo "Service ${P}-$1-service existiert bereits"
    return
  fi
  aws ecs create-service --cluster "$CLUSTER" --service-name "${P}-$1-service" \
    --task-definition "$2" --desired-count 0 --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_A},${SUBNET_B}],securityGroups=[${SG_TASKS}],assignPublicIp=ENABLED}" \
    --load-balancers "targetGroupArn=$3,containerName=${P}-$1,containerPort=$4" \
    --health-check-grace-period-seconds 120 \
    --deployment-configuration "deploymentCircuitBreaker={enable=true,rollback=true},minimumHealthyPercent=100,maximumPercent=200" \
    --query 'service.serviceName' --output text
}

service be "$(placeholder_taskdef be 512 1024 8080)" "$TG_BE" 8080
service fe "$(placeholder_taskdef fe 256 512 80)" "$TG_FE" 80
