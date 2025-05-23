# /bin/bash
if [ "$#" -ne 7 ]; then
    echo -e "[$(date)] \e[32mINFO\e[0m：usage: ./bootstrap_gitea.sh [your gitops repo] [your cluster name] [admin username] [pin] [mode] [gitea_admin] [gitea_password]"
    exit 1
fi

unset $1
unset $2
unset $3
unset $4
unset $5
unset $6
unset $7

export gitops_repo=$1 #<your newly created repo>
export cluster_name=$2 #<your cluster name, default hub>
export cluster_base_domain=$(oc get ingress.config.openshift.io cluster --template={{.spec.domain}} | sed -e "s/^apps.//")
export platform_base_domain=${cluster_base_domain#*.}
export admin_username=$3  #<your admin username, default admin>
export pin=$4 #<your target revision>
export mode=$5 #<you installed mode | hub or spoke>
export GITEA_ADMIN=$6
export GITEA_PASSWORD=$7

envsubst < .bootstrap/group.yaml | oc apply -f -

oc apply -f .bootstrap/subscription-bundle.yaml
echo -n -e "[$(date)] \e[32mINFO\e[0m：Waiting for openshift-gitops operators ready in openshift-gitops-operator namespace"

sleep 20

while [ "truex" != "$(oc get pod -l control-plane=gitops-operator -n openshift-gitops-operator -ojsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)x" ]; do
    echo -n '.'
    sleep 1
done
echo -e "[$(date)] \e[32mINFO\e[0m：openshift-gitops is ready"

oc apply -f .bootstrap/cluster-rolebinding.yaml

if [ "$5" == "hub" ]; then
   envsubst < .bootstrap/argocd_hub.yaml | oc apply -f -
elif [ "$5" == "spoke" ]; then
   envsubst < .bootstrap/argocd_spoke.yaml | oc apply -f -
else
   echo "ERROR：模式配置錯誤"
   exit 1
fi

echo -n -e "[$(date)] \e[32mINFO\e[0m：Waiting for argocd server ready in openshift-gitops namespace"
while [ "Availablex" != "$(oc get argocd openshift-gitops -n openshift-gitops -ojsonpath='{.status.phase}' 2>/dev/null)x" ]; do
    echo -n '.'
    sleep 3
done
echo -e "[$(date)] \e[32mINFO\e[0m：argocd server is ready"

envsubst < .bootstrap/argocd_gitea_secret.yaml | oc apply -f -

envsubst < .bootstrap/root-application.yaml | oc apply -f -