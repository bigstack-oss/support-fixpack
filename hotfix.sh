#!/bin/bash

# Copy images to all control nodes
cubectl node list -r control | while IFS=',' read -r hostname rest; do
    echo "---------------------------------------"
    echo "Copying images to control node ${hostname}..."
    skopeo copy docker-archive:docker-images/rancher.tar docker://$hostname:5080/rancher/rancher:v2.11.2 --dest-tls-verify=false
    skopeo copy docker-archive:docker-images/rancher-webhook.tar docker://$hostname:5080/rancher/rancher-webhook:v0.7.2 --dest-tls-verify=false
    skopeo copy docker-archive:docker-images/shell.tar docker://$hostname:5080/rancher/shell:v0.4.1 --dest-tls-verify=false
    skopeo copy docker-archive:docker-images/system-upgrade-controller.tar docker://$hostname:5080/rancher/system-upgrade-controller:v0.15.2 --dest-tls-verify=false
    skopeo copy docker-archive:docker-images/machine.tar docker://$hostname:5080/rancher/machine:v0.15.0-rancher127 --dest-tls-verify=false
    skopeo copy docker-archive:docker-images/rancher-fleet.tar docker://$hostname:5080/rancher/fleet:v0.12.3 --dest-tls-verify=false
    skopeo copy docker-archive:docker-images/rancher-mirrored-cluster-api-controller.tar docker://$hostname:5080/rancher/mirrored-cluster-api-controller:v1.9.5 --dest-tls-verify=false
    skopeo copy docker-archive:docker-images/rancher-fleet-agent.tar docker://$hostname:5080/rancher/fleet-agent:v0.12.3 --dest-tls-verify=false
    skopeo copy docker-archive:docker-images/rancher-kubectl.tar docker://$hostname:5080/rancher/kubectl:v1.32.2 --dest-tls-verify=false
    skopeo copy docker-archive:docker-images/rancher-agent.tar docker://$hostname:5080/rancher/rancher-agent:v2.11.2 --dest-tls-verify=false
    skopeo copy docker-archive:docker-images/csi-provisioner.tar docker://$hostname:5080/sig-storage/csi-provisioner:v5.0.1 --dest-tls-verify=false
    skopeo copy docker-archive:docker-images/csi-resizer.tar docker://$hostname:5080/sig-storage/csi-resizer:v1.11.1 --dest-tls-verify=false
    skopeo copy docker-archive:docker-images/csi-snapshotter.tar docker://$hostname:5080/sig-storage/csi-snapshotter:v8.2.0 --dest-tls-verify=false
    skopeo copy docker-archive:docker-images/csi-attacher.tar docker://$hostname:5080/sig-storage/csi-attacher:v4.6.1 --dest-tls-verify=false
done

# Rollout Services
echo "---------------------------------------"
echo "Rolling out Rancher services..."
kubectl rollout restart deployment/rancher -n cattle-system

echo "---------------------------------------"
echo "Rolling out Rancher webhook service..."
kubectl rollout restart deployment/rancher-webhook -n cattle-system

echo "---------------------------------------"
echo "Turn off Ceph FS CSI drivers ..."
kubectl patch daemonset ceph-csi-cephfs-nodeplugin -n ceph-csi-cephfs --type='merge' -p '{"spec":{"template":{"spec":{"nodeSelector":{"non-existing":"true"}}}}}'
kubectl scale deployment ceph-csi-cephfs-provisioner -n ceph-csi-cephfs --replicas=0

echo "---------------------------------------"
echo "Turn off Ceph RBD CSI drivers ..."
kubectl patch daemonset ceph-csi-rbd-nodeplugin -n ceph-csi-rbd --type='merge' -p '{"spec":{"template":{"spec":{"nodeSelector":{"non-existing":"true"}}}}}'
kubectl scale deployment ceph-csi-rbd-provisioner -n ceph-csi-rbd --replicas=0

echo "---------------------------------------"
echo "Rolling out..."
kubectl get pods -A | grep ImagePullBackOff | awk '{print "kubectl delete pod " $2 " -n " $1 " --force --grace-period=0"}'

echo "---------------------------------------"
echo "Clean up..."
for pod in $(kubectl get pods -n cattle-system | grep helm-operation | awk '{print $1}'); do
    kubectl delete pod $pod -n cattle-system --force --grace-period=0; 
done

echo "---------------------------------------"
echo "update appctl"
cp appctl /usr/local/bin/appctl
cubectl node -r control rsync /usr/local/bin/appctl

echo "---------------------------------------"
echo "fix terraform"
mkdir -p /var/lib/terraform/patched-registry
tar -xzf ./providers.tar.gz -C /var/lib/terraform/patched-registry
cubectl node -r control rsync /var/lib/terraform/patched-registry
cp ./override.tfrc /etc/cube/cos/terraform/configs/override.tfrc
cubectl node -r control rsync /etc/cube/cos/terraform/configs/override.tfrc
cp ./override.tfrc /root/.terraformrc
cubectl node -r control rsync /root/.terraformrc
cubectl node -r control exec -p "mv /var/lib/terraform/.terraform.lock.hcl /var/lib/terraform/.terraform.lock.hcl-bak"
cubectl node -r control exec -p "terraform -chdir=/var/lib/terraform init -upgrade"

echo "---------------------------------------"
echo "clean up succeeded pods..."
kubectl get pods -A | grep ImagePullBackOff | awk '{print $2 " --namespace=" $1}' | xargs -I {} sh -c 'kubectl delete pod {}'
sleep 60
kubectl delete pod --field-selector=status.phase==Succeeded -A
kubectl get pod -A
echo "patch completed"

