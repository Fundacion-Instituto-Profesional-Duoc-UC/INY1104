#!/bin/bash

# ===================================================================
# Script probado en AWS Academy Learner Lab y ejecutado en CloudShell
# ===================================================================

# =======================
# VARIABLES
# =======================
REGION="us-east-1"
VM_NAME="deployed-sh"
VPC_CIDR="192.168.0.0/16"
SUBNET_CIDR="192.168.10.0/24"
KEY_NAME="vockey"
INSTANCE_TYPE="t3.micro"
AMI_ID="ami-09cb80360d5069de4"  # AMI válida para Windows Server
SECURITY_GROUP_NAME="${VM_NAME}-SG"
USERNAME="Administrator"  # Usuario por defecto en Windows en AWS

echo "=================================================="
echo "|                                                |"
echo "|             INY1104-2025-1                     |"
echo "|                VM en AWS                       |"
echo "|                                                |"
echo "=================================================="

# =======================
# CREAR VPC Y SUBNET
# =======================
echo "========================================"
echo "Creando VPC y subred"
echo "========================================"
VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --region $REGION --query 'Vpc.VpcId' --output text)

aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support "{\"Value\":true}" --region $REGION
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames "{\"Value\":true}" --region $REGION

SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $SUBNET_CIDR \
  --availability-zone us-east-1a \
  --region $REGION \
  --query 'Subnet.SubnetId' \
  --output text)

# =======================
# GATEWAY E INTERNET
# =======================
IGW_ID=$(aws ec2 create-internet-gateway --region $REGION --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION

ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --region $REGION --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $REGION
aws ec2 associate-route-table --route-table-id $ROUTE_TABLE_ID --subnet-id $SUBNET_ID --region $REGION

# =======================
# SECURITY GROUP
# =======================
echo "=================================================="
echo "Creando Security Group con reglas para RDP y HTTP"
echo "=================================================="
SG_ID=$(aws ec2 create-security-group \
  --group-name $SECURITY_GROUP_NAME \
  --description "SG para $VM_NAME" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 3389 --cidr 0.0.0.0/0 --region $REGION
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION

# =======================
# IP PÚBLICA ELÁSTICA
# =======================
echo "========================================"
echo "Creando IP pública elástica"
echo "========================================"
ALLOC_ID=$(aws ec2 allocate-address --region $REGION --domain vpc --query 'AllocationId' --output text)

# =======================
# INSTANCIA EC2
# =======================
echo "========================================"
echo "Lanzando instancia Windows"
echo "========================================"
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --count 1 \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --security-group-ids $SG_ID \
  --subnet-id $SUBNET_ID \
  --associate-public-ip-address \
  --iam-instance-profile Name=LabInstanceProfile \
  --tag-specifications "[{\"ResourceType\":\"instance\",\"Tags\":[{\"Key\":\"Name\",\"Value\":\"$VM_NAME\"}]}]" \
  --region $REGION \
  --query 'Instances[0].InstanceId' \
  --output text)

# Validar que la instancia fue creada correctamente
if [[ -z "$INSTANCE_ID" ]]; then
  echo "❌ ERROR: No se pudo obtener el Instance ID. Abortando..."
  exit 1
fi

echo "📌 Instance ID obtenido: $INSTANCE_ID"

# =======================
# ESPERAR A QUE ESTÉ EN EJECUCIÓN
# =======================
echo "Esperando que la instancia esté en estado 'running' y con status checks 3/3..."

while true; do
  INSTANCE_STATE=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --query "Reservations[0].Instances[0].State.Name" \
    --output text)

  SYSTEM_STATUS=$(aws ec2 describe-instance-status \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --query "InstanceStatuses[0].SystemStatus.Status" \
    --output text)

  INSTANCE_STATUS=$(aws ec2 describe-instance-status \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --query "InstanceStatuses[0].InstanceStatus.Status" \
    --output text)

  echo "Estado: $INSTANCE_STATE | System: $SYSTEM_STATUS | Instance: $INSTANCE_STATUS"

  if [[ "$INSTANCE_STATE" == "running" && "$SYSTEM_STATUS" == "ok" && "$INSTANCE_STATUS" == "ok" ]]; then
    echo "✅ Instancia completamente lista (3/3 checks pasados)"
    break
  fi

  sleep 10
done

# =======================
# ASOCIAR IP PÚBLICA
# =======================
echo "Asociando IP elástica a la instancia..."
aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id $ALLOC_ID --region $REGION

IP_ADDRESS=$(aws ec2 describe-addresses \
  --allocation-ids $ALLOC_ID \
  --region $REGION \
  --query 'Addresses[0].PublicIp' \
  --output text)

# =======================
# INSTALAR IIS
# =======================
echo "==============================================================="
echo "Instalando IIS en la instancia (puede tardar unos minutos)"
aws ssm send-command \
  --document-name "AWS-RunPowerShellScript" \
  --instance-ids "$INSTANCE_ID" \
  --region $REGION \
  --comment "Instalar IIS" \
  --parameters commands=["Install-WindowsFeature -name Web-Server -IncludeManagementTools"] \
  --output text > /dev/null

# =======================
# ESPERAR A QUE IIS RESPONDA
# =======================
echo "Esperando que IIS esté disponible la instancia de Windows Server ..."
echo "(puede tardar unos minutos)"

while true; do
  STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$IP_ADDRESS)

  echo "Código de respuesta HTTP: $STATUS_CODE"

  if [[ "$STATUS_CODE" == "200" ]]; then
    echo "✅ IIS está en línea y respondiendo correctamente"
    break
  fi

  sleep 5
done


# =======================
# FINALIZACIÓN
# =======================
echo "=========================================================="
echo "Despliegue Finalizado. Probar en el navegador: http://$IP_ADDRESS"
echo "=========================================================="
