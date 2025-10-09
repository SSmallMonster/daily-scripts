#! /bin/bash

# 通过使用 rpmrebuild 来重新构建 RPM 包
# 需要以下工具/文件来辅助完成

# - rpmrebuild
# https://rpmfind.net/linux/rpm2html/search.php?query=rpmrebuild

# - replacefile.sh
# https://sourceforge.net/p/rpmrebuild/git/ci/master/tree/src/plugins/replacefile.sh#l6

# 开始替换文件之前，需要将新的文件准备好放在一个路径，示例中 /root/lustre-261-packages/dkms.conf 是需要替换的新文件。然后将下载好的 replacefile.sh 路径指定好
rpmrebuild -v --debug --package --change-files "./replacefile.sh -d usr/src/lustre-zfs-2.16.1/dkms.conf -s /root/lustre-261-packages/dkms.conf" lustre-zfs-dkms-2.16.1-1.el9.noarch.rpm

# 注意
# -d 参数一定是旧文件在 rpm 包里面的相对路径，可以通过 rpm -qf 查看已经安装好的文件或者 rpm -ql 去查看 rpm 包里面的文件路径，记得把根路径 / 拿掉，否则会出现文件替换不成功问题
# -s 参数是新文件的绝对路径

# 调试
# 如果不确定是不是被正确替换了，可以通过 rpm2cpio ../lustre-zfs-dkms-2.16.1-1.el9.noarch.rpm | cpio -idmv 来解压 rpm 包查看文件的内容
