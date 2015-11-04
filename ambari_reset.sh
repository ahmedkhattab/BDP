#!/bin/bash
echo "Cleaning up minions ... "
~/kubernetes/cluster/kubectl.sh delete rc --all
~/kubernetes/cluster/kubectl.sh delete svc ambari
~/kubernetes/cluster/kubectl.sh delete svc consul
~/kubernetes/cluster/kubectl.sh delete pods --all

echo "Launching consul"
~/kubernetes/cluster/kubectl.sh create -f ~/Ambari/consul.json
~/kubernetes/cluster/kubectl.sh create -f ~/Ambari/consul-service.json

echo "Launching Ambari server"
~/kubernetes/cluster/kubectl.sh create -f ~/Ambari/ambari-hdfs.json
~/kubernetes/cluster/kubectl.sh create -f ~/Ambari/ambari-service.json

sleep 8
echo "Registering consul services"

export AMBARI_CLUSTER_IP=$(~/kubernetes/cluster/kubectl.sh get service ambari -o=template '-t={{.spec.clusterIP}}')

~/kubernetes/cluster/kubectl.sh exec amb-server -- /bin/sh -c 'curl -X PUT -d "{\"Node\": \"ambari-8080\",\"Address\": \"'$AMBARI_CLUSTER_IP'\",\"Service\": {\"Service\": \"ambari-8080\"}}" http://$CONSUL_SERVICE_HOST:8500/v1/catalog/register'

~/kubernetes/cluster/kubectl.sh exec amb-server -- /bin/sh -c 'curl -X PUT -d "{\"Node\": \"ambari\",\"Address\": \"'$AMBARI_CLUSTER_IP'\",\"Service\": {\"Service\": \"ambari\"}}" http://$CONSUL_SERVICE_HOST:8500/v1/catalog/register'

echo "Launching 3 Ambari slaves"
~/kubernetes/cluster/kubectl.sh create -f ~/Ambari/ambari-slave.json

sleep 5
~/kubernetes/cluster/kubectl.sh get pods


export AMBARI_PORT=$(~/kubernetes/cluster/kubectl.sh get service ambari -o=template '-t={{(index .spec.ports 0).nodePort}}')
export AMBARI_IP=$(~/kubernetes/cluster/kubectl.sh get nodes -o=template '-t={{(index (index .items 0).status.addresses 2).address}}')

echo "Ambari UI accessible through: http://$AMBARI_IP:$AMBARI_PORT"




