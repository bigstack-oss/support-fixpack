## fix rancher with keycloak
cubectl config commit rancher --force

## force delete pod
kubectl delete pod $POD -n $NS --force --grace-period=0

## clean up pods 
kubectl delete pod --field-selector=status.phase==Succeeded -A

## delete ImagePullBackOff pods
kubectl get pods -A | grep ImagePullBackOff | awk '{print $2 " --namespace=" $1}' | xargs -I {} sh -c 'kubectl delete pod {}'

