set -e
# 检测系统架构
function detect_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64) echo "amd64" ;;
        aarch64) echo "arm64" ;;
        armv7l) echo "armv7" ;;
        *) echo "unsupported" ;;
    esac
}

# 安装 Clash
function install_clash() {
    if which clash > /dev/null 2>&1; then
        echo "Clash already installed"
        return 0
    fi

    echo "Installing Clash..."
    local arch=$(detect_arch)
    if [ "$arch" = "unsupported" ]; then
        echo "Unsupported architecture: $(uname -m)"
        return 1
    fi

    # 创建临时目录
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"

    # 下载 Clash
    local clash_url="https://github.com/Dreamacro/clash/releases/latest/download/clash-linux-${arch}-latest.gz"
    echo "Downloading Clash from: $clash_url"

    if ! curl -L -o clash.gz "$clash_url"; then
        echo "Failed to download Clash"
        rm -rf "$temp_dir"
        return 1
    fi

    # 解压并安装
    gunzip clash.gz
    chmod +x clash
    sudo mv clash /usr/local/bin/

    # 清理临时文件
    cd /
    rm -rf "$temp_dir"

    echo "Clash installed successfully"
}

# 处理订阅链接并生成配置文件
function process_subscription() {
    local config_url="$1"
    local config_file="/etc/clash/config.yaml"

    echo "Processing subscription from: $config_url"

    # 创建配置目录
    sudo mkdir -p /etc/clash

    # 下载订阅内容
    echo "Downloading subscription content..."
    local subscription_content=$(curl -s -L "$config_url")

    if [ $? -ne 0 ] || [ -z "$subscription_content" ]; then
        echo "Failed to download subscription content"
        return 1
    fi

    # 检查是否是 base64 编码的内容（订阅格式）
    if echo "$subscription_content" | base64 -d > /dev/null 2>&1; then
        echo "Processing subscription format (base64 encoded proxies)..."

        # 解码 base64 内容
        local decoded_content=$(echo "$subscription_content" | base64 -d)

        # 生成基础的 Clash 配置
        sudo tee "$config_file" > /dev/null <<EOF
port: 7890
socks-port: 7891
allow-lan: true
mode: Rule
log-level: info
external-controller: 127.0.0.1:9090

dns:
  enable: true
  listen: 0.0.0.0:53
  enhanced-mode: fake-ip
  nameserver:
    - 223.5.5.5
    - 8.8.8.8

proxies:
EOF

        # 处理每一行代理
        echo "$decoded_content" | while IFS= read -r line; do
            if [[ "$line" =~ ^ss:// ]]; then
                # 解析 SS 链接并转换为 Clash 格式
                process_ss_proxy "$line" >> "$config_file"
            fi
        done

        # 添加代理组和规则
        sudo tee -a "$config_file" > /dev/null <<EOF

proxy-groups:
  - name: "🚀 节点选择"
    type: select
    proxies:
      - "♻️ 自动选择"
      - DIRECT
EOF

        # 添加所有代理到选择组
        echo "$decoded_content" | while IFS= read -r line; do
            if [[ "$line" =~ ^ss:// ]]; then
                local name=$(echo "$line" | sed -n 's/.*#\(.*\)$/\1/p' | python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))")
                echo "      - \"$name\"" | sudo tee -a "$config_file" > /dev/null
            fi
        done

        sudo tee -a "$config_file" > /dev/null <<EOF
  - name: "♻️ 自动选择"
    type: url-test
    proxies:
EOF

        # 添加所有代理到自动选择组
        echo "$decoded_content" | while IFS= read -r line; do
            if [[ "$line" =~ ^ss:// ]]; then
                local name=$(echo "$line" | sed -n 's/.*#\(.*\)$/\1/p' | python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))")
                echo "      - \"$name\"" | sudo tee -a "$config_file" > /dev/null
            fi
        done

        sudo tee -a "$config_file" > /dev/null <<EOF
    url: 'http://www.gstatic.com/generate_204'
    interval: 300

rules:
  - DOMAIN-SUFFIX,google.com,🚀 节点选择
  - DOMAIN-SUFFIX,youtube.com,🚀 节点选择
  - DOMAIN-SUFFIX,facebook.com,🚀 节点选择
  - DOMAIN-SUFFIX,twitter.com,🚀 节点选择
  - DOMAIN-SUFFIX,instagram.com,🚀 节点选择
  - DOMAIN-SUFFIX,telegram.org,🚀 节点选择
  - DOMAIN-KEYWORD,github,🚀 节点选择
  - GEOIP,CN,DIRECT
  - MATCH,🚀 节点选择
EOF

    elif echo "$subscription_content" | grep -q "proxies:"; then
        # 如果已经是 YAML 格式的配置文件
        echo "Found YAML config format, saving directly..."
        echo "$subscription_content" | sudo tee "$config_file" > /dev/null
    else
        echo "Unknown subscription format"
        return 1
    fi

    echo "Config generated at: $config_file"
}

# 处理单个 SS 代理
function process_ss_proxy() {
    local ss_url="$1"

    # 提取服务器信息
    local encoded_part=$(echo "$ss_url" | sed 's/ss:\/\///' | cut -d'@' -f1)
    local server_part=$(echo "$ss_url" | sed 's/ss:\/\///' | cut -d'@' -f2 | cut -d'#' -f1)
    local name_part=$(echo "$ss_url" | sed -n 's/.*#\(.*\)$/\1/p')

    # 解码认证信息
    local auth_info=$(echo "$encoded_part" | base64 -d 2>/dev/null)
    local method=$(echo "$auth_info" | cut -d':' -f1)
    local password=$(echo "$auth_info" | cut -d':' -f2)

    # 解析服务器和端口
    local server=$(echo "$server_part" | cut -d':' -f1)
    local port=$(echo "$server_part" | cut -d':' -f2)

    # 解码名称
    local name=$(echo "$name_part" | python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))" 2>/dev/null || echo "$name_part")

    # 输出 Clash 格式
    cat <<EOF
  - name: "$name"
    type: ss
    server: $server
    port: $port
    cipher: $method
    password: "$password"
EOF
}

function prepare_config(){
    # 1. 检查参数
    if [ $# != 1 ]; then
        echo "Usage: bash $(basename "$0") <config_download_url>"
        echo "Example: bash $(basename "$0") https://example.com/clash-config.yaml"
        return 1
    fi

    local config_url="$1"

    # 2. 安装 Clash（如果需要）
    install_clash || return 1

    # 3. 下载配置文件
    download_config "$config_url" || return 1

    clash=$(which clash)
}

function apply_clash_service(){
service_template="# /etc/systemd/system/clash.service
   [Unit]
   Description=Clash Daemon

   [Service]
   Type=simple
   User=root
   ExecStart=$clash -d /etc/clash/ -f /etc/clash/config.yaml
   Restart=on-failure
   RestartSec=3

   [Install]
   WantedBy=multi-user.target"

echo "$service_template" | sudo tee /etc/systemd/system/clash.service > /dev/null
sudo systemctl daemon-reload && sudo systemctl enable clash && sudo systemctl restart clash
}

prepare_config "$@"
apply_clash_service

msg="🎉 Clash has been installed and configured successfully!

📊 Check clash service status:
   sudo systemctl status clash

🌐 Set proxy in your terminal:
   export https_proxy=http://127.0.0.1:7890
   export http_proxy=http://127.0.0.1:7890
   export all_proxy=socks5://127.0.0.1:7890

🔧 Clash management commands:
   sudo systemctl start clash    # 启动服务
   sudo systemctl stop clash     # 停止服务
   sudo systemctl restart clash  # 重启服务
   sudo systemctl status clash   # 查看状态

📁 Config file location: /etc/clash/config.yaml
🌍 Web UI (if enabled): http://127.0.0.1:9090"

echo "$msg"
