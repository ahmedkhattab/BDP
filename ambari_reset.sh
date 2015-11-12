#!/bin/bash

get-host-ip() {
  $KUBE get pod $1 -o template -t={{.status.hostIP}}
}

KUBE="/home/khattab/kubernetes/cluster/kubectl.sh"

echo "Cleaning up minions ... "
$KUBE delete rc --all
$KUBE delete svc ambari
$KUBE delete svc consul
$KUBE delete pods --all

echo "Launching consul"
$KUBE create -f ~/Ambari/consul.json
$KUBE create -f ~/Ambari/consul-service.json

echo "Launching Ambari server"
$KUBE create -f ~/Ambari/ambari-hdfs.json
$KUBE create -f ~/Ambari/ambari-service.json

sleep 25
echo "Registering consul services"

export AMBARI_CLUSTER_IP=$($KUBE get service ambari -o=template '-t={{.spec.clusterIP}}')
echo $AMBARI_CLUSTER_IP
$KUBE exec amb-server -- /bin/sh -c 'curl -X PUT -d "{\"Node\": \"ambari-8080\",\"Address\": \"'$AMBARI_CLUSTER_IP'\",\"Service\": {\"Service\": \"ambari-8080\"}}" http://$CONSUL_SERVICE_HOST:8500/v1/catalog/register'

$KUBE exec amb-server -- /bin/sh -c 'curl -X PUT -d "{\"Node\": \"amb-server\",\"Address\": \"'$AMBARI_CLUSTER_IP'\",\"Service\": {\"Service\": \"amb-server\"}}" http://$CONSUL_SERVICE_HOST:8500/v1/catalog/register'

echo "Launching 3 Ambari slaves"
$KUBE create -f ~/Ambari/ambari-slave.json
sleep 25
$KUBE get pods

echo "Creating ambari cluster using the blueprint multi-node-hdfs-yarn"
$KUBE create -f ~/Ambari/ambari-shell.json

$KUBE get pods | cut -d " " -f 1 | grep amb-slave | while read pod; do  
	$KUBE exec $pod -- /bin/sh -c 'curl -X PUT -d "{\"Node\": \"$(hostname)\",\"Address\": \"$(hostname -I)\",\"Service\": {\"Service\": \"$(hostname)\"}}" http://$CONSUL_SERVICE_HOST:8500/v1/catalog/register'
done

#$KUBE exec -it amb-shell -- /bin/sh -c '/tmp/install-cluster.sh'
#$KUBE exec -it amb-shell -- /bin/sh -c 'wget /multi-node-hdfs-yarn.json https://raw.githubusercontent.com/sequenceiq/ambari-rest-client/2.1.11/src/main/resources/blueprints/multi-node-hdfs-yarn'

export AMBARI_PORT=$($KUBE get service ambari -o=template '-t={{(index .spec.ports 0).nodePort}}')
export AMBARI_IP=$($KUBE get nodes -o=template '-t={{(index (index .items 0).status.addresses 2).address}}')

echo "Ambari UI accessible through: http://$AMBARI_IP:$AMBARI_PORT"




