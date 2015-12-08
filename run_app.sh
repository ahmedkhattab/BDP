#!/bin/bash
KUBE="/home/khattab/kubernetes-1.1.2/cluster/kubectl.sh"

$KUBE exec spark-driver -- /bin/sh -c 'if [ -d "bdp_apps/" ]; then
    rm -rf "bdp_apps/"
fi'


echo "Fetching code repository ..."
$KUBE exec -it spark-driver -- /bin/sh -c 'git clone https://github.com/ahmedkhattab/bdp_apps.git'
$KUBE exec -it spark-driver -- /bin/sh -c 'spark-submit ./bdp_apps/SparkApp/target/SparkApp-0.0.1-SNAPSHOT-jar-with-dependencies.jar'
