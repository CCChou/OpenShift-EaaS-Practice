# /bin/bash
if [ "$#" -ne 4 ]; then
    echo "usage: ./bootstrap.sh [your gitops repo] [your cluster name] [admin username] [pin]"
    exit 1
fi

unset $1
unset $2
unset $3
unset $4

export gitops_repo=$1 #<your newly created repo>
export cluster_name=$2	 #<your cluster name, default hub>
export cluster_base_domain=$(oc get ingress.config.openshift.io cluster --template={{.spec.domain}} | sed -e "s/^apps.//")
export platform_base_domain=${cluster_base_domain#*.}
export admin_username=$3  #<your admin username, default admin>
export pin=$4

envsubst < .bootstrap/group.yaml | oc apply -f -

oc apply -f .bootstrap/subscription.yaml
echo -n "Waiting for openshift-gitops operators ready in openshift-operators namespace"
while [ "true" != "$(oc get pod -l control-plane=gitops-operator -n openshift-operators -ojsonpath='{.items[0].status.containerStatuses[0].ready}')" ]; do
    echo -n '.'
    sleep 3
done
echo "openshift-gitops is ready"

oc apply -f .bootstrap/cluster-rolebinding.yaml

envsubst < .bootstrap/argocd.yaml | oc apply -f -
echo -n "Waiting for argocd server ready in openshift-gitops namespace"
while [ "Available" != "$(oc get argocd openshift-gitops -n openshift-gitops -ojsonpath='{.status.phase}')" ]; do
    echo -n '.'
    sleep 3
done
echo "argocd server is ready"

envsubst < .bootstrap/root-application.yaml | oc apply -f -