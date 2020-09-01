#!/bin/bash
# 默认密码 kali:kali

if [[ $(cat /etc/hostname) != "kali" ]]; then
    echo Run on Kali Linux
    exit
fi

apt update
apt install -y git live-build cdebootstrap devscripts

# 下载 lb
git clone git://gitlab.com/kalilinux/build-scripts/live-build-config.git
cd live-build-config/

# 可选，使用国内镜像
echo http://mirrors.neusoft.edu.cn/kali/ > .mirror

# live 脚本
root=kali-config/common/includes.chroot/

mkdir -p $root/{root,etc/systemd/system}
cat > $root/etc/systemd/system/rc-local.service << EOF
[Unit]
Description=/etc/rc.local Compatibility
ConditionPathExists=/etc/rc.local

[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99

[Install]
WantedBy=multi-user.target
EOF

cat > $root/etc/rc.local << EOF
#!/bin/bash

mkdir -p /mnt/hgfs
vmhgfs-fuse -o allow_other .host:/ /mnt/hgfs

systemctl start ssh
EOF
chmod +x $root/etc/rc.local

mkdir -p $root/home/kali
cat > $root/home/kali/.bash_profile << EOF
echo
echo Server IP
echo
ip a | awk -F '[/ ]' '/inet / {print \$6}'
echo
EOF

mkdir -p $root/root/.ssh
cat > $root/root/.ssh/authorized_keys << EOF
YOUR_KEY
EOF

cat > $root/root/.vimrc << EOF
YOUR_VIMRC
EOF

cat > $root/root/.bashrc << EOF
YOUR_ROOTRC
EOF

> kali-config/common/includes.chroot/etc/motd

# 清理工作
mkdir -p kali-config/common/hooks/normal
cat > kali-config/common/hooks/normal/0999-configure-my-kali.chroot << EOF
#!/bin/bash

mkdir -p /mnt/hgfs

apt autoremove --purge -y fontconfig apparmor firmware-linux-free python2-minimal bind9-libs cpp-10 perl perl-modules-5.30
systemctl enable rc-local
EOF
chmod +x kali-config/common/hooks/normal/0999-configure-my-kali.chroot

# 添加需要的包
rm -f ./kali-config/common/package-lists/{firmware.list.chroot,linux-headers.list.chroot}

mkdir -p kali-config/variant-mimimal/package-lists/
cat > kali-config/variant-mimimal/package-lists/kali.list.chroot << EOF
kali-root-login
openssh-server
squashfs-tools
open-vm-tools
vim
curl
EOF

time ./build.sh -v -- \
    --zsync false \
    --firmware-binary false \
    --firmware-chroot false \
    --debian-installer false \
    --memtest none \
    --variant mimimal \
    --apt-options "-y -o Acquire::Retries=3" \
    --bootappend-live "boot=live components quiet splash noeject net.ifnames=0"


