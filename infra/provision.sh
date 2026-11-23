#!/usr/bin/env bash
# Legt die AWS-Infrastruktur für RefCard05 an (AWS Academy Learner Lab, us-east-1).
# Voraussetzung: gültige Lab-Credentials (~/.aws/credentials). Das Skript ist wiederholbar:
# vorhandene Ressourcen werden erkannt und nicht doppelt angelegt.
#
# Ressourcen: 2x ECR, Security Groups, Secrets-Manager-Secret (DB-Passwort), RDS MariaDB,
# S3-Bucket (+ Least-Privilege-Bucket-Policy), CloudWatch-Log-Groups, ECS-Cluster,
# 2x ALB mit Target Groups.
# ECS-Services/Task-Definitions folgen nach dem ersten Image-Push (siehe infra/services.sh).
set -euo pipefail
export AWS_PAGER=""

REGION=${AWS_REGION:-us-east-1}
P=refcard05
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
LAB_ROLE_ARN="arn:aws:iam::${ACCOUNT}:role/LabRole"
BUCKET="${P}-images-${ACCOUNT}"
STATE_FILE="$(dirname "$0")/state.env"

say() { printf '\n== %s\n' "$*"; }

VPC=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
# Zwei Subnetze in verschiedenen AZs (ALB braucht mindestens zwei)
read -r SUBNET_A SUBNET_B < <(aws ec2 describe-subnets \
  --filters Name=vpc-id,Values="$VPC" Name=default-for-az,Values=true \
  --query 'sort_by(Subnets,&AvailabilityZone)[:2].SubnetId' --output text)

say "ECR-Repositories"
for r in "${P}-fe" "${P}-be"; do
  aws ecr describe-repositories --repository-names "$r" >/dev/null 2>&1 ||
    aws ecr create-repository --repository-name "$r" \
      --image-scanning-configuration scanOnPush=true --query 'repository.repositoryUri' --output text
done

say "Security Groups"
sg() { # name description -> id
  local id
  id=$(aws ec2 describe-security-groups --filters Name=group-name,Values="$1" Name=vpc-id,Values="$VPC" \
    --query 'SecurityGroups[0].GroupId' --output text)
  if [[ "$id" == "None" ]]; then
    id=$(aws ec2 create-security-group --group-name "$1" --description "$2" --vpc-id "$VPC" \
      --query GroupId --output text)
  fi
  echo "$id"
}
allow() { # sg port source(cidr|sg)
  local src_arg
  if [[ "$3" == sg-* ]]; then src_arg=(--source-group "$3"); else src_arg=(--cidr "$3"); fi
  local out
  if ! out=$(aws ec2 authorize-security-group-ingress --group-id "$1" --protocol tcp --port "$2" "${src_arg[@]}" 2>&1); then
    [[ "$out" == *InvalidPermission.Duplicate* ]] || { echo "$out" >&2; return 1; }   # Duplikat ist ok
  fi
}
SG_ALB=$(sg "${P}-alb" "RefCard05 ALB (HTTP von aussen)")
SG_TASKS=$(sg "${P}-tasks" "RefCard05 ECS-Tasks (nur vom ALB)")
SG_RDS=$(sg "${P}-rds" "RefCard05 RDS (nur von den Backend-Tasks)")
allow "$SG_ALB" 80 0.0.0.0/0
allow "$SG_TASKS" 80 "$SG_ALB"
allow "$SG_TASKS" 8080 "$SG_ALB"
allow "$SG_RDS" 3306 "$SG_TASKS"

say "DB-Passwort in Secrets Manager (nie im Code)"
SECRET_NAME="${P}/db-password"
if ! aws secretsmanager describe-secret --secret-id "$SECRET_NAME" >/dev/null 2>&1; then
  aws secretsmanager create-secret --name "$SECRET_NAME" \
    --secret-string "$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 28)" \
    --query ARN --output text
fi
SECRET_ARN=$(aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --query ARN --output text)

say "RDS MariaDB (Start dauert einige Minuten)"
if ! aws rds describe-db-instances --db-instance-identifier "${P}-db" >/dev/null 2>&1; then
  aws rds create-db-instance \
    --db-instance-identifier "${P}-db" \
    --engine mariadb --engine-version 11.8.9 \
    --db-instance-class db.t3.micro --allocated-storage 20 \
    --db-name db_biztrips \
    --master-username admin \
    --master-user-password "$(aws secretsmanager get-secret-value --secret-id "$SECRET_NAME" --query SecretString --output text)" \
    --vpc-security-group-ids "$SG_RDS" \
    --no-publicly-accessible --backup-retention-period 0 --no-multi-az \
    --query 'DBInstance.DBInstanceStatus' --output text
fi

say "S3-Bucket (privat, verschlüsselt, Least-Privilege-Policy)"
if ! aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" >/dev/null
fi
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-encryption --bucket "$BUCKET" --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
# LabRole ist die einzige Rolle, die ECS-Tasks im Learner Lab nutzen dürfen (iam:CreateRole ist gesperrt).
# Eine eigene Rolle ist daher nicht möglich. Die Einschränkung erfolgt stattdessen resource-seitig:
# 1) Allow: nur Get/Put/Delete auf Objekten und List auf diesen Bucket
# 2) Deny: jede andere S3-Aktion für LabRole auf diesem Bucket
# 3) Deny: unverschlüsselter Transport
aws s3api put-bucket-policy --bucket "$BUCKET" --policy "$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    { "Sid": "BackendObjectsOnly", "Effect": "Allow",
      "Principal": { "AWS": "${LAB_ROLE_ARN}" },
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::${BUCKET}/*" },
    { "Sid": "BackendList", "Effect": "Allow",
      "Principal": { "AWS": "${LAB_ROLE_ARN}" },
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::${BUCKET}" },
    { "Sid": "DenyEverythingElseForLabRole", "Effect": "Deny",
      "Principal": { "AWS": "${LAB_ROLE_ARN}" },
      "NotAction": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"],
      "Resource": ["arn:aws:s3:::${BUCKET}", "arn:aws:s3:::${BUCKET}/*"] },
    { "Sid": "DenyInsecureTransport", "Effect": "Deny",
      "Principal": "*", "Action": "s3:*",
      "Resource": ["arn:aws:s3:::${BUCKET}", "arn:aws:s3:::${BUCKET}/*"],
      "Condition": { "Bool": { "aws:SecureTransport": "false" } } }
  ]
}
EOF
)"

say "CloudWatch Log Groups"
for g in "/ecs/${P}-fe" "/ecs/${P}-be"; do
  aws logs create-log-group --log-group-name "$g" 2>/dev/null || true
  aws logs put-retention-policy --log-group-name "$g" --retention-in-days 14
done

say "ECS-Cluster"
aws ecs describe-clusters --clusters "${P}-cluster" --query 'clusters[?status==`ACTIVE`].clusterName' --output text |
  grep -q . || aws ecs create-cluster --cluster-name "${P}-cluster" --query 'cluster.clusterName' --output text

say "Load Balancer + Target Groups"
lb() { # name health_path port -> prints "tg_arn dns"
  local name=$1 path=$2 port=$3 lb_arn tg_arn
  lb_arn=$(aws elbv2 describe-load-balancers --names "$name" --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || true)
  if [[ -z "$lb_arn" || "$lb_arn" == "None" ]]; then
    lb_arn=$(aws elbv2 create-load-balancer --name "$name" --subnets "$SUBNET_A" "$SUBNET_B" \
      --security-groups "$SG_ALB" --query 'LoadBalancers[0].LoadBalancerArn' --output text)
  fi
  tg_arn=$(aws elbv2 describe-target-groups --names "${name}-tg" --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || true)
  if [[ -z "$tg_arn" || "$tg_arn" == "None" ]]; then
    tg_arn=$(aws elbv2 create-target-group --name "${name}-tg" --protocol HTTP --port "$port" \
      --vpc-id "$VPC" --target-type ip --health-check-path "$path" \
      --health-check-interval-seconds 15 --healthy-threshold-count 2 --unhealthy-threshold-count 3 \
      --query 'TargetGroups[0].TargetGroupArn' --output text)
  fi
  if [[ -z "$(aws elbv2 describe-listeners --load-balancer-arn "$lb_arn" --query 'Listeners[?Port==`80`].ListenerArn' --output text)" ]]; then
    aws elbv2 create-listener --load-balancer-arn "$lb_arn" --protocol HTTP --port 80 \
      --default-actions Type=forward,TargetGroupArn="$tg_arn" >/dev/null
  fi
  echo "$tg_arn $(aws elbv2 describe-load-balancers --load-balancer-arns "$lb_arn" --query 'LoadBalancers[0].DNSName' --output text)"
}
read -r TG_FE DNS_FE < <(lb "${P}-fe-alb" /healthz 80)
read -r TG_BE DNS_BE < <(lb "${P}-be-alb" /actuator/health 8080)

cat > "$STATE_FILE" <<EOF
# Automatisch erzeugt von provision.sh (nicht committen)
REGION=${REGION}
ACCOUNT=${ACCOUNT}
VPC=${VPC}
SUBNET_A=${SUBNET_A}
SUBNET_B=${SUBNET_B}
SG_ALB=${SG_ALB}
SG_TASKS=${SG_TASKS}
SG_RDS=${SG_RDS}
SECRET_ARN=${SECRET_ARN}
BUCKET=${BUCKET}
TG_FE=${TG_FE}
TG_BE=${TG_BE}
DNS_FE=${DNS_FE}
DNS_BE=${DNS_BE}
EOF

say "Fertig"
echo "Frontend-URL: http://${DNS_FE}"
echo "Backend-URL:  http://${DNS_BE}"
echo "Zustand gespeichert in ${STATE_FILE}"
