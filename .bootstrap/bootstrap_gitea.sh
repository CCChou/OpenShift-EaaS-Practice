# /bin/bash
if [ "$#" -ne 4 ]; then
    echo "usage: ./bootstrap_gitea.sh [your gitops repo] [your cluster name] [admin username] [pin] [mode] [gitea_admin] [gitea_password]"
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

oc apply -f .bootstrap/subscription.yaml
echo -n "Waiting for openshift-gitops operators ready in openshift-operators namespace"

sleep 20

while [ "true" != "$(oc get pod -l control-plane=gitops-operator -n openshift-operators -ojsonpath='{.items[0].status.containerStatuses[0].ready}')" ]; do
    echo -n '.'
    sleep 1
done
echo "openshift-gitops is ready"

oc apply -f .bootstrap/cluster-rolebinding.yaml

if [ "$5" == "hub" ]; then
   envsubst < .bootstrap/argocd_hub.yaml | oc apply -f -
elif [ "$5" == "spoke" ]; then
   envsubst < .bootstrap/argocd_spoke.yaml | oc apply -f -
else
   echo "模式配置錯誤"
   exit 1
fi

echo -n "Waiting for argocd server ready in openshift-gitops namespace"
while [ "Available" != "$(oc get argocd openshift-gitops -n openshift-gitops -ojsonpath='{.status.phase}')" ]; do
    echo -n '.'
    sleep 3
done
echo "argocd server is ready"

envsubst < .bootstrap/argocd_gitea_secret.yaml | oc apply -f -

envsubst < .bootstrap/root-application.yaml | oc apply -f -