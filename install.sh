#!/bin/bash
set -e

if [ -f "/etc/appliance/state/install_support_ext_pack_done" ]; then
    echo "[INFO] Support ext pack already installed, skipping..."
    exit 1
else
    node=$(cubectl node list | wc -l)
    # 1. 更新 virtio-win driver v285
    echo "[INFO] Mounting ISO to /usr/share/virtio-win..."
    cubectl node -r control exec -p "rm /usr/share/virtio-win/*.iso"
    cp ./virtio-win-0.1.285.iso /usr/share/virtio-win/virtio-win.iso
    cubectl node -r control rsync /usr/share/virtio-win/virtio-win.iso
    cp rpm/virt-v2v-2.7.1-12.el9.x86_64.rpm /tmp/.
    cubectl node rsync /tmp/virt-v2v-2.7.1-12.el9.x86_64.rpm
    cubectl node -r control exec -p "dnf remove -y virt-v2v"
    cubectl node -r control exec -p "dnf localinstall -y /tmp/virt-v2v-2.7.1-12.el9.x86_64.rpm"

    # 2. 複製 ext-* 工具
    echo "[INFO] Copying ext-* tools to /usr/local/bin..."
    cp ./ext-* /usr/local/bin/
    cp ./rke2-generator /usr/local/bin/
    if (( node > 1 )); then
        git add /usr/local/bin/ext-change-port-ip
        git add /usr/local/bin/ext-change-route-ip
        git add /usr/local/bin/ext-change-vm-pass
        git add /usr/local/bin/ext-image-config
        git add /usr/local/bin/ext-snapshot-restore
        git add /usr/local/bin/ext-volume-config
        git add /usr/local/bin/ext-volume-migrate
        git add /usr/local/bin/rke2-generator
        hex_sdk git_push "Add support-ext-pack"
    fi

    # 3. update admin quota unlimit
    echo "[INFO] Update admin quota to unlimited"
    openstack quota set --cores -1 --ram -1 --instances -1 --volumes -1 --gigabytes -1 --key-pairs -1 admin

    # 4. Override number of enabled pcie ports & enable swtpm for libvirt
    echo "[INFO] Override number of enabled pcie ports & enable swtpm for libvirt"
    mkdir -p /etc/nova/nova.d/
    cp ./override/custom-nova.conf /etc/nova/nova.d/custom.conf
    cubectl node -r compute rsync /etc/nova/nova.d/custom.conf
    cubectl node -r compute exec -p "hex_config restart_nova"

    # 5. update rabbitmq configuration
    mkdir -p /etc/systemd/system/rabbitmq-server.service.d
    cp ./override/custom-rabbitmq.conf /etc/systemd/system/rabbitmq-server.service.d/custom.conf
    cubectl node -r control rsync /etc/systemd/system/rabbitmq-server.service.d/custom.conf
    cubectl node -r control exec -p "systemctl daemon-reload"
    cubectl node -r control exec -p "systemctl restart rabbitmq-server"

    # 6. update rabbitmq configuration
    sed -i 's/os_type=windows/os_type=windows --property hw_disk_bus=virtio/g' /usr/lib/hex_sdk/modules/sdk_os.sh
    if (( node > 1 )); then
        git add /usr/lib/hex_sdk/modules/sdk_os.sh
        hex_sdk git_push "Fix missing virtio disk bus property for windows image"
    fi

    # 7. Create marker file to indicate the installation is done
    echo "[INFO] Marking installation as done..." > /etc/appliance/state/install_support_ext_pack_done
    cubectl node -r control rsync /etc/appliance/state/install_support_ext_pack_done

    # reload
    cubectl node rsync /root/.bashrc
    source /root/.bashrc

fi

./hotfix.sh
