#!/bin/bash

DEBUG=
CONF=
REALNAME=
WORK=getinputs

hr () { printf "%0$(tput cols)d" | tr 0 ${1:-=}; }

which fzf-tmux &> /dev/null && fzf="$(which fzf-tmux) --tac --height 90%" || fzf="fzf"

while [[ $# -gt 0 ]] && [[ "$1" == "--"* ]] ;
do
  opt=${1}
  case "${opt}" in
    "--" )
      break 2;;
#    "--dry" ) DRYRUN=1;;
#    "--dryrun" ) DRYRUN=1;;
#    "--test" ) DRYRUN=1;;
    "--debug" ) DEBUG=1 ;;
    "--realname" ) REALNAME=1 ;;
    "--viewconf" ) WORK=viewconf ;;
    "--getconf" )
      CONF=1
      WORK=getinputs
      ;;
    "--walk" )
      WORK=getinputs
      ;;
    "--help" )
      WORK=help
      ;;
    *)
      ;;
  esac
  shift
done

#main
while [ $WORK ]; do
  case "$WORK" in
    "viewconf" )
      hr
      echo "Current clusters in ~/.kube/config"
      kubectl config view --flatten -o jsonpath='{.users[?(@.name)].name}' | xargs -n 1 echo
      WORK=
      ;;
    "pullconf" )
      if [ "${namespace}" == "WHOLE_CLUSTER" ]; then
        OUTFILE=${HOME}/.kube/${cluster}.yaml
        command="tanzu tmc cluster kubeconfig get -m $supervisor -p $provisioner $cluster"
      else
        OUTFILE=${HOME}/.kube/${cluster}-${namespace}.yaml
        command="tanzu tmc cluster kubeconfig get -m $supervisor -p $provisioner $cluster -n $namespace"
      fi
      WORK=commandwrite
      ;;
    "commandwrite" )
      $command > $OUTFILE && WORK=mergeconf || WORK=debug
      ;;
    "mergeconf" )
      echo Merging config from $OUTFILE for $cluster in $supervisor
      cp ~/.kube/config ~/.kube/config.bak && KUBECONFIG=~/.kube/config:${OUTFILE} kubectl config view --flatten > ~/.kube/config.tmp && mv ~/.kube/config.tmp ~/.kube/config
      WORK=viewconf
      ;;
    "getinputs" )
      WORK=getsupervisor
      ;;
    "getsupervisor" )
      if [ $REALNAME ]; then
        supervisor=$(tanzu tmc management-cluster list -o json | jq -r '.managementClusters[] | "\(.fullName.name)"'  | csvgrep -H -c 1 -r "attached|aks|eks|null" -i | tail -n +2 | sort | uniq | ${fzf})
      else
        commonname=$(tanzu tmc management-cluster list -o json | jq -r '.managementClusters[] | "\(.meta.labels.cn)"' | csvgrep -H -c 1 -r "attached|aks|eks|null" -i | tail -n +2 | sort | uniq | ${fzf})
        supervisor=$(tanzu tmc management-cluster list -o json | jq -r '.managementClusters[] | "\(.meta.labels.cn),\(.fullName.name)"' | csvgrep -H -c 1 -m ${commonname} | csvcut -c 2 | tail -n +2)
      fi
      WORK=getcluster
      ;;
    "getcluster" )
      cluster=$(tanzu tmc cluster list -m $supervisor -o json | jq -r '.clusters[] | "\(.fullName.name)"' | ${fzf})
      WORK=getprovisioner
      ;;
    "getprovisioner" )
      provisioner=$(tanzu tmc cluster list -m $supervisor -o json | jq -r '.clusters[] | "\(.fullName.managementClusterName),\(.fullName.name),\(.fullName.provisionerName)"' | csvgrep -H -c 1 -m $supervisor | csvgrep -c 2 -m $cluster | csvcut -c 3 | tail -n +2)
      WORK=getnamespace
      ;;
    "getnamespace" )
      namespace=$((echo WHOLE_CLUSTER; tanzu tmc cluster namespace list -m $supervisor -p $provisioner --cluster-name $cluster -o json | jq -r '.namespaces[] | "\(.fullName.name)"') | ${fzf})
      WORK=viewobjects
      [ $CONF ] && WORK=pullconf
      ;;
    "viewobjects" )
      if [ "${namespace}" == "WHOLE_CLUSTER" ]; then
        command="tanzu tmc cluster namespace list -m $supervisor -p $provisioner --cluster-name $cluster"
      else
        command="tanzu tmc cluster namespace get $namespace -m $supervisor -p $provisioner --cluster-name $cluster"
      fi
      WORK=viewcommand
      ;;
    "viewcommand" )
      $command
      hr
      echo "#"$command
      WORK=
      ;;
    "debug" )
      hr
      echo Error.  Debugging.
      echo \$1=$1
      echo DEBUG=$DEBUG
      echo WORK=$WORK
      echo command=$command
      echo CONF=$CONF
      echo OUTFILE=$OUTFILE
      echo REALNAME=$REALNAME
      echo supervisor=$supervisor
      echo commonname=$commonname
      echo cluster=$cluster
      echo provisioner=$provisioner
      echo namespace=$namespace
      WORK=
      ;;
    "help" )
      echo "--debug      Show debug values"
      echo "--realname   Use real supervisor cluster names instead of common name label"
      echo "--viewconf   View current ~/.kube/config"
      echo "--getconf    Fetch kubeconfig from TMC"
      echo "--walk       Browse through Supervisor->Cluster->Namespace"
      echo "--help       Hopefully this is"
      WORK=
      ;;
    *)
      echo "Something Invalid Happened"
      WORK=debug
      ;;
  esac
done
