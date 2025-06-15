#!/bin/bash
###############################################################################
#
# OpenList Interactive Manager Script
#
# Version: 1.2.0
# Last Updated: 2025-06-15
#
# Description: 
#   An interactive management script for OpenList
#   Download first, then execute - no direct pipe installation
#
# Requirements:
#   - Linux with systemd
#   - Root privileges for installation
#   - curl, tar
#   - x86_64 or arm64 architecture
#
# Usage:
#   curl -fsSL "https://raw.githubusercontent.com/ypq123456789/openlist/refs/heads/main/openlist.sh" -o openlist.sh
#   chmod +x openlist.sh
#   sudo ./openlist.sh
#
###############################################################################

# 错误处理函数
handle_error() {
    local exit_code=$1
    local error_msg=$2
    echo -e "${RED_COLOR}错误：${error_msg}${RES}"
    read -p "按回车键继续..."
    return ${exit_code}
}

# 检查必要命令
check_dependencies() {
    local missing_deps=()
    
    if ! command -v curl >/dev/null 2>&1; then
        missing_deps+=("curl")
    fi
    
    if ! command -v tar >/dev/null 2>&1; then
        missing_deps+=("tar")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED_COLOR}缺少必要的依赖包：${missing_deps[*]}${RES}"
        echo -e "${YELLOW_COLOR}请先安装这些依赖包：${RES}"
        echo -e "Ubuntu/Debian: sudo apt update && sudo apt install curl tar"
        echo -e "CentOS/RHEL: sudo yum install curl tar"
        read -p "按回车键退出..."
        exit 1
    fi
}

# 配置部分
GITHUB_REPO="OpenListTeam/OpenList"
VERSION_TAG="beta"
VERSION_FILE="/opt/openlist/.version"

# 颜色配置
RED_COLOR='\e[1;31m'
GREEN_COLOR='\e[1;32m'
YELLOW_COLOR='\e[1;33m'
BLUE_COLOR='\e[1;34m'
CYAN_COLOR='\e[1;36m'
PURPLE_COLOR='\e[1;35m'
RES='\e[0m'

# 获取已安装的路径
get_installed_path() {
    if [ -f "/etc/systemd/system/openlist.service" ]; then
        installed_path=$(grep "WorkingDirectory=" /etc/systemd/system/openlist.service | cut -d'=' -f2)
        if [ -f "$installed_path/openlist" ]; then
            echo "$installed_path"
            return 0
        fi
    fi
    echo "/opt/openlist"
}

# 设置安装路径
INSTALL_PATH=$(get_installed_path)

# 获取平台架构
get_architecture() {
    if command -v arch >/dev/null 2>&1; then
        platform=$(arch)
    else
        platform=$(uname -m)
    fi

    case "$platform" in
        x86_64)
            echo "amd64"
            ;;
        aarch64)
            echo "arm64"
            ;;
        *)
            echo "UNKNOWN"
            ;;
    esac
}

ARCH=$(get_architecture)

# 检查系统要求
check_system_requirements() {
    echo -e "${BLUE_COLOR}正在检查系统要求...${RES}"
    
    # 检查操作系统
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED_COLOR}错误：需要 root 权限运行此脚本${RES}"
        echo -e "${YELLOW_COLOR}请使用: sudo ./openlist.sh${RES}"
        read -p "按回车键退出..."
        exit 1
    fi
    
    # 检查架构
    if [ "$ARCH" == "UNKNOWN" ]; then
        echo -e "${RED_COLOR}错误：不支持的系统架构 $(uname -m)${RES}"
        echo -e "${YELLOW_COLOR}目前仅支持 x86_64 和 arm64 架构${RES}"
        read -p "按回车键退出..."
        exit 1
    fi
    
    # 检查 systemd
    if ! command -v systemctl >/dev/null 2>&1; then
        echo -e "${RED_COLOR}错误：系统不支持 systemd${RES}"
        echo -e "${YELLOW_COLOR}本脚本需要 systemd 支持${RES}"
        read -p "按回车键退出..."
        exit 1
    fi
    
    # 检查依赖
    check_dependencies
    
    echo -e "${GREEN_COLOR}系统检查通过！${RES}"
    sleep 1
}

# 显示欢迎信息
show_welcome() {
    clear
    echo -e "${CYAN_COLOR}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    OpenList 管理脚本                         ║"
    echo "║                                                              ║"
    echo "║                    Interactive Manager                       ║"
    echo "║                                                              ║"
    echo "║                        Version 1.2.0                        ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RES}"
    echo
    echo -e "${BLUE_COLOR}系统信息：${RES}"
    echo -e "操作系统: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo -e "架构: $(uname -m)"
    echo -e "内核: $(uname -r)"
    echo
    sleep 2
}

# 获取可用版本
get_available_versions() {
    echo -e "${BLUE_COLOR}正在获取可用版本...${RES}"
    
    local versions
    if command -v jq >/dev/null 2>&1; then
        versions=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases" | jq -r '.[].tag_name' 2>/dev/null)
    else
        versions=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
    fi
    
    if [ ! -z "$versions" ]; then
        echo -e "${GREEN_COLOR}可用版本：${RES}"
        echo "$versions" | head -10
        return 0
    else
        echo -e "${YELLOW_COLOR}无法获取版本信息，将使用默认 beta 版本${RES}"
        return 1
    fi
}

# 选择版本
select_version() {
    echo -e "${PURPLE_COLOR}请选择要使用的版本：${RES}"
    echo -e "${GREEN_COLOR}1${RES} - beta (推荐，最新功能)"
    echo -e "${GREEN_COLOR}2${RES} - 查看所有可用版本"
    echo -e "${GREEN_COLOR}3${RES} - 手动输入版本标签"
    echo -e "${GREEN_COLOR}4${RES} - 返回主菜单"
    echo
    
    while true; do
        read -p "请输入选项 [1-4]: " version_choice
        
        case "$version_choice" in
            1)
                VERSION_TAG="beta"
                echo -e "${GREEN_COLOR}已选择 beta 版本${RES}"
                break
                ;;
            2)
                echo
                if get_available_versions; then
                    echo
                    read -p "请输入要使用的版本标签: " custom_version
                    if [ ! -z "$custom_version" ]; then
                        VERSION_TAG="$custom_version"
                        echo -e "${GREEN_COLOR}已选择版本：$VERSION_TAG${RES}"
                    else
                        VERSION_TAG="beta"
                        echo -e "${YELLOW_COLOR}输入为空，使用 beta 版本${RES}"
                    fi
                else
                    VERSION_TAG="beta"
                    echo -e "${YELLOW_COLOR}获取版本失败，使用 beta 版本${RES}"
                fi
                break
                ;;
            3)
                read -p "请输入版本标签 (如: beta, v1.0.0): " custom_version
                if [ ! -z "$custom_version" ]; then
                    VERSION_TAG="$custom_version"
                    echo -e "${GREEN_COLOR}已选择版本：$VERSION_TAG${RES}"
                else
                    VERSION_TAG="beta"
                    echo -e "${YELLOW_COLOR}输入为空，使用 beta 版本${RES}"
                fi
                break
                ;;
            4)
                return 1
                ;;
            *)
                echo -e "${RED_COLOR}无效选项，请重新选择${RES}"
                ;;
        esac
    done
    
    sleep 1
    return 0
}

# 设置代理
setup_proxy() {
    echo -e "${BLUE_COLOR}网络设置${RES}"
    echo -e "${GREEN_COLOR}是否使用 GitHub 代理？${RES}"
    echo -e "${YELLOW_COLOR}代理可以加速下载，推荐国内用户使用${RES}"
    echo
    echo -e "${GREEN_COLOR}1${RES} - 不使用代理（默认）"
    echo -e "${GREEN_COLOR}2${RES} - 使用 ghproxy.com"
    echo -e "${GREEN_COLOR}3${RES} - 使用 mirror.ghproxy.com"
    echo -e "${GREEN_COLOR}4${RES} - 自定义代理地址"
    echo
    
    while true; do
        read -p "请输入选项 [1-4]: " proxy_choice
        
        case "$proxy_choice" in
            1)
                GH_PROXY=""
                echo -e "${GREEN_COLOR}已选择：不使用代理${RES}"
                break
                ;;
            2)
                GH_PROXY="https://ghproxy.com/"
                echo -e "${GREEN_COLOR}已选择：ghproxy.com${RES}"
                break
                ;;
            3)
                GH_PROXY="https://mirror.ghproxy.com/"
                echo -e "${GREEN_COLOR}已选择：mirror.ghproxy.com${RES}"
                break
                ;;
            4)
                echo -e "${YELLOW_COLOR}代理地址格式：https://example.com/${RES}"
                read -p "请输入代理地址: " custom_proxy
                if [[ "$custom_proxy" =~ ^https://.*[/]$ ]]; then
                    GH_PROXY="$custom_proxy"
                    echo -e "${GREEN_COLOR}已设置代理：$GH_PROXY${RES}"
                else
                    echo -e "${RED_COLOR}代理地址格式错误，使用默认设置${RES}"
                    GH_PROXY=""
                fi
                break
                ;;
            *)
                echo -e "${RED_COLOR}无效选项，请重新选择${RES}"
                ;;
        esac
    done
    
    sleep 1
}

# 下载文件
download_file() {
    local url="$1"
    local output="$2"
    local max_retries=3
    local retry_count=0
    
    echo -e "${BLUE_COLOR}开始下载...${RES}"
    echo -e "URL: $url"
    
    while [ $retry_count -lt $max_retries ]; do
        echo -e "${YELLOW_COLOR}尝试 $((retry_count + 1))/$max_retries${RES}"
        
        if curl -L --progress-bar --connect-timeout 10 --retry 3 --retry-delay 3 "$url" -o "$output"; then
            if [ -f "$output" ] && [ -s "$output" ]; then
                if ! grep -q "Not Found" "$output" 2>/dev/null; then
                    echo -e "${GREEN_COLOR}下载成功！${RES}"
                    return 0
                else
                    echo -e "${RED_COLOR}文件不存在${RES}"
                    rm -f "$output"
                    return 1
                fi
            fi
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            echo -e "${YELLOW_COLOR}下载失败，3秒后重试...${RES}"
            sleep 3
        fi
    done
    
    echo -e "${RED_COLOR}下载失败，已重试 $max_retries 次${RES}"
    return 1
}

# 安装检查
check_install() {
    if [ -f "$INSTALL_PATH/openlist" ]; then
        echo -e "${YELLOW_COLOR}检测到已安装的 OpenList${RES}"
        echo -e "安装路径: $INSTALL_PATH"
        echo
        echo -e "${GREEN_COLOR}1${RES} - 覆盖安装"
        echo -e "${GREEN_COLOR}2${RES} - 取消安装"
        echo
        
        while true; do
            read -p "请选择 [1-2]: " install_choice
            case "$install_choice" in
                1)
                    echo -e "${GREEN_COLOR}准备覆盖安装...${RES}"
                    systemctl stop openlist 2>/dev/null
                    sleep 2
                    return 0
                    ;;
                2)
                    echo -e "${YELLOW_COLOR}已取消安装${RES}"
                    return 1
                    ;;
                *)
                    echo -e "${RED_COLOR}无效选项${RES}"
                    ;;
            esac
        done
    fi
    
    # 准备安装目录
    echo -e "${BLUE_COLOR}准备安装目录...${RES}"
    
    if [ ! -d "$(dirname "$INSTALL_PATH")" ]; then
        mkdir -p "$(dirname "$INSTALL_PATH")" || {
            handle_error 1 "无法创建目录 $(dirname "$INSTALL_PATH")"
            return 1
        }
    fi
    
    if [ ! -d "$INSTALL_PATH" ]; then
        mkdir -p "$INSTALL_PATH" || {
            handle_error 1 "无法创建安装目录 $INSTALL_PATH"
            return 1
        }
    fi
    
    echo -e "${GREEN_COLOR}安装目录准备完成：$INSTALL_PATH${RES}"
    return 0
}

# 安装 OpenList
install_openlist() {
    echo -e "${CYAN_COLOR}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                       安装 OpenList                         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RES}"
    
    # 检查安装
    if ! check_install; then
        read -p "按回车键继续..."
        return
    fi
    
    # 选择版本
    if ! select_version; then
        return
    fi
    
    # 设置代理
    setup_proxy
    
    # 构建下载地址
    local download_url="${GH_PROXY}https://github.com/${GITHUB_REPO}/releases/download/${VERSION_TAG}/openlist-linux-$ARCH.tar.gz"
    
    echo -e "${BLUE_COLOR}安装信息：${RES}"
    echo -e "版本: $VERSION_TAG"
    echo -e "架构: $ARCH"
    echo -e "安装路径: $INSTALL_PATH"
    echo -e "代理: ${GH_PROXY:-无}"
    echo
    
    read -p "确认安装？[Y/n]: " confirm
    case "${confirm:-y}" in
        [yY]|"")
            ;;
        *)
            echo -e "${YELLOW_COLOR}已取消安装${RES}"
            read -p "按回车键继续..."
            return
            ;;
    esac
    
    # 下载
    if ! download_file "$download_url" "/tmp/openlist.tar.gz"; then
        echo -e "${RED_COLOR}下载失败！${RES}"
        read -p "按回车键继续..."
        return
    fi
    
    # 验证文件
    echo -e "${BLUE_COLOR}验证文件完整性...${RES}"
    if ! tar -tf /tmp/openlist.tar.gz >/dev/null 2>&1; then
        echo -e "${RED_COLOR}文件损坏或格式错误${RES}"
        rm -f /tmp/openlist.tar.gz
        read -p "按回车键继续..."
        return
    fi
    
    # 解压
    echo -e "${BLUE_COLOR}解压文件...${RES}"
    if ! tar zxf /tmp/openlist.tar.gz -C "$INSTALL_PATH/"; then
        echo -e "${RED_COLOR}解压失败${RES}"
        rm -f /tmp/openlist.tar.gz
        read -p "按回车键继续..."
        return
    fi
    
    # 验证安装
    if [ ! -f "$INSTALL_PATH/openlist" ]; then
        echo -e "${RED_COLOR}安装失败，未找到可执行文件${RES}"
        read -p "按回车键继续..."
        return
    fi
    
    # 设置权限
    chmod +x "$INSTALL_PATH/openlist"
    
    # 创建数据目录
    mkdir -p "$INSTALL_PATH/data"
    
    # 记录版本信息
    echo "$VERSION_TAG" > "$VERSION_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S')" >> "$VERSION_FILE"
    
    # 创建服务
    echo -e "${BLUE_COLOR}创建系统服务...${RES}"
    cat > /etc/systemd/system/openlist.service << EOF
[Unit]
Description=OpenList service
Wants=network.target
After=network.target network.service

[Service]
Type=simple
WorkingDirectory=$INSTALL_PATH
ExecStart=$INSTALL_PATH/openlist
KillMode=process
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable openlist
    
    # 启动服务
    echo -e "${BLUE_COLOR}启动服务...${RES}"
    systemctl start openlist
    
    # 等待启动
    sleep 3
    
    # 清理临时文件
    rm -f /tmp/openlist.tar.gz
    
    # 显示安装结果
    echo -e "${GREEN_COLOR}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    OpenList 安装成功！                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RES}"
    
    # 获取IP地址
    local local_ip=$(ip addr show | grep -w inet | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1 | head -n1)
    
    echo -e "${BLUE_COLOR}访问信息：${RES}"
    echo -e "本地访问: http://127.0.0.1:5244/"
    echo -e "局域网访问: http://${local_ip}:5244/"
    echo
    echo -e "${BLUE_COLOR}默认账号：${RES}admin"
    echo -e "${BLUE_COLOR}初始密码：${RES}请查看服务日志获取"
    echo
    echo -e "${YELLOW_COLOR}查看密码命令：${RES}sudo journalctl -u openlist | grep 'initial password'"
    echo
    
    read -p "按回车键继续..."
}

# 更新 OpenList
update_openlist() {
    echo -e "${CYAN_COLOR}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                       更新 OpenList                         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RES}"
    
    if [ ! -f "$INSTALL_PATH/openlist" ]; then
        echo -e "${RED_COLOR}错误：未找到已安装的 OpenList${RES}"
        echo -e "${YELLOW_COLOR}请先安装 OpenList${RES}"
        read -p "按回车键继续..."
        return
    fi
    
    # 显示当前版本
    if [ -f "$VERSION_FILE" ]; then
        echo -e "${BLUE_COLOR}当前版本信息：${RES}"
        cat "$VERSION_FILE"
        echo
    fi
    
    # 获取版本标签
    if [ -f "$VERSION_FILE" ]; then
        VERSION_TAG=$(head -n1 "$VERSION_FILE" 2>/dev/null || echo "beta")
    else
        VERSION_TAG="beta"
    fi
    
    echo -e "${BLUE_COLOR}当前使用版本：${RES}$VERSION_TAG"
    echo
    echo -e "${GREEN_COLOR}1${RES} - 更新到最新版本"
    echo -e "${GREEN_COLOR}2${RES} - 选择其他版本"
    echo -e "${GREEN_COLOR}3${RES} - 返回主菜单"
    echo
    
    while true; do
        read -p "请选择 [1-3]: " update_choice
        case "$update_choice" in
            1)
                break
                ;;
            2)
                if ! select_version; then
                    return
                fi
                break
                ;;
            3)
                return
                ;;
            *)
                echo -e "${RED_COLOR}无效选项${RES}"
                ;;
        esac
    done
    
    # 设置代理
    setup_proxy
    
    # 构建下载地址
    local download_url="${GH_PROXY}https://github.com/${GITHUB_REPO}/releases/download/${VERSION_TAG}/openlist-linux-$ARCH.tar.gz"
    
    echo -e "${BLUE_COLOR}更新信息：${RES}"
    echo -e "版本: $VERSION_TAG"
    echo -e "代理: ${GH_PROXY:-无}"
    echo
    
    read -p "确认更新？[Y/n]: " confirm
    case "${confirm:-y}" in
        [yY]|"")
            ;;
        *)
            echo -e "${YELLOW_COLOR}已取消更新${RES}"
            read -p "按回车键继续..."
            return
            ;;
    esac
    
    # 停止服务
    echo -e "${BLUE_COLOR}停止服务...${RES}"
    systemctl stop openlist
    
    # 备份
    echo -e "${BLUE_COLOR}创建备份...${RES}"
    cp "$INSTALL_PATH/openlist" "/tmp/openlist.bak"
    
    # 下载新版本
    if ! download_file "$download_url" "/tmp/openlist.tar.gz"; then
        echo -e "${RED_COLOR}下载失败，正在恢复...${RES}"
        mv "/tmp/openlist.bak" "$INSTALL_PATH/openlist"
        systemctl start openlist
        read -p "按回车键继续..."
        return
    fi
    
    # 解压
    echo -e "${BLUE_COLOR}安装新版本...${RES}"
    if ! tar zxf /tmp/openlist.tar.gz -C "$INSTALL_PATH/"; then
        echo -e "${RED_COLOR}解压失败，正在恢复...${RES}"
        mv "/tmp/openlist.bak" "$INSTALL_PATH/openlist"
        systemctl start openlist
        rm -f /tmp/openlist.tar.gz
        read -p "按回车键继续..."
        return
    fi
    
    # 验证更新
    if [ ! -f "$INSTALL_PATH/openlist" ]; then
        echo -e "${RED_COLOR}更新失败，正在恢复...${RES}"
        mv "/tmp/openlist.bak" "$INSTALL_PATH/openlist"
        systemctl start openlist
        read -p "按回车键继续..."
        return
    fi
    
    # 设置权限
    chmod +x "$INSTALL_PATH/openlist"
    
    # 更新版本信息
    echo "$VERSION_TAG" > "$VERSION_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S')" >> "$VERSION_FILE"
    
    # 启动服务
    echo -e "${BLUE_COLOR}启动服务...${RES}"
    systemctl start openlist
    
    # 清理文件
    rm -f /tmp/openlist.tar.gz /tmp/openlist.bak
    
    echo -e "${GREEN_COLOR}OpenList 更新成功！${RES}"
    read -p "按回车键继续..."
}

# 卸载 OpenList
uninstall_openlist() {
    echo -e "${CYAN_COLOR}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                       卸载 OpenList                         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RES}"
    
    if [ ! -f "$INSTALL_PATH/openlist" ]; then
        echo -e "${RED_COLOR}错误：未找到已安装的 OpenList${RES}"
        read -p "按回车键继续..."
        return
    fi
    
    echo -e "${RED_COLOR}警告：卸载将删除以下内容：${RES}"
    echo -e "• OpenList 程序文件"
    echo -e "• 配置文件和数据库"
    echo -e "• 系统服务"
    echo -e "• 所有用户数据"
    echo
    echo -e "${YELLOW_COLOR}此操作不可逆！${RES}"
    echo
    
    read -p "确认卸载？请输入 'YES' 确认: " confirm
    if [ "$confirm" != "YES" ]; then
        echo -e "${YELLOW_COLOR}已取消卸载${RES}"
        read -p "按回车键继续..."
        return
    fi
    
    echo -e "${BLUE_COLOR}开始卸载...${RES}"
    
    # 停止服务
    echo -e "停止服务..."
    systemctl stop openlist 2>/dev/null
    systemctl disable openlist 2>/dev/null
    
    # 删除服务文件
    echo -e "删除服务文件..."
    rm -f /etc/systemd/system/openlist.service
    systemctl daemon-reload
    
    # 删除程序文件
    echo -e "删除程序文件..."
    rm -rf "$INSTALL_PATH"
    
    # 删除版本文件
    rm -f "$VERSION_FILE"
    
    echo -e "${GREEN_COLOR}OpenList 已完全卸载${RES}"
    read -p "按回车键继续..."
}

# 查看状态
show_status() {
    echo -e "${CYAN_COLOR}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                       服务状态                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RES}"
    
    if [ ! -f "$INSTALL_PATH/openlist" ]; then
        echo -e "${RED_COLOR}OpenList 未安装${RES}"
        read -p "按回车键继续..."
        return
    fi
    
    # 服务状态
    echo -e "${BLUE_COLOR}服务状态：${RES}"
    if systemctl is-active openlist >/dev/null 2>&1; then
        echo -e "${GREEN_COLOR}● 运行中${RES}"
    else
        echo -e "${RED_COLOR}● 已停止${RES}"
    fi
    
    # 版本信息
    echo -e "${BLUE_COLOR}版本信息：${RES}"
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE"
    else
        echo -e "${YELLOW_COLOR}未知版本${RES}"
    fi
    
    # 文件信息
    echo -e "${BLUE_COLOR}文件信息：${RES}"
    echo -e "安装路径: $INSTALL_PATH"
    echo -e "配置文件: $INSTALL_PATH/data/config.json"
    if [ -f "$INSTALL_PATH/openlist" ]; then
        echo -e "文件大小: $(ls -lh "$INSTALL_PATH/openlist" | awk '{print $5}')"
        echo -e "修改时间: $(stat -c %y "$INSTALL_PATH/openlist" | cut -d. -f1)"
    fi
    
    # 网络信息
    echo -e "${BLUE_COLOR}访问信息：${RES}"
    local local_ip=$(ip addr show | grep -w inet | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1 | head -n1)
    echo -e "本地访问: http://127.0.0.1:5244/"
    echo -e "局域网访问: http://${local_ip}:5244/"
    
    # 端口状态
    if ss -tlnp 2>/dev/null | grep -q ":5244"; then
        echo -e "${GREEN_COLOR}端口 5244: 已监听${RES}"
    else
        echo -e "${RED_COLOR}端口 5244: 未监听${RES}"
    fi
    
    echo
    read -p "按回车键继续..."
}

# 服务控制
control_service() {
    local action="$1"
    local action_name="$2"
    
    if [ ! -f "$INSTALL_PATH/openlist" ]; then
        echo -e "${RED_COLOR}错误：OpenList 未安装${RES}"
        read -p "按回车键继续..."
        return
    fi
    
    echo -e "${BLUE_COLOR}正在${action_name} OpenList...${RES}"
    
    if systemctl "$action" openlist; then
        echo -e "${GREEN_COLOR}OpenList 已${action_name}${RES}"
    else
        echo -e "${RED_COLOR}操作失败${RES}"
    fi
    
    sleep 2
}

# 查看日志
show_logs() {
    echo -e "${CYAN_COLOR}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                       查看日志                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RES}"
    
    if [ ! -f "$INSTALL_PATH/openlist" ]; then
        echo -e "${RED_COLOR}错误：OpenList 未安装${RES}"
        read -p "按回车键继续..."
        return
    fi
    
    echo -e "${BLUE_COLOR}日志查看选项：${RES}"
    echo -e "${GREEN_COLOR}1${RES} - 查看最近 50 条日志"
    echo -e "${GREEN_COLOR}2${RES} - 实时查看日志"
    echo -e "${GREEN_COLOR}3${RES} - 查看错误日志"
    echo -e "${GREEN_COLOR}4${RES} - 查找初始密码"
    echo -e "${GREEN_COLOR}5${RES} - 返回主菜单"
    echo
    
    while true; do
        read -p "请选择 [1-5]: " log_choice
        case "$log_choice" in
            1)
                echo -e "${BLUE_COLOR}最近 50 条日志：${RES}"
                journalctl -u openlist --no-pager -n 50
                ;;
            2)
                echo -e "${BLUE_COLOR}实时日志（按 Ctrl+C 退出）：${RES}"
                journalctl -u openlist -f
                ;;
            3)
                echo -e "${BLUE_COLOR}错误日志：${RES}"
                journalctl -u openlist --no-pager -p err
                ;;
            4)
                echo -e "${BLUE_COLOR}查找初始密码：${RES}"
                local password=$(journalctl -u openlist --no-pager | grep -i "initial password is:" | tail -1 | sed 's/.*initial password is: //')
                if [ ! -z "$password" ]; then
                    echo -e "${GREEN_COLOR}初始密码：$password${RES}"
                else
                    echo -e "${YELLOW_COLOR}未找到密码信息${RES}"
                fi
                ;;
            5)
                return
                ;;
            *)
                echo -e "${RED_COLOR}无效选项${RES}"
                continue
                ;;
        esac
        echo
        read -p "按回车键继续..."
        break
    done
}

# 高级功能菜单
advanced_menu() {
    while true; do
        clear
        echo -e "${CYAN_COLOR}"
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                       高级功能                              ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo -e "${RES}"
        
        echo -e "${GREEN_COLOR}1${RES}  - 查看详细状态"
        echo -e "${GREEN_COLOR}2${RES}  - 查看日志"
        echo -e "${GREEN_COLOR}3${RES}  - 备份配置"
        echo -e "${GREEN_COLOR}4${RES}  - 恢复配置"
        echo -e "${GREEN_COLOR}5${RES}  - 重置密码"
        echo -e "${GREEN_COLOR}6${RES}  - 修改端口"
        echo -e "${GREEN_COLOR}7${RES}  - 检查更新"
        echo -e "${GREEN_COLOR}8${RES}  - 系统信息"
        echo -e "${GREEN_COLOR}0${RES}  - 返回主菜单"
        echo
        
        read -p "请输入选项 [0-8]: " choice
        
        case "$choice" in
            1) show_status ;;
            2) show_logs ;;
            3) backup_config ;;
            4) restore_config ;;
            5) reset_password ;;
            6) change_port ;;
            7) check_update ;;
            8) show_system_info ;;
            0) break ;;
            *) 
                echo -e "${RED_COLOR}无效选项${RES}"
                sleep 1
                ;;
        esac
    done
}

# 备份配置
backup_config() {
    echo -e "${CYAN_COLOR}配置备份${RES}"
    
    if [ ! -d "$INSTALL_PATH/data" ]; then
        echo -e "${RED_COLOR}错误：未找到配置目录${RES}"
        read -p "按回车键继续..."
        return
    fi
    
    local backup_dir="./openlist_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    echo -e "${BLUE_COLOR}备份配置到：$backup_dir${RES}"
    
    if cp -r "$INSTALL_PATH/data" "$backup_dir/"; then
        echo -e "${GREEN_COLOR}备份成功${RES}"
        echo -e "备份位置: $backup_dir/data"
    else
        echo -e "${RED_COLOR}备份失败${RES}"
    fi
    
    read -p "按回车键继续..."
}

# 恢复配置
restore_config() {
    echo -e "${CYAN_COLOR}配置恢复${RES}"
    
    read -p "请输入备份目录路径: " backup_path
    
    if [ ! -d "$backup_path/data" ]; then
        echo -e "${RED_COLOR}错误：备份目录不存在${RES}"
        read -p "按回车键继续..."
        return
    fi
    
    echo -e "${YELLOW_COLOR}警告：此操作将覆盖当前配置${RES}"
    read -p "确认恢复？[y/N]: " confirm
    
    case "$confirm" in
        [yY])
            systemctl stop openlist
            if cp -r "$backup_path/data" "$INSTALL_PATH/"; then
                echo -e "${GREEN_COLOR}恢复成功${RES}"
                systemctl start openlist
            else
                echo -e "${RED_COLOR}恢复失败${RES}"
            fi
            ;;
        *)
            echo -e "${YELLOW_COLOR}已取消恢复${RES}"
            ;;
    esac
    
    read -p "按回车键继续..."
}

# 重置密码
reset_password() {
    echo -e "${CYAN_COLOR}重置密码${RES}"
    
    if [ ! -f "$INSTALL_PATH/openlist" ]; then
        echo -e "${RED_COLOR}错误：OpenList 未安装${RES}"
        read -p "按回车键继续..."
        return
    fi
    
    echo -e "${RED_COLOR}注意：重置密码将删除数据库文件${RES}"
    echo -e "${YELLOW_COLOR}这将会丢失所有配置和数据！${RES}"
    echo
    read -p "确认重置密码？请输入 'RESET': " confirm
    
    if [ "$confirm" != "RESET" ]; then
        echo -e "${YELLOW_COLOR}已取消重置${RES}"
        read -p "按回车键继续..."
        return
    fi
    
    echo -e "${BLUE_COLOR}正在重置密码...${RES}"
    
    # 停止服务
    systemctl stop openlist
    
    # 备份数据库
    if [ -f "$INSTALL_PATH/data/data.db" ]; then
        cp "$INSTALL_PATH/data/data.db" "$INSTALL_PATH/data/data.db.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # 删除数据库文件
    rm -f "$INSTALL_PATH/data/data.db"*
    
    # 启动服务
    systemctl start openlist
    
    # 等待服务启动
    sleep 5
    
    # 获取新密码
    local new_password=$(journalctl -u openlist --since "1 minute ago" | grep -i "initial password is:" | tail -1 | sed 's/.*initial password is: //')
    
    if [ ! -z "$new_password" ]; then
        echo -e "${GREEN_COLOR}密码重置成功${RES}"
        echo -e "${BLUE_COLOR}新密码：${RES}$new_password"
    else
        echo -e "${YELLOW_COLOR}无法自动获取新密码${RES}"
        echo -e "请查看日志：sudo journalctl -u openlist -f"
    fi
    
    read -p "按回车键继续..."
}

# 修改端口
change_port() {
    echo -e "${CYAN_COLOR}修改端口${RES}"
    echo -e "${YELLOW_COLOR}此功能需要修改配置文件${RES}"
    echo -e "${YELLOW_COLOR}建议通过 Web 界面修改${RES}"
    read -p "按回车键继续..."
}

# 检查更新
check_update() {
    echo -e "${CYAN_COLOR}检查更新${RES}"
    
    if [ ! -f "$VERSION_FILE" ]; then
        echo -e "${YELLOW_COLOR}未找到版本信息${RES}"
        read -p "按回车键继续..."
        return
    fi
    
    local current_version=$(head -n1 "$VERSION_FILE")
    echo -e "${BLUE_COLOR}当前版本：${RES}$current_version"
    
    echo -e "${BLUE_COLOR}检查远程版本...${RES}"
    
    # 这里可以添加更复杂的版本检查逻辑
    echo -e "${GREEN_COLOR}版本检查完成${RES}"
    echo -e "${YELLOW_COLOR}如需更新，请使用更新功能${RES}"
    
    read -p "按回车键继续..."
}

# 显示系统信息
show_system_info() {
    echo -e "${CYAN_COLOR}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                       系统信息                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RES}"
    
    echo -e "${BLUE_COLOR}操作系统：${RES}"
    cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2
    
    echo -e "${BLUE_COLOR}内核版本：${RES}"
    uname -r
    
    echo -e "${BLUE_COLOR}系统架构：${RES}"
    uname -m
    
    echo -e "${BLUE_COLOR}CPU 信息：${RES}"
    lscpu | grep "Model name" | cut -d':' -f2 | sed 's/^ *//'
    
    echo -e "${BLUE_COLOR}内存信息：${RES}"
    free -h | grep Mem | awk '{print "总计: " $2 ", 已用: " $3 ", 可用: " $7}'
    
    echo -e "${BLUE_COLOR}磁盘信息：${RES}"
    df -h / | tail -1 | awk '{print "总计: " $2 ", 已用: " $3 ", 可用: " $4 ", 使用率: " $5}'
    
    echo -e "${BLUE_COLOR}网络接口：${RES}"
    ip addr show | grep -E "inet.*global" | awk '{print $2}' | head -3
    
    echo
    read -p "按回车键继续..."
}

# 迁移 Alist 数据到 OpenList
migrate_alist_data() {
    local alist_data_path="/opt/alist/data"
    
    echo -e "${CYAN_COLOR}开始迁移 Alist 数据到 OpenList...${RES}"
    
    # 检查 Alist 数据目录是否存在
    if [ ! -d "$alist_data_path" ]; then
        echo -e "${RED_COLOR}错误：未找到 Alist 数据目录 $alist_data_path${RES}"
        read -p "按回车键继续..."
        return
    fi

    # 创建 OpenList 数据目录（如果不存在）
    mkdir -p "$INSTALL_PATH/data"
    
    # 复制 Alist 数据
    echo -e "${BLUE_COLOR}正在复制数据...${RES}"
    cp -r "$alist_data_path/"* "$INSTALL_PATH/data/"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN_COLOR}数据迁移成功！${RES}"
    else
        echo -e "${RED_COLOR}数据迁移失败！${RES}"
    fi
    
    read -p "按回车键继续..."
}

# 在主菜单中添加迁移选项
show_main_menu() {
    while true; do
        clear
        echo -e "${CYAN_COLOR}"
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                    OpenList 管理脚本                         ║"
        echo "║                                                              ║"
        echo "║                   Interactive Manager                        ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo -e "${RES}"
        
        # 显示状态
        if [ -f "$INSTALL_PATH/openlist" ]; then
            if systemctl is-active openlist >/dev/null 2>&1; then
                echo -e "${GREEN_COLOR}● OpenList 状态：运行中${RES}"
            else
                echo -e "${RED_COLOR}● OpenList 状态：已停止${RES}"
            fi
        else
            echo -e "${YELLOW_COLOR}● OpenList 状态：未安装${RES}"
        fi
        
        echo
        echo -e "${PURPLE_COLOR}═══ 基本操作 ═══${RES}"
        echo -e "${GREEN_COLOR}1${RES}  - 安装 OpenList"
        echo -e "${GREEN_COLOR}2${RES}  - 更新 OpenList"
        echo -e "${GREEN_COLOR}3${RES}  - 卸载 OpenList"
        echo -e "${GREEN_COLOR}4${RES}  - 迁移 Alist 数据到 OpenList"  # 新增迁移选项
        echo
        echo -e "${PURPLE_COLOR}═══ 服务管理 ═══${RES}"
        echo -e "${GREEN_COLOR}5${RES}  - 启动服务"
        echo -e "${GREEN_COLOR}6${RES}  - 停止服务"
        echo -e "${GREEN_COLOR}7${RES}  - 重启服务"
        echo -e "${GREEN_COLOR}8${RES}  - 查看状态"
        echo -e "${GREEN_COLOR}9${RES}  - 查看日志"
        echo -e "${GREEN_COLOR}0${RES}  - 退出脚本"
        echo
        
        read -p "请输入选项 [0-9]: " choice
        
        case "$choice" in
            1) install_openlist ;;
            2) update_openlist ;;
            3) uninstall_openlist ;;
            4) migrate_alist_data ;;  # 调用迁移功能
            5) control_service start "启动" ;;
            6) control_service stop "停止" ;;
            7) control_service restart "重启" ;;
            8) show_status ;;
            9) show_logs ;;
            0) 
                echo -e "${GREEN_COLOR}谢谢使用！${RES}"
                exit 0
                ;;
            *) 
                echo -e "${RED_COLOR}无效选项，请重新选择${RES}"
                sleep 1
                ;;
        esac
    done
}

# 主程序入口
main() {
    # 显示欢迎信息
    show_welcome
    
    # 检查系统要求
    check_system_requirements
    
    # 显示主菜单
    show_main_menu
}

# 执行主程序
main "$@"
