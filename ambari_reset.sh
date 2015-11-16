#!/bin/bash
KUBE="/home/khattab/kubernetes/cluster/kubectl.sh"

get-ambari-server() {
  AMBARI_PORT=$($KUBE get service ambari -o=template '-t={{(index .spec.ports 0).nodePort}}')
  AMBARI_IP=$($KUBE get nodes -o=template '-t={{(index (index .items 0).status.addresses 2).address}}')
}

get-host-ip() {
  $KUBE get pod $1 -o template -t={{.status.hostIP}}
}

get-pod-status() {
  $KUBE get pod $1 -o template -t={{.status.phase}}
}


get-pending-pods() {
  $KUBE get pods | grep "Pending" | wc -l
}

get-namenode-pod() {
  get-ambari-server
  json= curl -s --user admin:admin http://$AMBARI_IP:$AMBARI_PORT/api/v1/clusters/multi-node-hdfs/services/HDFS/components/NAMENODE -o namenode.json
  NAMENODE_HOST=$(jq -r '.host_components[] | select(.HostRoles.component_name=="NAMENODE") | .HostRoles.host_name' namenode.json)
  echo $NAMENODE_HOST
}


clean-up() {
  echo "Cleaning up minions ... "
  $KUBE delete rc --all
  $KUBE delete svc ambari
  $KUBE delete svc consul
  $KUBE delete pods --all
}

start() {

	clean-up

	echo "Launching consul"
	$KUBE create -f ~/Ambari/consul.json
	$KUBE create -f ~/Ambari/consul-service.json
	
   echo "Waiting for consul server to start"
  while true; do
		server_state=$(get-pod-status amb-consul)
		if [[ "$server_state" == "Running" ]]; then
			break
		else
			echo "."
			sleep 5
		fi
	done

	echo "Launching Ambari server"
	$KUBE create -f ~/Ambari/ambari-hdfs.json
	$KUBE create -f ~/Ambari/ambari-service.json

  echo "Waiting for ambari server to start"
	while true; do
		server_state=$(get-pod-status amb-server)
		if [[ "$server_state" == "Running" ]]; then
			break
		else
			echo "."
			sleep 5
		fi
	done

	echo "Registering consul services"

	AMBARI_CLUSTER_IP=$($KUBE get service ambari -o=template '-t={{.spec.clusterIP}}')

	$KUBE exec amb-server -- /bin/sh -c 'curl -X PUT -d "{\"Node\": \"ambari-8080\",\"Address\": \"'$AMBARI_CLUSTER_IP'\",\"Service\": {\"Service\": \"ambari-8080\"}}" http://$CONSUL_SERVICE_HOST:8500/v1/catalog/register'

	$KUBE exec amb-server -- /bin/sh -c 'curl -X PUT -d "{\"Node\": \"amb-server\",\"Address\": \"'$AMBARI_CLUSTER_IP'\",\"Service\": {\"Service\": \"amb-server\"}}" http://$CONSUL_SERVICE_HOST:8500/v1/catalog/register'

	echo "Launching 3 Ambari slaves"
	$KUBE create -f ~/Ambari/ambari-slave.json
	while true; do
		pending_pods=$(get-pending-pods)
		if [[ $pending_pods == 0 ]]; then
			break
		else
			echo "Waiting for $pending_pods ambari slaves to start"
			sleep 5
		fi
	done

	echo "Creating ambari cluster using the blueprint multi-node-hdfs-yarn"
	$KUBE create -f ~/Ambari/ambari-shell.json

	$KUBE get pods | cut -d " " -f 1 | grep amb-slave | while read pod; do  
		$KUBE exec $pod -- /bin/sh -c 'curl -X PUT -d "{\"Node\": \"$(hostname)\",\"Address\": \"$(hostname -I)\",\"Service\": {\"Service\": \"$(hostname)\"}}" http://$CONSUL_SERVICE_HOST:8500/v1/catalog/register'
	done

	#$KUBE exec -it amb-shell -- /bin/sh -c '/tmp/install-cluster.sh'
	#$KUBE exec -it amb-shell -- /bin/sh -c 'wget /multi-node-hdfs-yarn.json https://raw.githubusercontent.com/sequenceiq/ambari-rest-client/2.1.11/src/main/resources/blueprints/multi-node-hdfs-yarn'

	get-ambari-server

	echo "Ambari UI accessible through: http://$AMBARI_IP:$AMBARI_PORT"
}

