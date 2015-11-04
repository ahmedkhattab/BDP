#!/bin/bash

get-consul-ip() {
  kubectl get service consul -o=template -t={{.spec.clusterIP}}
}

get-ambari-ip() {
  kubectl get service ambari -o=template -t={{.spec.clusterIP}}
}

_consul-register-service() {
  curl -X PUT -d "{\"Node\": \"ambari\",\"Address\": \"$AMBARI_SERVICE_HOST\",\"Service\": {\"Service\": \"ambari\"}}" http://$CONSUL_SERVICE_HOST:8500/v1/catalog/register
}


 _consul-register-service ambari $(AMBARI_SERVICE_HOST)
 _consul-register-service ambari-8080 $(AMBARI_SERVICE_HOST)
