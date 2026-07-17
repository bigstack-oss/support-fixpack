# v3.1.0 fixpack Download 
- https://s3.bigstack.co/downloads/fixpack/support-fixpack-310.zip

# hotfix.sh
- 修正 offline 環境無法取得 OCI image的問題

# hotfix-virsh-secret.sh
- VM 建立 Error，Volume 無法掛到 VM，原因是 virsh secret-list 內的 uuid 是錯的，沒對上 cinder.conf 的 rbd_secret_uuid

# HELP
## check offline repo
```
curl -k -s "http://localhost:5080/v2/_catalog" | jq ".repositories | length"
```

## fix rancher with keycloak
```
cubectl config commit rancher --force
```
## force delete pod
```
kubectl delete pod $POD -n $NS --force --grace-period=0
```
## clean up pods 
```
kubectl delete pod --field-selector=status.phase==Succeeded -A
```
## delete ImagePullBackOff pods
```
kubectl get pods -A | grep ImagePullBackOff | awk '{print $2 " --namespace=" $1}' | xargs -I {} sh -c 'kubectl delete pod {}'
```