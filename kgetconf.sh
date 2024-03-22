#!/bin/bash

DEBUG=
VIEW=

while [[ $# -gt 0 ]] && [[ "$1" == "--"* ]] ;
do
  opt=${1}
  case "${opt}" in
    "--" )
      break 2;;
    "--dry" ) DRYRUN=1;;
    "--dryrun" ) DRYRUN=1;;
    "--test" ) DRYRUN=1;;
    "--debug" ) DEBUG=1 ;;
    "--view" ) JUSTVIEW=1 ;;
    *) #erm. nothing here.
    ;;
  esac
  shift
done

hr () { printf "%0$(tput cols)d" | tr 0 ${1:-=}; }

if [ $JUSTVIEW ]; then
  VIEW=1
else
  which fzf-tmux &> /dev/null && fzf="$(which fzf-tmux) --tac --height 40%" || fzf="fzf"

  supervisor=$(tanzu tmc cluster list -o json | jq -r '.clusters[] | "\(.fullName.managementClusterName)"' | csvgrep -H -c 1 -i -m attached | tail -n +2 | sort | uniq | ${fzf})

  cluster=$(tanzu tmc cluster list -m $supervisor -o json | jq -r '.clusters[] | "\(.fullName.name)"' | ${fzf})

  provisioner=$(tanzu tmc cluster list -m $supervisor -o json | jq -r '.clusters[] | "\(.fullName.managementClusterName),\(.fullName.name),\(.fullName.provisionerName)"' | csvgrep -H -c 1 -m $supervisor | csvgrep -c 2 -m $cluster | csvcut -c 3 | tail -n +2)

  namespace=$((echo WHOLE_CLUSTER; tanzu tmc cluster namespace list -m $supervisor -p $provisioner --cluster-name $cluster -o json | jq -r '.namespaces[] | "\(.fullName.name)"') | ${fzf})

  if [ "${namespace}" == "WHOLE_CLUSTER" ]; then
    OUTFILE=${HOME}/.kube/${cluster}.yaml
    command="tanzu tmc cluster kubeconfig get -m $supervisor -p $provisioner $cluster"
  else
    OUTFILE=${HOME}/.kube/${cluster}-${namespace}.yaml
    command="tanzu tmc cluster kubeconfig get -m $supervisor -p $provisioner $cluster -n $namespace"
  fi

  $command > $OUTFILE && VIEW=1 || DEBUG=1

  if [ $DEBUG ]; then
    hr
    echo Error.  Debugging.
    echo \$1=$1
    echo DEBUG=$DEBUG
    echo command=$command
    echo OUTFILE=$OUTFILE
    echo supervisor=$supervisor
    echo cluster=$cluster
    echo provisioner=$provisioner
    echo namespace=$namespace
  else
    echo Merging config for $cluster in $supervisor
    cp ~/.kube/config ~/.kube/config.bak && KUBECONFIG=~/.kube/config:${OUTFILE} kubectl config view --flatten > ~/.kube/config.tmp && mv ~/.kube/config.tmp ~/.kube/config
  fi
fi

if [ $VIEW ]; then
  hr
  echo "Current clusters in ~/.kube/config"
  kubectl config view --flatten -o jsonpath='{.users[?(@.name)].name}' | xargs -n 1 echo
fi
