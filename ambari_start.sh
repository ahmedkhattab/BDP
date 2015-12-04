#!/bin/bash

KUBE="/home/khattab/kubernetes-1.1.2/cluster/kubectl.sh"
AMBARI_SERVER_POD="amb-server.service.consul"

get-ambari-server() {
  AMBARI_PORT=$($KUBE get service ambari -o=template '--template={{(index .spec.ports 0).nodePort}}')
  AMBARI_IP=$($KUBE get nodes -o=template '--template={{(index (index .items 0).status.addresses 2).address}}')
}

get-host-ip() {
  $KUBE get pod $1 -o template --template={{.status.hostIP}}
}

get-pod-status() {
  $KUBE get pod $1 -o template --template={{.status.phase}}
}


get-pending-pods() {
  $KUBE get pods | grep "Pending" | wc -l
}

get-namenode-pod() {
  get-ambari-server
  json= curl -s --user admin:admin http://$AMBARI_IP:$AMBARI_PORT/api/v1/clusters/multi-node-hdfs/services/HDFS/components/NAMENODE -o namenode.json
  NAMENODE_HOST=$(jq -r '.host_components[] | select(.HostRoles.component_name=="NAMENODE") | .HostRoles.host_name' namenode.json)
   echo -e "${color_yellow} Namenode running on $NAMENODE_HOST ${color_norm}"
}


clean-up-ambari() {
  echo "Ambari: Cleaning up minions ... "
  $KUBE delete rc amb-slave-controller
  $KUBE delete svc ambari
  $KUBE delete svc consul
  $KUBE delete pods $AMBARI_SERVER_POD
  $KUBE delete pods amb-consul
  $KUBE delete pods amb-shell

	while true; do
		remaining=$($KUBE get pods --no-headers | grep "amb" | wc -l)
		if [[ $remaining == 0 ]]; then
      echo "done"
			break
		else
			echo -n "."
			sleep 5
		fi
	done
}

start_ambari() {

	clean-up-ambari

	echo "Ambari: Launching consul"
	$KUBE create -f ~/Ambari/consul.json
	$KUBE create -f ~/Ambari/consul-service.json

  echo "Ambari: Waiting for consul server to start"
  while true; do
		server_state=$(get-pod-status amb-consul)
		if [[ "$server_state" == "Running" ]]; then
			echo ""
      break
		else
			echo -n "."
			sleep 5
		fi
	done

	echo "Ambari: Launching Ambari server"
	$KUBE create -f ~/Ambari/ambari-hdfs.json
	$KUBE create -f ~/Ambari/ambari-service.json

  echo "Ambari: Waiting for ambari server to start"
	while true; do
		server_state=$(get-pod-status $AMBARI_SERVER_POD)
		if [[ "$server_state" == "Running" ]]; then
			echo ""			
			break
		else
			echo -n "."
			sleep 5
		fi
	done

	echo "Ambari: Registering consul services"

	AMBARI_CLUSTER_IP=$($KUBE get service ambari -o=template '--template={{.spec.clusterIP}}')

	$KUBE exec $AMBARI_SERVER_POD -- /bin/sh -c 'curl -X PUT -d "{\"Node\": \"ambari-8080\",\"Address\": \"'$AMBARI_CLUSTER_IP'\",\"Service\": {\"Service\": \"ambari-8080\"}}" http://$CONSUL_SERVICE_HOST:8500/v1/catalog/register'

	$KUBE exec $AMBARI_SERVER_POD -- /bin/sh -c 'curl -X PUT -d "{\"Node\": \"amb-server\",\"Address\": \"'$AMBARI_CLUSTER_IP'\",\"Service\": {\"Service\": \"amb-server\"}}" http://$CONSUL_SERVICE_HOST:8500/v1/catalog/register'


	echo "Ambari: waiting for 3 Ambari slaves to start ..."
	$KUBE create -f ~/Ambari/ambari-slave.json
	while true; do
		pending_pods=$(get-pending-pods)
		if [[ $pending_pods == 0 ]]; then
			break
		else
			echo -n "."
			sleep 5
		fi
	done

	echo "Ambari: Creating ambari cluster using the blueprint multi-node-hdfs"
	$KUBE create -f ~/Ambari/ambari-shell.json

	$KUBE get pods | cut -d " " -f 1 | grep amb-slave | while read pod; do  
		$KUBE exec $pod -- /bin/sh -c 'curl -X PUT -d "{\"Node\": \"$(hostname)\",\"Address\": \"$(hostname -I)\",\"Service\": {\"Service\": \"$(hostname)\"}}" http://$CONSUL_SERVICE_HOST:8500/v1/catalog/register'
	done

	get-ambari-server

	echo -e "${color_yellow} Ambari: Ambari UI accessible through: http://$AMBARI_IP:$AMBARI_PORT .${color_norm}"
	echo "Ambari: Ambari UI accessible through: http://$AMBARI_IP:$AMBARI_PORT" > stdout
}

