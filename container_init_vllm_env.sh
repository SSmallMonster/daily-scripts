#! /bin/bash

# ==========================================
# Argument Parsing
# ==========================================
ENABLE_SSH=false

for arg in "$@"; do
  case $arg in
    --enable_ssh)
      ENABLE_SSH=true
      shift # Remove --enable_ssh from processing
      ;;
    *)
      # Unknown option
      ;;
  esac
done

# ==========================================
# Main System Setup
# ==========================================

# replace apt source
echo 'deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy main restricted universe multiverse

deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse

deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse

deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-security main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-security main restricted universe multiverse' > /etc/apt/sources.list
apt update

echo "Successfully replace apt source to mirrors.tuna.tsinghua.edu.cn."


# install python3-dev in global
apt install python3-dev -y
apt install vim -y
apt install iproute2 -y
apt install jq -y
apt install less -y
apt install net-tools -y
apt install lsof -y
apt install git -y

echo "Successfully install [ python3-dev vim ] packages."

# update ~/.bashrc
# Check if lines exist to avoid duplication if script runs twice
if ! grep -q "vllm_venv_312" ~/.bashrc; then
    echo "alias ac='source /data/models/vllm_venv_312/bin/activate'" >> ~/.bashrc
fi
if ! grep -q "cd /data/models/" ~/.bashrc; then
    echo 'cd /data/models/' >> ~/.bashrc
fi
if ! grep -q "HF_ENDPOINT" ~/.bashrc; then
    echo 'export HF_ENDPOINT=https://hf-mirror.com' >> ~/.bashrc
fi

echo 'set encoding=utf-8' > ~/.vimrc

# everything is ok, go devel...
if [ -f /data/models/vllm_venv_312/bin/activate ]; then
    source /data/models/vllm_venv_312/bin/activate
    # set pypi.tuna.tsinghua.edu.cn as pip source
    pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
    echo "source ~/.bashrc;ac to active python environment."
else
    echo "Warning: venv not found at /data/models/vllm_venv_312/bin/activate, skipping activation."
fi


# ==========================================
# SSH Function Definitions
# ==========================================

function do_install_sshd(){
    echo "Starting compilation and installation of s6 tools..."
    apt-get install -y openssh-server -y
    # init_sshd
    SKALIBS_VERSION=2.14.3.0
    EXECLINE_VERSION=2.9.6.1
    S6_VERSION=2.13.1.0

    cd /data/models/ && tar -xzf skalibs-${SKALIBS_VERSION}.tar.gz && \
        cd skalibs-${SKALIBS_VERSION} && \
        ./configure --prefix=/usr/local --enable-static --disable-shared --enable-static-libc && \
        make && make install

    cd /data/models/ && tar -xzf execline-${EXECLINE_VERSION}.tar.gz && \
        cd execline-${EXECLINE_VERSION} && \
        ./configure --prefix=/usr/local --enable-static --disable-shared --enable-static-libc && \
        make && make install

    cd /data/models/ && tar -xzf s6-${S6_VERSION}.tar.gz && \
        cd s6-${S6_VERSION} && \
        ./configure --prefix=/usr/local --enable-static --disable-shared --enable-static-libc && \
        make LDFLAGS="--static" && make install
}

function enable_sshd(){
    echo "Checking SSH configuration..."
    
    # Check if we need to install source compiled tools
    ! command -v s6-svc && do_install_sshd

    mkdir -p /etc/services.d/sshd/data/sshd_config
    mkdir -p /run/sshd
    
    # Configure SSHD
    # Ensure config file exists before sed
    if [ ! -f /etc/ssh/sshd_config ]; then
        apt-get install -y openssh-server
    fi
    
    sed -i 's/^#AuthorizedKeysFile.*/AuthorizedKeysFile .ssh\/authorized_keys .ssh\/drun\/authorized_keys/' /etc/ssh/sshd_config
    sed -i 's/^#StrictModes.*/StrictModes no/' /etc/ssh/sshd_config
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

    # Add Key
    mkdir -p ~/.ssh
    KEY_CONTENT='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDazvgG0OHLEt88dVsfZPy0bRghz1gNItfsSbEDE7GMDeoCn0xvTmGCaaJC7aNfhVxhS7V1gGUS5lDLDxCdXba9m78lv9DEsTqTGREnZTWe2KaZDTHfbkxSvFFUw+WIzM/NdPI2s+lgFq9obRe1x0fpxr/HVMRgSmVKdzDqCftro5i72B+1wXthzi7jYubeG8PBJg25iZ+wh177N2MjFgSYpuvs4C/gNQTRzBYSHGEOEZAi17aQGtqkZLs7NML3z+dnzz99poRqdMXtsDeczaRXjAAwommngvGGeaIFC0JYq+wB0T9f5sSKm89lowwvfJt2W3BH+lRYkQJMi9ZwV3WJwCVkRSg6RfX+syel8DpMFTGbhk5kX7dVD6v/m1PbAg5CeeReczJFQcM8YM95K663R/YMEQWk+knBl5zU9chkLBqIwqH//sy5BlHjK3osIg7DDYJZkMGV9YXh21DY781T4pi4UbXblpRMDLJqIXGEoGFofRVvoeyLb5arCPLplyE= mingming.zhou'
    
    if ! grep -q "mingming.zhou" ~/.ssh/authorized_keys 2>/dev/null; then
        echo "$KEY_CONTENT" >> ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
        echo "SSH Key added."
    fi

    # Supervisor Config
    if [ ! -f /etc/supervisor/supervisord.conf ]; then
        echo "Generating supervisord.conf..."
        mkdir -p /etc/supervisor/conf.d/
        echo_supervisord_conf > /etc/supervisor/supervisord.conf
    fi
        
    # Modify [include] section
    # 1. Uncomment [include]
    sed -i 's/^;\[include\]/[include]/' /etc/supervisor/supervisord.conf
    # 2. Update files path to /etc/supervisor/conf.d/*.conf
    sed -i 's|^;files = relative/directory/\*\.ini|files = /etc/supervisor/conf.d/*.conf|' /etc/supervisor/supervisord.conf
    
    echo "supervisord.conf configured to include /etc/supervisor/conf.d/*.conf"

    ssh_config="
[program:sshd]
command=/usr/sbin/sshd -D -f /etc/ssh/sshd_config
autostart=true
autorestart=true
stderr_logfile=/var/log/sshd.err.log
stdout_logfile=/var/log/sshd.out.log"
    
    # 使用双引号确保换行符保留
    echo "$ssh_config" > /etc/supervisor/conf.d/sshd.conf

    echo "Reloading Supervisor..."
    supervisorctl reload || supervisord -c /etc/supervisor/supervisord.conf
}

# ==========================================
# Conditional Logic
# ==========================================

# Apply Proxy
# 这个配置文件只有在使用 ssh 登录的时候创建 shell 才会生效，如果使用 k8s exec 登录 Pod的方式创建的 shell 不会自动导入这个环境变量
if [ -f /data/models/proxy.sh ]; then
    cp /data/models/proxy.sh /etc/profile.d/proxy.sh
fi

# EXECUTE SSH SETUP IF FLAG IS SET
if [ "$ENABLE_SSH" = true ]; then
    echo "Argument --enable_ssh detected. Proceeding with SSH installation and configuration."
    enable_sshd
else
    echo "SSH setup skipped. Use --enable_ssh to install and configure SSH."
fi

echo "Script execution completed."
