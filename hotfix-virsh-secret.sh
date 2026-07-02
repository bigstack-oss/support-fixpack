for node in $(cubectl node list -r compute | awk -F',' '{print $1}'); do
    echo "=== Deploying to $node ==="
    ssh $node << 'EOF'

if [ ! -f /etc/cinder/cinder.conf ]; then
    echo "Error: /etc/cinder/cinder.conf not found on $HOSTNAME"
    exit 1
fi

UUID=$(grep -m 1 "rbd_secret_uuid" /etc/cinder/cinder.conf | awk -F'=' '{print $2}' | tr -d '[:space:]')

if [ -z "$UUID" ]; then
    echo "Error: Could not find rbd_secret_uuid on $HOSTNAME"
    exit 1
fi
echo "Found UUID: $UUID"

if virsh secret-list | grep -E -q "($UUID)"; then
    echo "Secret already exists on $HOSTNAME. Skipping..."
    exit 0
fi

echo "Defining the virsh secret..."
cat <<SECRETOF | virsh secret-define --file /dev/stdin
<secret ephemeral='no' private='no'>
  <uuid>${UUID}</uuid>
  <usage type='ceph'>
    <name>client.admin secret</name>
  </usage>
</secret>
SECRETOF

echo "Setting the secret value from Ceph..."
CEPH_KEY=$(ceph auth get-key client.admin 2>/dev/null | tr -d '\n ')

if [ -z "$CEPH_KEY" ]; then
    echo "Error: Failed to retrieve key for client.admin from Ceph"
    exit 1
fi

if virsh secret-set-value --secret "$UUID" --base64 "$CEPH_KEY"; then
    echo "Success on $HOSTNAME!"
else
    echo "Error: Failed to set virsh secret value on $HOSTNAME"
    exit 1
fi

EOF
done
