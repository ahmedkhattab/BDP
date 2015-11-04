#!/bin/bash

export KUBERNETES_PROVIDER=aws
export KUBE_AWS_ZONE=eu-west-1b
export NUM_MINIONS=3
export MINION_SIZE=t2.small
export AWS_S3_REGION=eu-west-1
export AWS_S3_BUCKET=kh-kubernetes-artifacts
export INSTANCE_PREFIX=k8s

./cluster/kube-up.sh
