#!/bin/bash

# Variables
RESOURCE_GROUP="$RESOURCE_GROUP"
LOCATION="$LOCATION"
VM_NAME="$VM_NAME"
VNET_NAME="$VNET_NAME"
SUBNET_NAME="$SUBNET_NAME"
NIC_NAME="$NIC_NAME"
ADMIN_USERNAME="$ADMIN_USERNAME"
ADMIN_PASSWORD="$ADMIN_PASSWORD"
IP_NAME="$VM_NAME-PublicIP"
NSG_NAME="$VM_NAME-NSG"
IMAGE="$IMAGE"

echo "=================================================="
echo "|                                                |"
echo "|                 INY1104                        |"
echo "|                VM en Azure                     |"
echo "|                                                |"
echo "=================================================="

echo "========================================"
echo "Creando grupo de recursos"
echo "========================================"
az group create --name $RESOURCE_GROUP --location $LOCATION

echo "========================================"
echo "Creando red virtual y subred"
echo "========================================"
az network vnet create --resource-group $RESOURCE_GROUP --name $VNET_NAME --address-prefix "192.168.0.0/16" --subnet-name $SUBNET_NAME --subnet-prefix "192.168.10.0/24"

echo "========================================"
echo "Creando IP pública"
echo "========================================"
az network public-ip create --resource-group $RESOURCE_GROUP --name $IP_NAME --sku Standard --allocation-method Static

echo "======================================================================================"
echo "Creando Network Security Group con reglas para RDP y HTTP con origen abierto al mundo!"
echo "======================================================================================"
az network nsg create --resource-group $RESOURCE_GROUP --name $NSG_NAME

#Creando reglas para RDP y HTTP"
az network nsg rule create --resource-group $RESOURCE_GROUP --nsg-name $NSG_NAME --name RDPAccess --priority 1000 --protocol Tcp --destination-port-range 3389 --access Allow --direction Inbound --source-address-prefix "0.0.0.0/0"
az network nsg rule create --resource-group $RESOURCE_GROUP --nsg-name $NSG_NAME --name HTTPAccess --priority 1010 --protocol Tcp --destination-port-range 80 --access Allow --direction Inbound --source-address-prefix "0.0.0.0/0"

echo "=================================================="
echo "Creando NIC de red asociando con NSG e IP pública"
sleep 2
echo "Comprobando existencia de la IP pública..."

while :; do
  IP_ADDRESS=$(az network public-ip show --name $IP_NAME --resource-group $RESOURCE_GROUP --query ipAddress --output tsv 2>/dev/null)
  
  if [[ -n "$IP_ADDRESS" && "$IP_ADDRESS" != "null" ]]; then
    sleep 2
    echo "La IP pública encontrada es: $IP_ADDRESS"
    break # Salir del bucle cuando la IP pública esté disponible
  else
    echo "Aún no... comprobando nuevamente"
    sleep 10 # Esperar 10 segundos antes de intentarlo de nuevo
  fi
done
echo "=================================================="

az network nic create --resource-group $RESOURCE_GROUP --name $NIC_NAME --vnet-name $VNET_NAME --subnet $SUBNET_NAME --network-security-group $NSG_NAME --public-ip-address $IP_NAME

echo "==============================================================="
echo "Creando VM de Windows Server..."

az vm create --resource-group $RESOURCE_GROUP --location $LOCATION --name $VM_NAME --nics $NIC_NAME --image $IMAGE --admin-username $ADMIN_USERNAME --admin-password $ADMIN_PASSWORD --tags env=action-deployment --no-wait

echo "Comprobando que la máquina virtual exista y esté ejecutándose"
echo "==============================================================="

while :; do
  # Obtener el estado de la VM
  VM_STATUS=$(az vm get-instance-view --name $VM_NAME --resource-group $RESOURCE_GROUP --query instanceView.statuses[1].code --output tsv)

  if [[ "$VM_STATUS" == "PowerState/running" ]]; then
    echo "Estado actual de la VM: $VM_STATUS"
    echo "Se comprueba que la VM se está ejecutando, se procede a instalar"
    echo "el servicio de Web Server (IIS), espere un momento por favor..."
    break # Salir del bucle cuando la VM esté en estado 'running'
  else
    echo "==============================================================="
    echo "VM aún no disponible, esperando el estado 'running'..."
    echo "Intentando comprobar nuevamente..."
    sleep 10 # Esperar 10 segundos antes de intentarlo de nuevo
  fi
done

echo "==============================================================="
az vm run-command invoke --resource-group $RESOURCE_GROUP --name $VM_NAME --command-id RunPowerShellScript --scripts "Install-WindowsFeature -name Web-Server -IncludeManagementTools"

echo "=========================================================="
echo "Despligue Finalizado, validar funcionamiento del servidor"
echo "Probar en su navegador la siguente url http://$IP_ADDRESS"
echo "=========================================================="