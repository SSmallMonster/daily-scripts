set -e
function prepare_config_and_install(){
# 1. check minio installed
! (which minio > /dev/null 2>&1) && echo "minio not found in $PATH" && return 1

default_path=/var/run/minio
storage_path=""
# 2. check if config offered
if [ $# != 1 ];then
    echo "no storage path offered, use $default_path as default path"
    storage_path=$default_path
else
    storage_path=$1
fi

mkdir -p  $storage_path
apply_minio_service $storage_path
}

function apply_minio_service(){
storage_path=$1
service_template="# /etc/systemd/system/minio.service
   [Unit]
   Description=Minio Daemon

   [Service]
   Type=simple
   User=root
   ExecStart=$(which minio) server $storage_path --console-address :9001
   Restart=on-failure
   RestartSec=3

   [Install]
   WantedBy=multi-user.target
"

echo -n "$service_template" > /etc/systemd/system/minio.service
systemctl daemon-reload && systemctl restart minio
}

prepare_config_and_install "$@"

msg="Minio has installed successfully!

# check minio service status
systemctl status minio
"
echo -n "$msg"

start_time=$(date "+%Y-%m-%d %H:%M:%S")
sleep 1 && journalctl -u minio --no-pager --since "$start_time"
