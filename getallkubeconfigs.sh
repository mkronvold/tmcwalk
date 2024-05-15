#!/bin/bash

#figure out where we are

[ $(hostname -s) == "dev2013" ] && site=sv4 && env=dev

[ $(hostname -s) == "stg555" ] && site=sv4 && env=stg
[ $(hostname -s) == "stgf1088" ] && site=fr8 && env=stg

[ $(hostname -s) == "prod10506" ] && site=sv1 && env=prod
[ $(hostname -s) == "prod41773" ] && site=ch3 && env=prod
[ $(hostname -s) == "prod3029" ] && site=sha && env=prod
[ $(hostname -s) == "prod9088" ] && site=fr8 && env=prod

[ $(hostname -s) == "prod8073" ] && site=cdg && env=dr
[ $(hostname -s) == "prod7012" ] && site=de2 && env=dr

commonname=$site-$env

# and what our WCP is

supervisor=$(tanzu tmc management-cluster list -o json | jq -r '.managementClusters[] | "\(.meta.labels.cn),\(.fullName.name)"' | csvgrep -H -c 1 -m ${commonname} | csvcut -c 2 | tail -n +2)

# from the WCP get a cluster list
# find the provisioner of each cluster
# pull the kubeconfig to ~/.kube
# merge with ~/.kube/config

for cluster in $(tanzu tmc cluster list -m $supervisor -o json | jq -r '.clusters[] | "\(.fullName.name)"')
do
  regex=^${cluster}$
  provisioner=$(tanzu tmc cluster list -m $supervisor -o json | jq -r '.clusters[] | "\(.fullName.managementClusterName),\(.fullName.name),\(.fullName.provisionerName)"' | csvgrep -H -c 1 -m $supervisor | csvgrep -c 2 -r $regex | csvcut -c 3 | tail -n +2)
  OUTFILE=${HOME}/.kube/${cluster}.yaml
  command="tanzu tmc cluster kubeconfig get -m $supervisor -p $provisioner $cluster"
  $command > $OUTFILE
  echo Merging config from $OUTFILE for $cluster in $supervisor
  cp ~/.kube/config ~/.kube/config.bak && KUBECONFIG=~/.kube/config:${OUTFILE} kubectl config view --flatten > ~/.kube/config.tmp && mv ~/.kube/config.tmp ~/.kube/config
done

#hr
echo "Current clusters in ~/.kube/config"
kubectl config view --flatten -o jsonpath='{.users[?(@.name)].name}' | xargs -n 1 echo
