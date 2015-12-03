#!/bin/bash
KUBE="/home/khattab/kubernetes-1.1.2/cluster/kubectl.sh"

. rabbitmq_start.sh && start_rabbitmq
. spark_start.sh && start_spark

$KUBE exec spark-driver -- /bin/sh -c 'git clone https://github.com/ahmedkhattab/bdp_apps.git'
spark-submit ./bdp_apps/SparkApp/target/SparkApp-0.0.1-SNAPSHOT-jar-with-dependencies.jar 
