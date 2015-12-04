#!/bin/bash
KUBE="/home/khattab/kubernetes-1.1.2/cluster/kubectl.sh"

if [[ -z "${color_start-}" ]]; then
  declare -r color_start="\033["
  declare -r color_red="${color_start}0;31m"
  declare -r color_yellow="${color_start}0;33m"
  declare -r color_green="${color_start}0;32m"
  declare -r color_norm="${color_start}0m"
fi


echo -e "${color_green} Starting ambari ... ${color_norm}"
. ambari_start.sh && start_ambari
sleep 20
get-namenode-pod
$KUBE expose pod $NAMENODE_HOST --port=8020 --target-port=8020 --name=namenode


echo -e "${color_green} Starting rabbitmq ... ${color_norm}"
. rabbitmq_start.sh && start_rabbitmq

echo -e "${color_green} Starting spark ... ${color_norm}"
. spark_start.sh && start_spark

while true; do
		driver_state=$(get-pod-status spark-driver)
		if [[ "$driver_state" == "Running" ]]; then
			echo ""			
			break
		else
			echo -n "."
			sleep 5
		fi
	done

echo "Fetching code repository ..."
$KUBE exec spark-driver -- /bin/sh -c 'git clone https://github.com/ahmedkhattab/bdp_apps.git'
#$KUBE exec spark-driver -- /bin/sh -c 'spark-submit ./bdp_apps/SparkApp/target/SparkApp-0.0.1-SNAPSHOT-jar-with-dependencies.jar'
