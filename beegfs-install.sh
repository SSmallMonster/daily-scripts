set -e
echo "start installing beegfs package..."

yum install wget ca-certificates -y

# disable selinux - this need to reboot machine
# systemctl stop firewalld && systemctl disable firewalld
# sed --follow-symlinks -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
# setenforce 0

yum list installed polkit > /dev/null 2>&1 && echo "removing polkit package..." && yum remove polkit
beegfsPackages="beegfs-mgmtd beegfs-meta beegfs-storage beegfs-helperd beegfs-client beegfs-utils"
for package in $beegfsPackages
do
  yum list installed $package > /dev/null 2>&1 && echo $package is installed || (echo $package is not installed && needInstall=true)
done

if [ ! -z "$needInstall" ];
then
    echo "failed" && exit 1
    # install beegfs rhel7 repo
    # wget -O /etc/yum.repos.d/beegfs-rhel8.repo https://www.beegfs.io/release/latest-stable/dists/beegfs-rhel8.repo
    wget -O /etc/yum.repos.d/beegfs-rhel7.repo https://www.beegfs.io/release/beegfs_7.2.9/dists/beegfs-rhel7.repo && \
    	yum makecache
    
    # beegfs components
    # - *mgmtd
    # - *meta
    # - *storage
    # - *client
    # - [optional] beegfs-helperd
    # - [optional] beegfs-utils
    
    yum install $beegfsPackages -y
fi
export PATH=$PATH:/opt/beegfs/sbin/

echo "start configuring beegfs service..."
configRoot=/opt/beegfs/etc && mkdir -p $configRoot && \
	echo "generated beegfs-mgmtd.conf in /etc/beegfs"

echo "deploying meta service..."
beegfs-setup-meta -f -p $configRoot -s 100 -m $(hostname) && \
	echo "updating /etc/beegfs/beegfs-meta.conf
		* sysMgmtdHost(manage) -> $(hostname)
		* nodeNumID -> 100"

echo "deploying storage service..."
storageRoot=/mnt/beegfs/storage && mkdir -p $storageRoot && \
	beegfs-setup-storage -f -p $storageRoot -s 100 -i 101 -m $(hostname)

echo "deploying client service..."
beegfs-setup-client -m $(hostname) && \
	echo "updating /etc/beegfs/beegfs-client.conf 
		* mount path(default): /mnt/beegfs"

systemctl restart beegfs-helperd beegfs-client

echo "beegfs has been deployed successfully!"
