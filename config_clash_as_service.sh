set -e
function prepare_config(){
# 1. check clash installed
! (which clash > /dev/null 2>&1) && echo "clash not found in $PATH" && return 1

# 2. check if config offered
[ $# != 1 ] && echo "no clash config offered!
example:
         bash $(basename "$0") <your_config_path>" && return 1
defaultConfig=$1

# 3. copy and use config as default 
mkdir -p /etc/clash && cp $defaultConfig /etc/clash
}

function apply_clash_service(){
defaultConfig=$1    
service_template="# /etc/systemd/system/clash.service
   [Unit]
   Description=Clash Daemon

   [Service]
   Type=simple
   User=root
   ExecStart=clash -d /etc/clash/ -f /etc/clash/$defaultConfig
   Restart=on-failure
   RestartSec=3

   [Install]
   WantedBy=multi-user.target"

echo "$service_template" > /etc/systemd/system/clash.service
systemctl daemon-reload && systemctl restart clash
}

prepare_config "$@"
apply_clash_service "$@"

msg="Clash has installed successfully!

# check clash service status
systemctl status clash

# use from terminal
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890"
echo "$msg"
