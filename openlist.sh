#!/bin/bash
###############################################################################
#
# OpenList Interactive Manager Script
#
# Version: 1.6.7
# Last Updated: 2025-06-22
#
# Description:
#   An interactive management script for OpenList
#   Cross-platform support: Linux, Windows (WSL), macOS, Android Termux
#
# Requirements:
#   - Linux with systemd (or compatible systems)
#   - Root privileges for most operations
#   - curl, tar
#
# Installation:
#   sudo curl -fsSL "https://raw.githubusercontent.com/ypq123456789/openlist-manger/refs/heads/main/openlist.sh" -o /usr/local/bin/openlist && sudo chmod +x /usr/local/bin/openlist && openlist
#
# Usage:
#   openlist
#
###############################################################################

# 配置部分
GITHUB_REPO="OpenListTeam/OpenList"
VERSION_TAG="beta"
VERSION_FILE="/opt/openlist/.version"
MANAGER_VERSION="1.6.7"  # 更新管理器版本号

# 颜色配置
RED_COLOR='\e[1;31m'
GREEN_COLOR='\e[1;32m'
YELLOW_COLOR='\e[1;33m'
BLUE_COLOR='\e[1;34m'
CYAN_COLOR='\e[1;36m'
PURPLE_COLOR='\e[1;35m'
RES='\e[0m'

# ===================== 跨平台系统检测 =====================

# 检测操作系统类型
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            OS_TYPE="linux"
            OS_NAME="$ID"
            OS_VERSION="$VERSION_ID"
        else
            OS_TYPE="linux"
            OS_NAME="unknown"
            OS_VERSION="unknown"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        OS_TYPE="macos"
        OS_NAME="macos"
        OS_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
        # Windows (Git Bash, Cygwin, etc.)
        OS_TYPE="windows"
        OS_NAME="windows"
        OS_VERSION="unknown"
    elif [[ -d "/data/data/com.termux" ]]; then
        # Android Termux
        OS_TYPE="termux"
        OS_NAME="termux"
        OS_VERSION="unknown"
    else
        OS_TYPE="unknown"
        OS_NAME="unknown"
        OS_VERSION="unknown"
    fi
    
    echo -e "${BLUE_COLOR}检测到系统：${OS_TYPE} (${OS_NAME} ${OS_VERSION})${RES}"
}

# 检查权限（跨平台）
check_permissions() {
    local need_root=false
    
    case "$OS_TYPE" in
        "linux")
            # Linux 需要 root 权限
            need_root=true
            ;;
        "macos")
            # macOS 通常需要管理员权限
            need_root=true
            ;;
        "windows")
            # Windows 在 WSL 中需要 root
            if [[ -f /proc/version ]] && grep -q Microsoft /proc/version; then
                need_root=true
            fi
            ;;
        "termux")
            # Termux 不需要 root
            need_root=false
            ;;
        *)
            need_root=true
            ;;
    esac
    
    if [[ "$need_root" == "true" ]] && [[ "$(id -u)" != "0" ]]; then
        echo -e "${RED_COLOR}错误：需要管理员权限运行此脚本${RES}"
        case "$OS_TYPE" in
            "linux")
                echo -e "${YELLOW_COLOR}请使用: sudo ./openlist.sh${RES}"
                ;;
            "macos")
                echo -e "${YELLOW_COLOR}请使用: sudo ./openlist.sh${RES}"
                ;;
            "windows")
                echo -e "${YELLOW_COLOR}请在 WSL 中使用: sudo ./openlist.sh${RES}"
                ;;
        esac
        read -r -p "按回车键退出..." < /dev/tty
        exit 1
    fi
}

# 检查包管理器（跨平台）
check_package_manager() {
    case "$OS_TYPE" in
        "linux")
            if command -v apt >/dev/null 2>&1; then
                PACKAGE_MANAGER="apt"
            elif command -v yum >/dev/null 2>&1; then
                PACKAGE_MANAGER="yum"
            elif command -v dnf >/dev/null 2>&1; then
                PACKAGE_MANAGER="dnf"
            elif command -v pacman >/dev/null 2>&1; then
                PACKAGE_MANAGER="pacman"
            else
                PACKAGE_MANAGER="unknown"
            fi
            ;;
        "macos")
            if command -v brew >/dev/null 2>&1; then
                PACKAGE_MANAGER="brew"
            else
                PACKAGE_MANAGER="unknown"
            fi
            ;;
        "termux")
            if command -v pkg >/dev/null 2>&1; then
                PACKAGE_MANAGER="pkg"
            else
                PACKAGE_MANAGER="unknown"
            fi
            ;;
        *)
            PACKAGE_MANAGER="unknown"
            ;;
    esac
    
    echo -e "${BLUE_COLOR}包管理器：${PACKAGE_MANAGER}${RES}"
}

# 安装依赖包（跨平台）
install_dependencies() {
    local missing_deps=()
    
    if ! command -v curl >/dev/null 2>&1; then
        missing_deps+=("curl")
    fi
    
    if ! command -v tar >/dev/null 2>&1; then
        missing_deps+=("tar")
    fi
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        return 0
    fi
    
    echo -e "${RED_COLOR}缺少必要的依赖包：${missing_deps[*]}${RES}"
    echo -e "${YELLOW_COLOR}正在尝试安装依赖包...${RES}"
    
    case "$PACKAGE_MANAGER" in
        "apt")
            apt update && apt install -y "${missing_deps[@]}" || return 1
            ;;
        "yum")
            yum install -y "${missing_deps[@]}" || return 1
            ;;
        "dnf")
            dnf install -y "${missing_deps[@]}" || return 1
            ;;
        "pacman")
            pacman -S --noconfirm "${missing_deps[@]}" || return 1
            ;;
        "brew")
            brew install "${missing_deps[@]}" || return 1
            ;;
        "pkg")
            pkg install -y "${missing_deps[@]}" || return 1
            ;;
        *)
            echo -e "${RED_COLOR}无法自动安装依赖包，请手动安装：${missing_deps[*]}${RES}"
            return 1
            ;;
    esac
    
    echo -e "${GREEN_COLOR}依赖包安装完成${RES}"
    return 0
}

# 检查 systemd（跨平台）
check_systemd() {
    case "$OS_TYPE" in
        "linux")
            if ! command -v systemctl >/dev/null 2>&1; then
                echo -e "${YELLOW_COLOR}警告：系统不支持 systemd${RES}"
                echo -e "${YELLOW_COLOR}服务管理功能可能不可用${RES}"
                SYSTEMD_AVAILABLE=false
            else
                SYSTEMD_AVAILABLE=true
            fi
            ;;
        "macos"|"windows"|"termux")
            echo -e "${YELLOW_COLOR}当前系统不支持 systemd，将使用替代方案${RES}"
            SYSTEMD_AVAILABLE=false
            ;;
        *)
            SYSTEMD_AVAILABLE=false
            ;;
    esac
}

# 获取本机IP（跨平台）
get_local_ip() {
    case "$OS_TYPE" in
        "linux"|"windows")
            # Linux 和 WSL
            curl -s https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}' 2>/dev/null || echo "127.0.0.1"
            ;;
        "macos")
            # macOS
            curl -s https://api.ipify.org 2>/dev/null || ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -n1 2>/dev/null || echo "127.0.0.1"
            ;;
        "termux")
            # Termux
            curl -s https://api.ipify.org 2>/dev/null || ip addr show | grep -w inet | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1 | head -n1 2>/dev/null || echo "127.0.0.1"
            ;;
        *)
            echo "127.0.0.1"
            ;;
    esac
}

# 设置安装路径（跨平台）
get_install_path() {
    case "$OS_TYPE" in
        "linux"|"windows")
            echo "/opt/openlist"
            ;;
        "macos")
            echo "/usr/local/opt/openlist"
            ;;
        "termux")
            echo "$HOME/openlist"
            ;;
        *)
            echo "/opt/openlist"
            ;;
    esac
}

# 创建服务（跨平台）
create_service() {
    local install_path=$1
    
    case "$OS_TYPE" in
        "linux"|"windows")
            if [[ "$SYSTEMD_AVAILABLE" == "true" ]]; then
                # 创建 systemd 服务
                cat > /etc/systemd/system/openlist.service << EOF
[Unit]
Description=OpenList service
Wants=network.target
After=network.target network.service

[Service]
Type=simple
WorkingDirectory=$install_path
ExecStart=$install_path/openlist server
KillMode=process
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
                systemctl daemon-reload
                systemctl enable openlist
                echo -e "${GREEN_COLOR}systemd 服务创建成功${RES}"
            else
                echo -e "${YELLOW_COLOR}跳过 systemd 服务创建${RES}"
            fi
            ;;
        "macos")
            # macOS 使用 launchd
            cat > /Library/LaunchDaemons/com.openlist.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.openlist</string>
    <key>ProgramArguments</key>
    <array>
        <string>$install_path/openlist</string>
        <string>server</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$install_path</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF
            echo -e "${GREEN_COLOR}launchd 服务创建成功${RES}"
            ;;
        "termux")
            # Termux 使用 nohup 或 screen
            echo -e "${YELLOW_COLOR}Termux 环境，请手动启动服务：${RES}"
            echo -e "nohup $install_path/openlist server > $install_path/openlist.log 2>&1 &"
            ;;
    esac
}

# 启动服务（跨平台）
start_service() {
    case "$OS_TYPE" in
        "linux"|"windows")
            if [[ "$SYSTEMD_AVAILABLE" == "true" ]]; then
                systemctl start openlist
            else
                echo -e "${YELLOW_COLOR}请手动启动服务${RES}"
            fi
            ;;
        "macos")
            launchctl load /Library/LaunchDaemons/com.openlist.plist
            ;;
        "termux")
            echo -e "${YELLOW_COLOR}请手动启动服务${RES}"
            ;;
    esac
}

# 停止服务（跨平台）
stop_service() {
    case "$OS_TYPE" in
        "linux"|"windows")
            if [[ "$SYSTEMD_AVAILABLE" == "true" ]]; then
                systemctl stop openlist
            else
                echo -e "${YELLOW_COLOR}请手动停止服务${RES}"
            fi
            ;;
        "macos")
            launchctl unload /Library/LaunchDaemons/com.openlist.plist
            ;;
        "termux")
            echo -e "${YELLOW_COLOR}请手动停止服务${RES}"
            ;;
    esac
}

# 检查服务状态（跨平台）
check_service_status() {
    case "$OS_TYPE" in
        "linux"|"windows")
            if [[ "$SYSTEMD_AVAILABLE" == "true" ]]; then
                systemctl is-active openlist >/dev/null 2>&1
            else
                # 检查进程
                pgrep -f "openlist server" >/dev/null 2>&1
            fi
            ;;
        "macos")
            launchctl list | grep -q com.openlist
            ;;
        "termux")
            pgrep -f "openlist server" >/dev/null 2>&1
            ;;
        *)
            false
            ;;
    esac
}

# 获取服务日志（跨平台）
get_service_logs() {
    case "$OS_TYPE" in
        "linux"|"windows")
            if [[ "$SYSTEMD_AVAILABLE" == "true" ]]; then
                journalctl -u openlist --no-pager -n 50
            else
                echo -e "${YELLOW_COLOR}无法获取服务日志，请检查进程输出${RES}"
            fi
            ;;
        "macos")
            log show --predicate 'process == "openlist"' --last 1h
            ;;
        "termux")
            if [[ -f "$INSTALL_PATH/openlist.log" ]]; then
                tail -n 50 "$INSTALL_PATH/openlist.log"
            else
                echo -e "${YELLOW_COLOR}未找到日志文件${RES}"
            fi
            ;;
    esac
}

# ===================== Docker 镜像标签选择 =====================
DOCKER_IMAGE_TAG="beta"

select_docker_image_tag() {
    echo -e "${BLUE_COLOR}请选择要使用的 OpenList Docker 镜像标签：${RES}"
    echo -e "${GREEN_COLOR}1${RES} - beta-ffmpeg"
    echo -e "${GREEN_COLOR}2${RES} - beta-aio"
    echo -e "${GREEN_COLOR}3${RES} - beta-aria2"
    echo -e "${GREEN_COLOR}4${RES} - beta (默认)"
    echo -e "${GREEN_COLOR}5${RES} - 手动输入标签"
    echo
    read -r -p "请输入选项 [1-5] (默认4): " tag_choice < /dev/tty
    case "$tag_choice" in
        1)
            DOCKER_IMAGE_TAG="beta-ffmpeg";;
        2)
            DOCKER_IMAGE_TAG="beta-aio";;
        3)
            DOCKER_IMAGE_TAG="beta-aria2";;
        4|"")
            DOCKER_IMAGE_TAG="beta";;
        5)
            read -r -p "请输入自定义标签: " custom_tag < /dev/tty
            if [ -n "$custom_tag" ]; then
                DOCKER_IMAGE_TAG="$custom_tag"
            else
                DOCKER_IMAGE_TAG="beta"
            fi
            ;;
        *)
            DOCKER_IMAGE_TAG="beta";;
    esac
    echo -e "${GREEN_COLOR}已选择镜像标签: $DOCKER_IMAGE_TAG${RES}"
}

# 错误处理函数
handle_error() {
    local exit_code=$1
    local error_msg=$2
    echo -e "${RED_COLOR}错误：${error_msg}${RES}"
    read -r -p "按回车键继续..." < /dev/tty
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
        read -r -p "按回车键退出..." < /dev/tty
        exit 1
    fi
}

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
INSTALL_PATH=$(get_install_path)

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
    
    # 检测操作系统
    detect_os
    
    # 检查权限
    check_permissions
    
    # 检查包管理器
    check_package_manager
    
    # 检查架构
    if [ "$ARCH" == "UNKNOWN" ]; then
        echo -e "${RED_COLOR}错误：不支持的系统架构 $(uname -m)${RES}"
        echo -e "${YELLOW_COLOR}目前仅支持 x86_64 和 arm64 架构${RES}"
        read -r -p "按回车键退出..." < /dev/tty
        exit 1
    fi
    
    # 检查 systemd
    check_systemd
    
    # 检查依赖
    if ! install_dependencies; then
        read -r -p "按回车键退出..." < /dev/tty
        exit 1
    fi
    
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
    echo "║                   Interactive Manager v${MANAGER_VERSION}                ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RES}"
    
    # 添加提示信息
    echo -e "${YELLOW_COLOR}* 提示：输入 'openlist' 可再次唤出脚本${RES}"
    echo

    echo -e "${BLUE_COLOR}系统信息：${RES}"
    case "$OS_TYPE" in
        "linux")
            echo -e "操作系统: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2 2>/dev/null || echo "Linux")"
            ;;
        "macos")
            echo -e "操作系统: macOS $(sw_vers -productVersion 2>/dev/null || echo "unknown")"
            ;;
        "windows")
            echo -e "操作系统: Windows (WSL)"
            ;;
        "termux")
            echo -e "操作系统: Android Termux"
            ;;
        *)
            echo -e "操作系统: $OS_TYPE"
            ;;
    esac
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
        local version_choice
        version_choice=$(default_read "请输入选项 [1-4] (默认1): " "1")
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
                    local custom_version
                    custom_version=$(default_read "请输入要使用的版本标签 (默认beta): " "beta")
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
                local custom_version
                custom_version=$(default_read "请输入版本标签 (如: beta, v1.0.0，默认beta): " "beta")
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
        proxy_choice=$(default_read "请输入选项 [1-4] (默认1): " "1")
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
                custom_proxy=$(default_read "请输入代理地址 (以/结尾): " "")
                if [[ "$custom_proxy" =~ ^https://.*/$ ]]; then
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
            read -r -p "请选择 [1-2]: " install_choice < /dev/tty
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
    
    # Termux 环境优先使用 pkg 安装
    if [ "$OS_TYPE" = "termux" ]; then
        echo -e "${BLUE_COLOR}检测到 Termux 环境，尝试使用 pkg 安装 OpenList...${RES}"
        
        # 更新包列表
        echo -e "${BLUE_COLOR}更新包列表...${RES}"
        pkg update -y
        
        # 尝试安装 OpenList
        echo -e "${BLUE_COLOR}安装 OpenList...${RES}"
        if pkg install -y openlist; then
            echo -e "${GREEN_COLOR}"
            echo "╔══════════════════════════════════════════════════════════════╗"
            echo "║                    OpenList 安装成功！                       ║"
            echo "╚══════════════════════════════════════════════════════════════╝"
            echo -e "${RES}"
            
            # 获取IP地址
            local local_ip=$(get_local_ip)
            
            echo -e "${BLUE_COLOR}访问信息：${RES}"
            echo -e "本地访问: http://127.0.0.1:5244/"
            echo -e "公网访问: http://${local_ip}:5244/"
            echo
            echo -e "${BLUE_COLOR}默认账号：${RES}admin"
            echo -e "${BLUE_COLOR}初始密码：${RES}请查看服务日志获取"
            echo -e "${YELLOW_COLOR}注意：Termux 环境下请手动启动服务${RES}"
            echo -e "${YELLOW_COLOR}启动命令：openlist server${RES}"
            echo
            
            read -r -p "按回车键继续..." < /dev/tty
            return
        else
            echo -e "${YELLOW_COLOR}pkg 安装失败，回退到手动下载安装方式${RES}"
            echo
        fi
    fi
    
    # 检查安装
    if ! check_install; then
        read -r -p "按回车键继续..." < /dev/tty
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
    
    read -r -p "确认安装？[Y/n]: " confirm < /dev/tty
    case "${confirm:-y}" in
        [yY]|"")
            ;;
        *)
            echo -e "${YELLOW_COLOR}已取消安装${RES}"
            read -r -p "按回车键继续..." < /dev/tty
            return
            ;;
    esac
    
    # 下载
    if ! download_file "$download_url" "/tmp/openlist.tar.gz"; then
        echo -e "${RED_COLOR}下载失败！${RES}"
        read -r -p "按回车键继续..." < /dev/tty
        return
    fi
    
    # 验证文件
    echo -e "${BLUE_COLOR}验证文件完整性...${RES}"
    if ! tar -tf /tmp/openlist.tar.gz >/dev/null 2>&1; then
        echo -e "${RED_COLOR}文件损坏或格式错误${RES}"
        rm -f /tmp/openlist.tar.gz
        read -r -p "按回车键继续..." < /dev/tty
        return
    fi
    
    # 解压
    echo -e "${BLUE_COLOR}解压文件...${RES}"
    if ! tar zxf /tmp/openlist.tar.gz -C "$INSTALL_PATH/"; then
        echo -e "${RED_COLOR}解压失败${RES}"
        rm -f /tmp/openlist.tar.gz
        read -r -p "按回车键继续..." < /dev/tty
        return
    fi
    
    # 验证安装
    if [ ! -f "$INSTALL_PATH/openlist" ]; then
        echo -e "${RED_COLOR}安装失败，未找到可执行文件${RES}"
        read -r -p "按回车键继续..." < /dev/tty
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
    create_service "$INSTALL_PATH"
    
    # 启动服务
    echo -e "${BLUE_COLOR}启动服务...${RES}"
    start_service
    
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
    local local_ip=$(get_local_ip)
    
    echo -e "${BLUE_COLOR}访问信息：${RES}"
    echo -e "本地访问: http://127.0.0.1:5244/"
    echo -e "公网访问: http://${local_ip}:5244/"
    echo
    echo -e "${BLUE_COLOR}默认账号：${RES}admin"
    echo -e "${BLUE_COLOR}初始密码：${RES}请查看服务日志获取"
    echo
    
    read -r -p "按回车键继续..." < /dev/tty
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
        read -r -p "按回车键继续..." < /dev/tty
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
    echo -e "${GREEN_COLOR}1${RES} - 更新到正式版最新版本"
    echo -e "${GREEN_COLOR}2${RES} - 更新到开发版最新版本"
    echo -e "${GREEN_COLOR}3${RES} - 选择其他版本"
    echo -e "${GREEN_COLOR}4${RES} - 返回主菜单"
    echo
    while true; do
        update_choice=$(default_read "请选择 [1-4] (默认1): " "1")
        case "$update_choice" in
            1)
                # 获取最新正式版 release tag
                latest_release=$(curl -s https://api.github.com/repos/OpenListTeam/OpenList/releases/latest | grep 'tag_name' | head -1 | cut -d '"' -f4)
                if [ -n "$latest_release" ]; then
                    VERSION_TAG="$latest_release"
                    echo -e "${GREEN_COLOR}将更新到最新正式版: $VERSION_TAG${RES}"
                else
                    VERSION_TAG="beta"
                    echo -e "${YELLOW_COLOR}未获取到正式版，使用 beta${RES}"
                fi
                break
                ;;
            2)
                VERSION_TAG="beta"
                echo -e "${GREEN_COLOR}将更新到开发版: beta${RES}"
                break
                ;;
            3)
                if ! select_version; then
                    return
                fi
                break
                ;;
            4)
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
    
    read -r -p "确认更新？[Y/n]: " confirm < /dev/tty
    case "${confirm:-y}" in
        [yY]|"")
            ;;
        *)
            echo -e "${YELLOW_COLOR}已取消更新${RES}"
            read -r -p "按回车键继续..." < /dev/tty
            return
            ;;
    esac
    
    # 停止服务
    echo -e "${BLUE_COLOR}停止服务...${RES}"
    stop_service
    
    # 备份
    echo -e "${BLUE_COLOR}创建备份...${RES}"
    cp "$INSTALL_PATH/openlist" "/tmp/openlist.bak"
    
    # 下载新版本
    if ! download_file "$download_url" "/tmp/openlist.tar.gz"; then
        echo -e "${RED_COLOR}下载失败，正在恢复...${RES}"
        mv "/tmp/openlist.bak" "$INSTALL_PATH/openlist"
        start_service
        read -r -p "按回车键继续..." < /dev/tty
        return
    fi
    
    # 解压
    echo -e "${BLUE_COLOR}安装新版本...${RES}"
    if ! tar zxf /tmp/openlist.tar.gz -C "$INSTALL_PATH/"; then
        echo -e "${RED_COLOR}解压失败，正在恢复...${RES}"
        mv "/tmp/openlist.bak" "$INSTALL_PATH/openlist"
        start_service
        rm -f /tmp/openlist.tar.gz
        read -r -p "按回车键继续..." < /dev/tty
        return
    fi
    
    # 验证更新
    if [ ! -f "$INSTALL_PATH/openlist" ]; then
        echo -e "${RED_COLOR}更新失败，正在恢复...${RES}"
        mv "/tmp/openlist.bak" "$INSTALL_PATH/openlist"
        start_service
        read -r -p "按回车键继续..." < /dev/tty
        return
    fi
    
    # 设置权限
    chmod +x "$INSTALL_PATH/openlist"
    
    # 更新版本信息
    echo "$VERSION_TAG" > "$VERSION_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S')" >> "$VERSION_FILE"
    
    # 启动服务
    echo -e "${BLUE_COLOR}启动服务...${RES}"
    start_service
    
    # 清理文件
    rm -f /tmp/openlist.tar.gz /tmp/openlist.bak
    
    echo -e "${GREEN_COLOR}OpenList 更新成功！${RES}"
    read -r -p "按回车键继续..." < /dev/tty
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
        read -r -p "按回车键继续..." < /dev/tty
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
    
    read -r -p "确认卸载？请输入 'YES' 确认: " confirm < /dev/tty
    if [ "$confirm" != "YES" ]; then
        echo -e "${YELLOW_COLOR}已取消卸载${RES}"
        read -r -p "按回车键继续..." < /dev/tty
        return
    fi
    
    echo -e "${BLUE_COLOR}开始卸载...${RES}"
    
    # 停止服务
    echo -e "停止服务..."
    stop_service 2>/dev/null
    
    # 删除服务文件
    echo -e "删除服务文件..."
    case "$OS_TYPE" in
        "linux"|"windows")
            if [[ "$SYSTEMD_AVAILABLE" == "true" ]]; then
                systemctl disable openlist 2>/dev/null
                rm -f /etc/systemd/system/openlist.service
                systemctl daemon-reload
            fi
            ;;
        "macos")
            launchctl unload /Library/LaunchDaemons/com.openlist.plist 2>/dev/null
            rm -f /Library/LaunchDaemons/com.openlist.plist
            ;;
        "termux")
            # Termux 不需要删除服务文件
            ;;
    esac
    
    # 删除程序文件
    echo -e "删除程序文件..."
    rm -rf "$INSTALL_PATH"
    
    # 删除版本文件
    rm -f "$VERSION_FILE"
    
    echo -e "${GREEN_COLOR}OpenList 已完全卸载${RES}"
    read -r -p "按回车键继续..." < /dev/tty
}

# 监控 OpenList 状态
show_status() {
    echo -e "${CYAN_COLOR}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                       OpenList 状态                          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RES}"
    
    if [ "$OS_TYPE" = "termux" ]; then
        # Termux 环境下的状态检查
        if command -v openlist >/dev/null 2>&1; then
            # pkg 安装的 OpenList
            if pgrep -f "openlist server" >/dev/null 2>&1; then
                echo -e "${GREEN_COLOR}● OpenList 状态：运行中 (pkg 安装)${RES}"
            else
                echo -e "${RED_COLOR}● OpenList 状态：已停止 (pkg 安装)${RES}"
            fi
            
            # 显示版本信息
            local version=$(openlist version 2>/dev/null || echo "未知")
            echo -e "${BLUE_COLOR}● 当前版本：${RES}$version"
            echo -e "${BLUE_COLOR}● 安装方式：${RES}pkg 安装"
            echo -e "${BLUE_COLOR}● 可执行文件：${RES}$(which openlist)"
            
            # 显示网络信息
            local local_ip=$(get_local_ip)
            echo -e "${BLUE_COLOR}● 访问地址：${RES}"
            echo -e "  本地访问: http://127.0.0.1:5244/"
            echo -e "  公网访问: http://${local_ip}:5244/"
            
            # 显示端口状态
            if ss -tlnp 2>/dev/null | grep -q ":5244" || netstat -tlnp 2>/dev/null | grep -q ":5244"; then
                echo -e "${GREEN_COLOR}● 端口 5244: 已监听${RES}"
            else
                echo -e "${RED_COLOR}● 端口 5244: 未监听${RES}"
            fi
            
        elif [ -f "$INSTALL_PATH/openlist" ]; then
            # 手动安装的 OpenList
            if pgrep -f "openlist server" >/dev/null 2>&1; then
                echo -e "${GREEN_COLOR}● OpenList 状态：运行中 (手动安装)${RES}"
            else
                echo -e "${RED_COLOR}● OpenList 状态：已停止 (手动安装)${RES}"
            fi
            
            # 显示版本信息
            if [ -f "$VERSION_FILE" ]; then
                local version=$(head -n1 "$VERSION_FILE" 2>/dev/null)
                local install_time=$(tail -n1 "$VERSION_FILE" 2>/dev/null)
                echo -e "${BLUE_COLOR}● 当前版本：${RES}$version"
                echo -e "${BLUE_COLOR}● 安装时间：${RES}$install_time"
            else
                echo -e "${YELLOW_COLOR}● 版本信息：未知${RES}"
            fi
            
            # 显示文件信息
            echo -e "${BLUE_COLOR}● 安装路径：${RES}$INSTALL_PATH"
            echo -e "${BLUE_COLOR}● 配置文件：${RES}$INSTALL_PATH/data/config.json"
            if [ -f "$INSTALL_PATH/openlist" ]; then
                echo -e "${BLUE_COLOR}● 文件大小：${RES}$(ls -lh "$INSTALL_PATH/openlist" | awk '{print $5}')"
                echo -e "${BLUE_COLOR}● 修改时间：${RES}$(stat -c %y "$INSTALL_PATH/openlist" | cut -d. -f1)"
            fi
            
            # 显示网络信息
            local local_ip=$(get_local_ip)
            echo -e "${BLUE_COLOR}● 访问地址：${RES}"
            echo -e "  本地访问: http://127.0.0.1:5244/"
            echo -e "  公网访问: http://${local_ip}:5244/"
            
            # 显示端口状态
            if ss -tlnp 2>/dev/null | grep -q ":5244" || netstat -tlnp 2>/dev/null | grep -q ":5244"; then
                echo -e "${GREEN_COLOR}● 端口 5244: 已监听${RES}"
            else
                echo -e "${RED_COLOR}● 端口 5244: 未监听${RES}"
            fi
        else
            echo -e "${YELLOW_COLOR}● OpenList 状态：未安装${RES}"
        fi
    else
        # 其他环境的状态检查
        if [ -f "$INSTALL_PATH/openlist" ]; then
            if check_service_status; then
                echo -e "${GREEN_COLOR}● OpenList 状态：运行中${RES}"
            else
                echo -e "${RED_COLOR}● OpenList 状态：已停止${RES}"
            fi
            
            # 显示版本信息
            if [ -f "$VERSION_FILE" ]; then
                local version=$(head -n1 "$VERSION_FILE" 2>/dev/null)
                local install_time=$(tail -n1 "$VERSION_FILE" 2>/dev/null)
                echo -e "${BLUE_COLOR}● 当前版本：${RES}$version"
                echo -e "${BLUE_COLOR}● 安装时间：${RES}$install_time"
            else
                echo -e "${YELLOW_COLOR}● 版本信息：未知${RES}"
            fi
            
            # 显示文件信息
            echo -e "${BLUE_COLOR}● 安装路径：${RES}$INSTALL_PATH"
            echo -e "${BLUE_COLOR}● 配置文件：${RES}$INSTALL_PATH/data/config.json"
            if [ -f "$INSTALL_PATH/openlist" ]; then
                echo -e "${BLUE_COLOR}● 文件大小：${RES}$(ls -lh "$INSTALL_PATH/openlist" | awk '{print $5}')"
                echo -e "${BLUE_COLOR}● 修改时间：${RES}$(stat -c %y "$INSTALL_PATH/openlist" | cut -d. -f1)"
            fi
            
            # 显示网络信息
            local local_ip=$(get_local_ip)
            echo -e "${BLUE_COLOR}● 访问地址：${RES}"
            echo -e "  本地访问: http://127.0.0.1:5244/"
            echo -e "  公网访问: http://${local_ip}:5244/"
            
            # 显示端口状态
            if ss -tlnp 2>/dev/null | grep -q ":5244" || netstat -tlnp 2>/dev/null | grep -q ":5244"; then
                echo -e "${GREEN_COLOR}● 端口 5244: 已监听${RES}"
            else
                echo -e "${RED_COLOR}● 端口 5244: 未监听${RES}"
            fi
        else
            echo -e "${YELLOW_COLOR}● OpenList 状态：未安装${RES}"
        fi
    fi
    
    echo
    read -r -p "按回车键继续..." < /dev/tty
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
        read -r -p "按回车键继续..." < /dev/tty
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
        read -r -p "请选择 [1-5]: " log_choice < /dev/tty
        case "$log_choice" in
            1)
                echo -e "${BLUE_COLOR}最近 50 条日志：${RES}"
                get_service_logs
                ;;
            2)
                echo -e "${BLUE_COLOR}实时日志（按 Ctrl+C 退出）：${RES}"
                case "$OS_TYPE" in
                    "linux"|"windows")
                        if [[ "$SYSTEMD_AVAILABLE" == "true" ]]; then
                            journalctl -u openlist -f
                        else
                            echo -e "${YELLOW_COLOR}无法获取实时日志${RES}"
                        fi
                        ;;
                    "macos")
                        log stream --predicate 'process == "openlist"'
                        ;;
                    "termux")
                        if [[ -f "$INSTALL_PATH/openlist.log" ]]; then
                            tail -f "$INSTALL_PATH/openlist.log"
                        else
                            echo -e "${YELLOW_COLOR}未找到日志文件${RES}"
                        fi
                        ;;
                esac
                ;;
            3)
                echo -e "${BLUE_COLOR}错误日志：${RES}"
                case "$OS_TYPE" in
                    "linux"|"windows")
                        if [[ "$SYSTEMD_AVAILABLE" == "true" ]]; then
                            journalctl -u openlist --no-pager -p err
                        else
                            echo -e "${YELLOW_COLOR}无法获取错误日志${RES}"
                        fi
                        ;;
                    "macos")
                        log show --predicate 'process == "openlist" AND messageType == 16' --last 1h
                        ;;
                    "termux")
                        if [[ -f "$INSTALL_PATH/openlist.log" ]]; then
                            grep -i error "$INSTALL_PATH/openlist.log" | tail -20
                        else
                            echo -e "${YELLOW_COLOR}未找到日志文件${RES}"
                        fi
                        ;;
                esac
                ;;
            4)
                echo -e "${BLUE_COLOR}查找初始密码：${RES}"
                local password=""
                case "$OS_TYPE" in
                    "linux"|"windows")
                        if [[ "$SYSTEMD_AVAILABLE" == "true" ]]; then
                            password=$(journalctl -u openlist --no-pager | grep -i "initial password is:" | tail -1 | sed 's/.*initial password is: //')
                        fi
                        ;;
                    "macos")
                        password=$(log show --predicate 'process == "openlist"' --last 1h | grep -i "initial password is:" | tail -1 | sed 's/.*initial password is: //')
                        ;;
                    "termux")
                        if [[ -f "$INSTALL_PATH/openlist.log" ]]; then
                            password=$(grep -i "initial password is:" "$INSTALL_PATH/openlist.log" | tail -1 | sed 's/.*initial password is: //')
                        fi
                        ;;
                esac
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
        read -r -p "按回车键继续..." < /dev/tty
        break
    done
}

# 备份配置
backup_config() {
    echo -e "${CYAN_COLOR}配置备份${RES}"
    
    if [ ! -d "$INSTALL_PATH/data" ]; then
        echo -e "${RED_COLOR}错误：未找到配置目录${RES}"
        read -r -p "按回车键继续..." < /dev/tty
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
    
    read -r -p "按回车键继续..." < /dev/tty
}

# 恢复配置
restore_config() {
    echo -e "${CYAN_COLOR}配置恢复${RES}"
    
    read -r -p "请输入备份目录路径: " backup_path < /dev/tty
    
    if [ ! -d "$backup_path/data" ]; then
        echo -e "${RED_COLOR}错误：备份目录不存在${RES}"
        read -r -p "按回车键继续..." < /dev/tty
        return
    fi
    
    echo -e "${YELLOW_COLOR}警告：此操作将覆盖当前配置${RES}"
    read -r -p "确认恢复？[y/N]: " confirm < /dev/tty
    
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
    
    read -r -p "按回车键继续..." < /dev/tty
}

# 重置密码
reset_password() {
    echo -e "${CYAN_COLOR}重置密码${RES}"
    
    if [ ! -f "$INSTALL_PATH/openlist" ]; then
        echo -e "${RED_COLOR}错误：OpenList 未安装${RES}"
        read -r -p "按回车键继续..." < /dev/tty
        return
    fi
    
    echo -e "${RED_COLOR}注意：重置密码将删除数据库文件${RES}"
    echo -e "${YELLOW_COLOR}这将会丢失所有配置和数据！${RES}"
    echo
    read -r -p "确认重置密码？请输入 'RESET': " confirm < /dev/tty
    
    if [ "$confirm" != "RESET" ]; then
        echo -e "${YELLOW_COLOR}已取消重置${RES}"
        read -r -p "按回车键继续..." < /dev/tty
        return
    fi
    
    echo -e "${BLUE_COLOR}正在重置密码...${RES}"
    
    # 停止服务
    stop_service
    
    # 备份数据库
    if [ -f "$INSTALL_PATH/data/data.db" ]; then
        cp "$INSTALL_PATH/data/data.db" "$INSTALL_PATH/data/data.db.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # 删除数据库文件
    rm -f "$INSTALL_PATH/data/data.db"*
    
    # 启动服务
    start_service
    
    # 等待服务启动
    sleep 5
    
    # 获取新密码
    local new_password=""
    case "$OS_TYPE" in
        "linux"|"windows")
            if [[ "$SYSTEMD_AVAILABLE" == "true" ]]; then
                new_password=$(journalctl -u openlist --since "1 minute ago" | grep -i "initial password is:" | tail -1 | sed 's/.*initial password is: //')
            fi
            ;;
        "macos")
            new_password=$(log show --predicate 'process == "openlist"' --last 1m | grep -i "initial password is:" | tail -1 | sed 's/.*initial password is: //')
            ;;
        "termux")
            if [[ -f "$INSTALL_PATH/openlist.log" ]]; then
                new_password=$(grep -i "initial password is:" "$INSTALL_PATH/openlist.log" | tail -1 | sed 's/.*initial password is: //')
            fi
            ;;
    esac
    
    if [ ! -z "$new_password" ]; then
        echo -e "${GREEN_COLOR}密码重置成功${RES}"
        echo -e "${BLUE_COLOR}新密码：${RES}$new_password"
    else
        echo -e "${YELLOW_COLOR}无法自动获取新密码${RES}"
        echo -e "请查看日志：sudo journalctl -u openlist -f"
    fi
    
    read -r -p "按回车键继续..." < /dev/tty
}

# 管理密码
manage_password() {
    echo -e "${CYAN_COLOR}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    管理管理员密码                            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RES}"

    if [ ! -f "$INSTALL_PATH/openlist" ]; then
        echo -e "${RED_COLOR}错误：OpenList 未安装${RES}"
        read -r -p "按回车键继续..." < /dev/tty
        return
    fi

    echo -e "${BLUE_COLOR}请选择操作：${RES}"
    echo -e "${GREEN_COLOR}1${RES} - 随机生成新密码"
    echo -e "${GREEN_COLOR}2${RES} - 手动设置新密码"
    echo -e "${GREEN_COLOR}3${RES} - 返回"
    echo

    local choice
    while true; do
        read -r -p "请输入选项 [1-3]: " choice < /dev/tty
        case "$choice" in
            1)
                echo -e "${BLUE_COLOR}正在生成随机密码...${RES}"
                local output
                output=$($INSTALL_PATH/openlist admin random)
                
                echo -e "${GREEN_COLOR}操作完成！${RES}"
                echo -e "${BLUE_COLOR}命令输出:${RES}"
                echo -e "$output"

                local new_password
                new_password=$(echo "$output" | grep -i "new password" | awk -F': ' '{print $2}')
                if [ -n "$new_password" ]; then
                    echo -e "${GREEN_COLOR}成功生成新密码: $new_password${RES}"
                else
                    echo -e "${YELLOW_COLOR}无法从输出中自动提取密码，请查看上面的完整命令输出。${RES}"
                fi
                break
                ;;
            2)
                local new_password
                read -r -p "请输入新的管理员密码: " new_password < /dev/tty
                if [ -z "$new_password" ]; then
                    echo -e "${RED_COLOR}密码不能为空！${RES}"
                    continue
                fi

                echo -e "${BLUE_COLOR}正在设置新密码...${RES}"
                $INSTALL_PATH/openlist admin set "$new_password"
                echo -e "${GREEN_COLOR}密码设置命令已执行。${RES}"
                echo -e "${YELLOW_COLOR}请尝试使用新密码登录以验证是否成功。${RES}"
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

    read -r -p "按回车键继续..." < /dev/tty
}

# 控制服务
control_service() {
    local action=$1
    local action_desc=$2
    
    echo -e "${CYAN_COLOR}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    OpenList 服务控制                         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RES}"
    
    if [ ! -f "$INSTALL_PATH/openlist" ]; then
        echo -e "${RED_COLOR}错误：OpenList 未安装${RES}"
        read -r -p "按回车键继续..." < /dev/tty
        return
    fi
    
    case "$action" in
        start)
            echo -e "${BLUE_COLOR}正在启动 OpenList 服务...${RES}"
            start_service
            ;;
        stop)
            echo -e "${BLUE_COLOR}正在停止 OpenList 服务...${RES}"
            stop_service
            ;;
        restart)
            echo -e "${BLUE_COLOR}正在重启 OpenList 服务...${RES}"
            stop_service
            sleep 2
            start_service
            ;;
        *)
            echo -e "${RED_COLOR}无效的操作${RES}"
            read -r -p "按回车键继续..." < /dev/tty
            return
            ;;
    esac
    
    # 等待服务状态变化
    sleep 2
    
    # 检查服务状态
    if check_service_status; then
        echo -e "${GREEN_COLOR}OpenList 服务已成功${action_desc}${RES}"
    else
        echo -e "${RED_COLOR}OpenList 服务${action_desc}失败${RES}"
    fi
    
    read -r -p "按回车键继续..." < /dev/tty
}

# 迁移 Alist 数据
migrate_alist_data() {
    echo -e "${CYAN_COLOR}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    Alist 数据迁移                            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RES}"
    
    if [ ! -f "$INSTALL_PATH/openlist" ]; then
        echo -e "${RED_COLOR}错误：OpenList 未安装${RES}"
        read -r -p "按回车键继续..." < /dev/tty
        return
    fi
    
    # 检查 Alist 是否安装
    if [ ! -f "/opt/alist/alist" ]; then
        echo -e "${RED_COLOR}错误：未找到 Alist 安装${RES}"
        echo -e "${YELLOW_COLOR}请确保 Alist 已安装在 /opt/alist 目录${RES}"
        read -r -p "按回车键继续..." < /dev/tty
        return
    fi
    
    echo -e "${YELLOW_COLOR}警告：此操作将迁移 Alist 的配置数据到 OpenList${RES}"
    echo -e "${YELLOW_COLOR}建议在迁移前备份 Alist 数据${RES}"
    echo
    read -r -p "确认迁移？[y/N]: " confirm < /dev/tty
    
    case "$confirm" in
        [yY])
            # 停止两个服务
            echo -e "${BLUE_COLOR}停止服务...${RES}"
            case "$OS_TYPE" in
                "linux")
                    if [[ "$SYSTEMD_AVAILABLE" == "true" ]]; then
                        systemctl stop alist 2>/dev/null
                    else
                        echo -e "${YELLOW_COLOR}请手动停止 Alist 服务${RES}"
                    fi
                    ;;
                *)
                    echo -e "${YELLOW_COLOR}请手动停止 Alist 服务${RES}"
                    ;;
            esac
            stop_service
            
            # 备份 OpenList 数据
            echo -e "${BLUE_COLOR}备份 OpenList 数据...${RES}"
            if [ -d "$INSTALL_PATH/data" ]; then
                mv "$INSTALL_PATH/data" "$INSTALL_PATH/data.backup.$(date +%Y%m%d_%H%M%S)"
            fi
            
            # 创建数据目录
            mkdir -p "$INSTALL_PATH/data"
            
            # 复制 Alist 数据
            echo -e "${BLUE_COLOR}迁移数据...${RES}"
            if [ -f "/opt/alist/data/data.db" ]; then
                cp "/opt/alist/data/data.db" "$INSTALL_PATH/data/"
                echo -e "${GREEN_COLOR}数据库迁移成功${RES}"
            else
                echo -e "${RED_COLOR}未找到 Alist 数据库文件${RES}"
            fi
            
            if [ -f "/opt/alist/data/config.json" ]; then
                cp "/opt/alist/data/config.json" "$INSTALL_PATH/data/"
                echo -e "${GREEN_COLOR}配置文件迁移成功${RES}"
            else
                echo -e "${RED_COLOR}未找到 Alist 配置文件${RES}"
            fi
            
            # 设置权限
            chown -R root:root "$INSTALL_PATH/data"
            chmod -R 755 "$INSTALL_PATH/data"
            
            # 启动 OpenList
            echo -e "${BLUE_COLOR}启动 OpenList 服务...${RES}"
            start_service
            
            echo -e "${GREEN_COLOR}数据迁移完成${RES}"
            echo -e "${YELLOW_COLOR}请检查 OpenList 是否正常运行${RES}"
            ;;
        *)
            echo -e "${YELLOW_COLOR}已取消迁移${RES}"
            ;;
    esac
    
    read -r -p "按回车键继续..." < /dev/tty
}

# 检查系统空间
check_disk_space() {
    echo -e "${BLUE_COLOR}检查系统空间...${RES}"
    
    # 检查 /tmp 目录空间
    local tmp_space=$(df -h /tmp | awk 'NR==2 {print $4}')
    local tmp_space_mb=$(df /tmp | awk 'NR==2 {print $4}')
    
    # 检查当前目录空间
    local current_space=$(df -h . | awk 'NR==2 {print $4}')
    local current_space_mb=$(df . | awk 'NR==2 {print $4}')
    
    if [ $tmp_space_mb -lt 102400 ] || [ $current_space_mb -lt 102400 ]; then
        echo -e "${RED_COLOR}警告：系统空间不足${RES}"
        echo -e "临时目录可用空间: $tmp_space"
        echo -e "当前目录可用空间: $current_space"
        echo -e "${YELLOW_COLOR}建议清理系统空间后再继续${RES}"
        read -r -p "是否继续？[y/N]: " continue_choice < /dev/tty
        case "$continue_choice" in
            [yY])
                return 0
                ;;
            *)
                exit 1
                ;;
        esac
    fi
}

# ===================== Docker 相关函数 =====================

# 检查 Docker 是否安装
check_docker_installed() {
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${YELLOW_COLOR}未检测到 Docker，正在自动安装...${RES}"
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            if [[ $ID == "ubuntu" || $ID == "debian" ]]; then
                apt update && apt install -y docker.io || handle_error 1 "Docker 安装失败"
            elif [[ $ID == "centos" || $ID == "rhel" ]]; then
                yum install -y docker || handle_error 1 "Docker 安装失败"
            else
                echo -e "${RED_COLOR}不支持的系统，请手动安装 Docker${RES}"
                exit 1
            fi
        fi
        systemctl enable docker && systemctl start docker
        echo -e "${GREEN_COLOR}Docker 安装完成${RES}"
    else
        echo -e "${GREEN_COLOR}已检测到 Docker${RES}"
    fi
}

# 通过镜像名查找 OpenList 容器ID
find_openlist_container() {
    docker ps -a --format '{{.ID}} {{.Image}} {{.Names}}' | grep "ghcr.io/openlistteam/openlist-git:$DOCKER_IMAGE_TAG" | awk '{print $1}' | head -n1
}

# 通过镜像名查找 OpenList 容器名称
find_openlist_container_name() {
    docker ps -a --format '{{.ID}} {{.Image}} {{.Names}}' | grep "ghcr.io/openlistteam/openlist-git:$DOCKER_IMAGE_TAG" | awk '{print $3}' | head -n1
}

# 拉取镜像并运行容器
install_openlist_docker() {
    select_docker_image_tag
    check_docker_installed
    echo -e "${BLUE_COLOR}拉取 OpenList 镜像...${RES}"
    docker pull ghcr.io/openlistteam/openlist-git:$DOCKER_IMAGE_TAG || handle_error 1 "镜像拉取失败"
    # 检查是否已存在容器
    local cid=$(find_openlist_container)
    if [ -n "$cid" ]; then
        echo -e "${YELLOW_COLOR}已存在 OpenList 容器，尝试启动...${RES}"
        docker start $(find_openlist_container_name)
    else
        echo -e "${BLUE_COLOR}创建并启动 OpenList 容器...${RES}"
        docker run -d --name openlist -p 5244:5244 --restart unless-stopped ghcr.io/openlistteam/openlist-git:$DOCKER_IMAGE_TAG || handle_error 1 "容器启动失败"
    fi
    echo -e "${GREEN_COLOR}OpenList Docker 容器已启动 (镜像: $DOCKER_IMAGE_TAG)${RES}"
    sleep 2
}

# 进入容器
exec_openlist_docker() {
    check_docker_installed
    local cname=$(find_openlist_container_name)
    if [ -z "$cname" ]; then
        echo -e "${RED_COLOR}未找到 OpenList 容器${RES}"
        return
    fi
    echo -e "${YELLOW_COLOR}提示：进入容器后，输入 exit 可返回本脚本交互界面，无需重新运行脚本。${RES}"
    echo -e "${BLUE_COLOR}进入 OpenList 容器...${RES}"
    docker exec -it "$cname" /bin/sh
}

# 在容器内设置管理员密码
set_password_openlist_docker() {
    check_docker_installed
    local cname=$(find_openlist_container_name)
    if [ -z "$cname" ]; then
        echo -e "${RED_COLOR}未找到 OpenList 容器${RES}"
        return
    fi
    read -r -p "请输入新的管理员密码: " new_password < /dev/tty
    if [ -z "$new_password" ]; then
        echo -e "${RED_COLOR}密码不能为空${RES}"
        return
    fi
    docker exec "$cname" ./openlist admin set "$new_password"
    echo -e "${GREEN_COLOR}已在容器内设置新密码${RES}"
}

# 重启容器
restart_openlist_docker() {
    check_docker_installed
    local cname=$(find_openlist_container_name)
    if [ -z "$cname" ]; then
        echo -e "${RED_COLOR}未找到 OpenList 容器${RES}"
        return
    fi
    docker restart "$cname"
    echo -e "${GREEN_COLOR}OpenList 容器已重启${RES}"
}

# 查看容器状态
status_openlist_docker() {
    check_docker_installed
    echo -e "${BLUE_COLOR}所有 OpenList 相关容器状态：${RES}"
    local found=0
    docker ps -a --format '状态: {{.Status}}  名称: {{.Names}}  镜像: {{.Image}}  端口: {{.Ports}}  创建时间: {{.CreatedAt}}' | \
    grep -E 'ghcr.io/openlistteam/openlist-git:(beta|beta-ffmpeg|beta-aio|beta-aria2)' && found=1
    if [ $found -eq 0 ]; then
        echo -e "${YELLOW_COLOR}未找到任何 OpenList 官方镜像容器${RES}"
    fi
    read -r -p "按回车键返回菜单..." < /dev/tty
}

# 查看容器日志
logs_openlist_docker() {
    check_docker_installed
    local cname=$(find_openlist_container_name)
    if [ -z "$cname" ]; then
        echo -e "${RED_COLOR}未找到 OpenList 容器${RES}"
        read -r -p "按回车键返回菜单..." < /dev/tty
        return
    fi
    echo -e "${BLUE_COLOR}显示 OpenList 容器最近20条日志：${RES}"
    docker logs --tail 20 "$cname"
    read -r -p "按回车键返回菜单..." < /dev/tty
}

# 检查 Docker 是否已安装
is_docker_installed() {
    if command -v docker >/dev/null 2>&1; then
        echo -e "${GREEN_COLOR}Docker 已安装${RES}"
        return 0
    else
        echo -e "${YELLOW_COLOR}Docker 未安装${RES}"
        return 1
    fi
}

# 检查 OpenList Docker 容器是否已安装
is_openlist_docker_installed() {
    local count=$(docker ps -a --format '{{.Image}}' 2>/dev/null | grep -E 'ghcr.io/openlistteam/openlist-git:(beta|beta-ffmpeg|beta-aio|beta-aria2)' | wc -l)
    if [ "$count" -gt 0 ]; then
        echo -e "${GREEN_COLOR}OpenList Docker 容器已安装${RES}"
        return 0
    else
        echo -e "${YELLOW_COLOR}OpenList Docker 容器未安装${RES}"
        return 1
    fi
}

# 检查 OpenList 二进制文件是否已下载
is_openlist_binary_downloaded() {
    if [ "$OS_TYPE" = "termux" ]; then
        # Termux 环境下检查 pkg 安装的 OpenList
        if command -v openlist >/dev/null 2>&1; then
            echo -e "${GREEN_COLOR}OpenList 已安装 (pkg 安装)${RES}"
            return 0
        elif [ -f "$INSTALL_PATH/openlist" ]; then
            echo -e "${GREEN_COLOR}OpenList 二进制文件已下载 (手动安装)${RES}"
            return 0
        else
            echo -e "${YELLOW_COLOR}OpenList 未安装${RES}"
            return 1
        fi
    else
        # 其他环境检查手动安装的文件
        if [ -f "$INSTALL_PATH/openlist" ]; then
            echo -e "${GREEN_COLOR}OpenList 二进制文件已下载${RES}"
            return 0
        else
            echo -e "${YELLOW_COLOR}OpenList 二进制文件未下载${RES}"
            return 1
        fi
    fi
}

# 检查 OpenList 服务是否正在运行
is_openlist_service_running() {
    if [ "$OS_TYPE" = "termux" ]; then
        # Termux 环境下检查 OpenList 进程
        if pgrep -f "openlist server" >/dev/null 2>&1; then
            echo -e "${GREEN_COLOR}OpenList 服务正在运行${RES}"
            return 0
        else
            echo -e "${YELLOW_COLOR}OpenList 服务未运行${RES}"
            return 1
        fi
    else
        # 其他环境检查系统服务
        if check_service_status; then
            echo -e "${GREEN_COLOR}OpenList 服务正在运行${RES}"
            return 0
        else
            echo -e "${YELLOW_COLOR}OpenList 服务未运行${RES}"
            return 1
        fi
    fi
}

# 检查 Nginx 是否已安装
is_nginx_installed() {
    if command -v nginx >/dev/null 2>&1; then
        echo -e "${GREEN_COLOR}Nginx 已安装${RES}"
        return 0
    else
        echo -e "${YELLOW_COLOR}Nginx 未安装${RES}"
        return 1
    fi
}

# 获取本机公网IP
get_local_ip() {
    curl -s https://api.ipify.org || hostname -I | awk '{print $1}'
}

# 一键安装 Nginx
nginx_check_and_install() {
    if command -v nginx >/dev/null 2>&1; then
        echo -e "${GREEN_COLOR}Nginx 已安装${RES}"
        return 0
    fi
    echo -e "${YELLOW_COLOR}Nginx 未安装，是否一键安装？${RES}"
    read -r -p "安装 Nginx？[Y/n]: " confirm < /dev/tty
    case "${confirm:-y}" in
        [yY]|"")
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                if [[ $ID == "ubuntu" || $ID == "debian" ]]; then
                    apt update && apt install -y nginx || handle_error 1 "Nginx 安装失败"
                elif [[ $ID == "centos" || $ID == "rhel" ]]; then
                    yum install -y nginx || handle_error 1 "Nginx 安装失败"
                else
                    echo -e "${RED_COLOR}不支持的系统，请手动安装 Nginx${RES}"
                    return 1
                fi
            fi
            systemctl enable nginx && systemctl start nginx
            echo -e "${GREEN_COLOR}Nginx 安装完成${RES}"
            ;;
        *)
            echo -e "${YELLOW_COLOR}已取消安装 Nginx${RES}"
            return 1
            ;;
    esac
}

# 配置 Nginx 反向代理
setup_nginx_proxy() {
    nginx_check_and_install || return
    read -r -p "请输入要绑定的域名: " domain < /dev/tty
    if [ -z "$domain" ]; then
        echo -e "${RED_COLOR}域名不能为空${RES}"
        return
    fi
    # 生成 Nginx 配置
    local conf_path="/etc/nginx/conf.d/openlist_${domain}.conf"
    cat > "$conf_path" <<EOF
server {
    listen 80;
    server_name $domain;
    location / {
        proxy_pass http://127.0.0.1:5244;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    nginx -t && systemctl reload nginx
    echo -e "${GREEN_COLOR}Nginx 反向代理配置已生成并重载${RES}"
    local ip=$(get_local_ip)
    echo -e "${YELLOW_COLOR}请在域名服务商处将 $domain 的A记录指向本机IP: $ip${RES}"
    echo -e "配置完成后可通过 http://$domain 访问 OpenList"
    read -r -p "按回车键返回菜单..." < /dev/tty
}

# 域名绑定/反代菜单
show_domain_proxy_menu() {
    while true; do
        clear
        echo -e "${CYAN_COLOR}"
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                域名绑定与 Nginx 反向代理设置                 ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo -e "${RES}"
        echo -e "${GREEN_COLOR}1${RES} - 一键配置域名反向代理"
        echo -e "${GREEN_COLOR}0${RES} - 返回主菜单"
        echo
        choice=$(default_read "请输入选项 [0-1] (默认0): " "0")
        case "$choice" in
            1)
                setup_nginx_proxy
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED_COLOR}无效选项，请重新选择${RES}"
                sleep 1
                ;;
        esac
    done
}

# 主菜单
show_main_menu() {
    while true; do
        clear
        echo -e "${CYAN_COLOR}"
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                    OpenList 管理脚本                         ║"
        echo "║                                                              ║"
        echo "║                   Interactive Manager v${MANAGER_VERSION}                ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo -e "${RES}"
        # 添加提示信息
        echo -e "${YELLOW_COLOR}* 提示：输入 'openlist' 可再次唤出脚本${RES}"
        echo
        # 关键组件状态
        is_openlist_binary_downloaded
        is_openlist_service_running
        is_docker_installed
        is_openlist_docker_installed
        is_nginx_installed
        show_domain_bind_status
        echo
        # 推荐安装方式
        echo -e "${BLUE_COLOR}推荐安装方式：${RES}"
        echo -e "  1. ${GREEN_COLOR}二进制文件服务模式（适合大多数用户，兼容性好）${RES}"
        echo -e "  2. ${GREEN_COLOR}Docker 安装（适合有 Docker 环境的用户，隔离性强）${RES}"
        echo
        echo -e "${PURPLE_COLOR}═══ 二进制文件服务模式 ═══${RES}"
        echo -e "${GREEN_COLOR}1${RES}  - 安装 OpenList"
        echo -e "${GREEN_COLOR}2${RES}  - 更新 OpenList"
        echo -e "${GREEN_COLOR}3${RES}  - 卸载 OpenList"
        echo -e "${GREEN_COLOR}4${RES}  - 迁移 Alist 数据到 OpenList"
        echo -e "${GREEN_COLOR}5${RES}  - 启动服务"
        echo -e "${GREEN_COLOR}6${RES}  - 停止服务"
        echo -e "${GREEN_COLOR}7${RES}  - 重启服务"
        echo -e "${GREEN_COLOR}8${RES}  - 查看状态"
        echo -e "${GREEN_COLOR}9${RES}  - 查看日志"
        echo
        echo -e "${PURPLE_COLOR}═══ Docker 管理 ═══${RES}"
        echo -e "${GREEN_COLOR}10${RES} - Docker 一键安装/启动 OpenList"
        echo -e "${GREEN_COLOR}11${RES} - 进入 OpenList 容器"
        echo -e "${GREEN_COLOR}12${RES} - 容器内设置管理员密码"
        echo -e "${GREEN_COLOR}13${RES} - 重启 OpenList 容器"
        echo -e "${GREEN_COLOR}14${RES} - 查看容器状态"
        echo -e "${GREEN_COLOR}15${RES} - 查看容器日志"
        echo
        echo -e "${PURPLE_COLOR}═══ 域名绑定/反向代理 ═══${RES}"
        echo -e "${GREEN_COLOR}16${RES} - 域名绑定/反代设置"
        echo
        echo -e "${PURPLE_COLOR}═══ 定时自动更新 ═══${RES}"
        echo -e "${GREEN_COLOR}17${RES} - 定时自动更新设置"
        echo
        echo -e "${GREEN_COLOR}0${RES}  - 退出脚本"
        echo
        local choice
        choice=$(default_read "请输入选项 [0-17] (默认0): " "0")
        echo -e "${YELLOW_COLOR}[调试] 输入的选项: '$choice'${RES}"
        if [ -z "$choice" ]; then
            choice=0
        fi
        if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            echo -e "${RED_COLOR}请输入数字选项 [0-17]${RES}"
            sleep 2
            continue
        fi
        case "$choice" in
            1) check_disk_space && install_openlist ;;
            2) check_disk_space && update_openlist ;;
            3) uninstall_openlist ;;
            4) check_disk_space && migrate_alist_data ;;
            5) control_service start "启动" ;;
            6) control_service stop "停止" ;;
            7) control_service restart "重启" ;;
            8) show_status ;;
            9) show_logs ;;
            10) install_openlist_docker ;;
            11) exec_openlist_docker ;;
            12) set_password_openlist_docker ;;
            13) restart_openlist_docker ;;
            14) status_openlist_docker ;;
            15) logs_openlist_docker ;;
            16) show_domain_proxy_menu ;;
            17) show_auto_update_menu ;;
            0) 
                echo -e "${GREEN_COLOR}谢谢使用！${RES}"
                echo -e "${YELLOW_COLOR}* 提示：如需再次使用，请输入 'openlist' 命令${RES}"
                exit 0 
                ;;
            *) echo -e "${RED_COLOR}无效选项，请重新选择${RES}"; echo -e "${YELLOW_COLOR}[调试] 无效选项: '$choice'${RES}"; sleep 2 ;;
        esac
    done
}

# 定时自动更新相关函数
CRON_MARK_BIN='# OpenList二进制自动更新'
CRON_MARK_DOCKER='# OpenList Docker自动更新'

# 非交互式更新函数
non_interactive_update() {
    local mode=$1
    
    if [ "$mode" = "bin" ]; then
        # 非交互式二进制更新
        if [ ! -f "$INSTALL_PATH/openlist" ]; then
            echo "OpenList 未安装，跳过更新"
            return 1
        fi
        
        # 获取最新正式版 release
        local latest_release=$(curl -s https://api.github.com/repos/OpenListTeam/OpenList/releases/latest | grep 'tag_name' | head -1 | cut -d '"' -f4)
        if [ -z "$latest_release" ]; then
            echo "无法获取最新版本，跳过更新"
            return 1
        fi
        
        # 检查当前版本
        local current_version="beta"
        if [ -f "$VERSION_FILE" ]; then
            current_version=$(head -n1 "$VERSION_FILE" 2>/dev/null || echo "beta")
        fi
        
        if [ "$latest_release" = "$current_version" ]; then
            echo "当前已是最新版本: $current_version"
            return 0
        fi
        
        echo "开始自动更新到: $latest_release"
        
        # 停止服务
        stop_service
        
        # 下载新版本
        local download_url="https://github.com/${GITHUB_REPO}/releases/download/${latest_release}/openlist-linux-$ARCH.tar.gz"
        if ! download_file "$download_url" "/tmp/openlist.tar.gz"; then
            echo "下载失败，恢复服务"
            start_service
            return 1
        fi
        
        # 备份
        cp "$INSTALL_PATH/openlist" "/tmp/openlist.bak"
        
        # 解压
        if ! tar zxf /tmp/openlist.tar.gz -C "$INSTALL_PATH/"; then
            echo "解压失败，恢复服务"
            mv "/tmp/openlist.bak" "$INSTALL_PATH/openlist"
            start_service
            rm -f /tmp/openlist.tar.gz
            return 1
        fi
        
        # 验证更新
        if [ ! -f "$INSTALL_PATH/openlist" ]; then
            echo "更新失败，恢复服务"
            mv "/tmp/openlist.bak" "$INSTALL_PATH/openlist"
            start_service
            return 1
        fi
        
        # 设置权限
        chmod +x "$INSTALL_PATH/openlist"
        
        # 更新版本信息
        echo "$latest_release" > "$VERSION_FILE"
        echo "$(date '+%Y-%m-%d %H:%M:%S')" >> "$VERSION_FILE"
        
        # 启动服务
        start_service
        
        # 清理文件
        rm -f /tmp/openlist.tar.gz /tmp/openlist.bak
        
        echo "自动更新成功: $latest_release"
        return 0
        
    elif [ "$mode" = "docker" ]; then
        # 非交互式 Docker 更新
        if ! command -v docker >/dev/null 2>&1; then
            echo "Docker 未安装，跳过更新"
            return 1
        fi
        
        local cname=$(find_openlist_container_name)
        if [ -z "$cname" ]; then
            echo "未找到 OpenList 容器，跳过更新"
            return 1
        fi
        
        echo "开始自动更新 Docker 容器"
        
        # 拉取最新镜像
        docker pull ghcr.io/openlistteam/openlist-git:beta
        
        # 停止并删除旧容器
        docker stop "$cname"
        docker rm "$cname"
        
        # 创建新容器
        docker run -d --name openlist -p 5244:5244 --restart unless-stopped ghcr.io/openlistteam/openlist-git:beta
        
        echo "Docker 自动更新成功"
        return 0
    fi
    
    return 1
}

setup_cron_update() {
    local mode=$1
    local schedule=$2
    local cmd
    if [ "$mode" = "bin" ]; then
        # 修改为非交互式更新命令
        cmd="curl -fsSL \"https://raw.githubusercontent.com/ypq123456789/openlist-manger/refs/heads/main/openlist.sh\" | sudo bash -s -- non_interactive_update bin"
        mark="$CRON_MARK_BIN"
    else
        # 修改为非交互式 Docker 更新命令
        cmd="curl -fsSL \"https://raw.githubusercontent.com/ypq123456789/openlist-manger/refs/heads/main/openlist.sh\" | sudo bash -s -- non_interactive_update docker"
        mark="$CRON_MARK_DOCKER"
    fi
    (crontab -l 2>/dev/null | grep -v "$mark"; echo "$schedule $cmd $mark") | crontab -
    echo -e "${GREEN_COLOR}定时自动更新任务已设置：$schedule${RES}"
    echo -e "${BLUE_COLOR}命令：$cmd${RES}"
}

remove_cron_update() {
    local mark=$1
    crontab -l 2>/dev/null | grep -v "$mark" | crontab -
    echo -e "${YELLOW_COLOR}已取消对应的定时自动更新任务${RES}"
}

show_cron_update_status() {
    echo -e "${BLUE_COLOR}当前定时自动更新任务：${RES}"
    crontab -l 2>/dev/null | grep -E "$CRON_MARK_BIN|$CRON_MARK_DOCKER" && return
    echo -e "${YELLOW_COLOR}未设置任何自动更新任务${RES}"
}

show_auto_update_menu() {
    while true; do
        clear
        echo -e "${CYAN_COLOR}"
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                  定时自动更新设置                            ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo -e "${RES}"
        echo -e "${BLUE_COLOR}请选择自动更新模式：${RES}"
        echo -e "${GREEN_COLOR}1${RES} - 二进制文件服务模式自动更新"
        echo -e "${GREEN_COLOR}2${RES} - Docker 模式自动更新"
        echo -e "${GREEN_COLOR}3${RES} - 查看当前定时任务"
        echo -e "${GREEN_COLOR}4${RES} - 取消二进制自动更新"
        echo -e "${GREEN_COLOR}5${RES} - 取消 Docker 自动更新"
        echo -e "${GREEN_COLOR}0${RES} - 返回主菜单"
        echo
        choice=$(default_read "请输入选项 [0-5] (默认0): " "0")
        case "$choice" in
            1|2)
                local mode="bin"
                [ "$choice" = "2" ] && mode="docker"
                echo -e "${BLUE_COLOR}请选择更新频率：${RES}"
                echo -e "${GREEN_COLOR}1${RES} - 每小时更新"
                echo -e "${GREEN_COLOR}2${RES} - 每3小时更新"
                echo -e "${GREEN_COLOR}3${RES} - 每天更新"
                echo -e "${GREEN_COLOR}4${RES} - 每周更新"
                echo -e "${GREEN_COLOR}5${RES} - 自定义 crontab 表达式"
                freq=$(default_read "请选择 [1-5] (默认3): " "3")
                local schedule
                case "$freq" in
                    1) schedule="0 * * * *";;
                    2) schedule="0 */3 * * *";;
                    3) schedule="0 3 * * *";;
                    4) schedule="0 3 * * 0";;
                    5)
                        schedule=$(default_read "请输入自定义 crontab 时间表达式: " "0 3 * * *")
                        ;;
                    *)
                        echo -e "${RED_COLOR}无效选项${RES}"
                        continue
                        ;;
                esac
                setup_cron_update "$mode" "$schedule"
                read -r -p "按回车键返回菜单..." < /dev/tty
                ;;
            3)
                show_cron_update_status
                read -r -p "按回车键返回菜单..." < /dev/tty
                ;;
            4)
                remove_cron_update "$CRON_MARK_BIN"
                read -r -p "按回车键返回菜单..." < /dev/tty
                ;;
            5)
                remove_cron_update "$CRON_MARK_DOCKER"
                read -r -p "按回车键返回菜单..." < /dev/tty
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED_COLOR}无效选项${RES}"
                sleep 1
                ;;
        esac
    done
}

show_domain_bind_status() {
    local conf_dir="/etc/nginx/conf.d"
    local domain_files=$(ls $conf_dir/openlist_*.conf 2>/dev/null)
    if [ -z "$domain_files" ]; then
        echo -e "${YELLOW_COLOR}域名绑定状态：未绑定域名${RES}"
    else
        local domains=""
        for f in $domain_files; do
            local d=$(grep -Eo 'server_name[ ]+[^;]+' "$f" | awk '{print $2}')
            [ -n "$d" ] && domains+="$d, "
        done
        domains=${domains%, }
        echo -e "${GREEN_COLOR}域名绑定状态：已绑定域名：$domains${RES}"
    fi
}

# 1. 优化所有菜单和输入，回车直接选择默认选项
# 2. 优化版本检查逻辑，自动从 GitHub releases 获取最新版本

# --- 版本检查函数 ---
check_latest_version() {
    echo -e "${BLUE_COLOR}正在检查 OpenList 最新版本...${RES}"
    local latest_version
    latest_version=$(curl -s https://api.github.com/repos/OpenListTeam/OpenList/releases/latest | grep 'tag_name' | head -1 | cut -d '"' -f4)
    if [ -z "$latest_version" ]; then
        echo -e "${YELLOW_COLOR}无法获取最新版本信息，跳过检查${RES}"
        return
    fi
    if [ "$latest_version" != "$VERSION_TAG" ]; then
        echo -e "${YELLOW_COLOR}发现新版本: $latest_version (当前: $VERSION_TAG)${RES}"
        echo -e "${YELLOW_COLOR}建议前往 https://github.com/OpenListTeam/OpenList/releases 下载或更新${RES}"
    else
        echo -e "${GREEN_COLOR}当前已是最新版本: $VERSION_TAG${RES}"
    fi
}

# --- 优化菜单输入函数 ---
# 用于所有菜单，支持回车默认选项
default_read() {
    local prompt="$1"
    local default="$2"
    local input
    read -r -p "$prompt" input < /dev/tty
    if [ -z "$input" ]; then
        input="$default"
    fi
    echo "$input"
}

# --- 替换所有菜单输入为 default_read ---
# 以 select_version 为例
select_version() {
    echo -e "${PURPLE_COLOR}请选择要使用的版本：${RES}"
    echo -e "${GREEN_COLOR}1${RES} - beta (推荐，最新功能)"
    echo -e "${GREEN_COLOR}2${RES} - 查看所有可用版本"
    echo -e "${GREEN_COLOR}3${RES} - 手动输入版本标签"
    echo -e "${GREEN_COLOR}4${RES} - 返回主菜单"
    echo
    while true; do
        local version_choice
        version_choice=$(default_read "请输入选项 [1-4] (默认1): " "1")
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
                    local custom_version
                    custom_version=$(default_read "请输入要使用的版本标签 (默认beta): " "beta")
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
                local custom_version
                custom_version=$(default_read "请输入版本标签 (如: beta, v1.0.0，默认beta): " "beta")
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

# --- 在主菜单和其他菜单调用 default_read 替换 read -r -p ---
# 以主菜单为例
show_main_menu() {
    while true; do
        clear
        echo -e "${CYAN_COLOR}"
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                    OpenList 管理脚本                         ║"
        echo "║                                                              ║"
        echo "║                   Interactive Manager v${MANAGER_VERSION}                ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo -e "${RES}"
        # 添加提示信息
        echo -e "${YELLOW_COLOR}* 提示：输入 'openlist' 可再次唤出脚本${RES}"
        echo
        # 关键组件状态
        is_openlist_binary_downloaded
        is_openlist_service_running
        is_docker_installed
        is_openlist_docker_installed
        is_nginx_installed
        show_domain_bind_status
        echo
        # 推荐安装方式
        echo -e "${BLUE_COLOR}推荐安装方式：${RES}"
        echo -e "  1. ${GREEN_COLOR}二进制文件服务模式（适合大多数用户，兼容性好）${RES}"
        echo -e "  2. ${GREEN_COLOR}Docker 安装（适合有 Docker 环境的用户，隔离性强）${RES}"
        echo
        echo -e "${PURPLE_COLOR}═══ 二进制文件服务模式 ═══${RES}"
        echo -e "${GREEN_COLOR}1${RES}  - 安装 OpenList"
        echo -e "${GREEN_COLOR}2${RES}  - 更新 OpenList"
        echo -e "${GREEN_COLOR}3${RES}  - 卸载 OpenList"
        echo -e "${GREEN_COLOR}4${RES}  - 迁移 Alist 数据到 OpenList"
        echo -e "${GREEN_COLOR}5${RES}  - 启动服务"
        echo -e "${GREEN_COLOR}6${RES}  - 停止服务"
        echo -e "${GREEN_COLOR}7${RES}  - 重启服务"
        echo -e "${GREEN_COLOR}8${RES}  - 查看状态"
        echo -e "${GREEN_COLOR}9${RES}  - 查看日志"
        echo
        echo -e "${PURPLE_COLOR}═══ Docker 管理 ═══${RES}"
        echo -e "${GREEN_COLOR}10${RES} - Docker 一键安装/启动 OpenList"
        echo -e "${GREEN_COLOR}11${RES} - 进入 OpenList 容器"
        echo -e "${GREEN_COLOR}12${RES} - 容器内设置管理员密码"
        echo -e "${GREEN_COLOR}13${RES} - 重启 OpenList 容器"
        echo -e "${GREEN_COLOR}14${RES} - 查看容器状态"
        echo -e "${GREEN_COLOR}15${RES} - 查看容器日志"
        echo
        echo -e "${PURPLE_COLOR}═══ 域名绑定/反向代理 ═══${RES}"
        echo -e "${GREEN_COLOR}16${RES} - 域名绑定/反代设置"
        echo
        echo -e "${PURPLE_COLOR}═══ 定时自动更新 ═══${RES}"
        echo -e "${GREEN_COLOR}17${RES} - 定时自动更新设置"
        echo
        echo -e "${GREEN_COLOR}0${RES}  - 退出脚本"
        echo
        local choice
        choice=$(default_read "请输入选项 [0-17] (默认0): " "0")
        echo -e "${YELLOW_COLOR}[调试] 输入的选项: '$choice'${RES}"
        if [ -z "$choice" ]; then
            choice=0
        fi
        if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            echo -e "${RED_COLOR}请输入数字选项 [0-17]${RES}"
            sleep 2
            continue
        fi
        case "$choice" in
            1) check_disk_space && install_openlist ;;
            2) check_disk_space && update_openlist ;;
            3) uninstall_openlist ;;
            4) check_disk_space && migrate_alist_data ;;
            5) control_service start "启动" ;;
            6) control_service stop "停止" ;;
            7) control_service restart "重启" ;;
            8) show_status ;;
            9) show_logs ;;
            10) install_openlist_docker ;;
            11) exec_openlist_docker ;;
            12) set_password_openlist_docker ;;
            13) restart_openlist_docker ;;
            14) status_openlist_docker ;;
            15) logs_openlist_docker ;;
            16) show_domain_proxy_menu ;;
            17) show_auto_update_menu ;;
            0) 
                echo -e "${GREEN_COLOR}谢谢使用！${RES}"
                echo -e "${YELLOW_COLOR}* 提示：如需再次使用，请输入 'openlist' 命令${RES}"
                exit 0 
                ;;
            *) echo -e "${RED_COLOR}无效选项，请重新选择${RES}"; echo -e "${YELLOW_COLOR}[调试] 无效选项: '$choice'${RES}"; sleep 2 ;;
        esac
    done
}

# --- 在主程序入口增加版本检查 ---
main() {
    # 处理命令行参数
    if [ $# -gt 0 ]; then
        case "$1" in
            "non_interactive_update")
                if [ -n "$2" ]; then
                    echo "执行非交互式更新: $2"
                    non_interactive_update "$2"
                    exit $?
                else
                    echo "错误: 缺少更新模式参数"
                    exit 1
                fi
                ;;
            *)
                echo "未知参数: $1"
                echo "用法: $0 [non_interactive_update <bin|docker>]"
                exit 1
                ;;
        esac
    fi
    
    # 交互式模式
    check_latest_version
    show_welcome
    check_system_requirements
    check_disk_space
    show_main_menu
}

# 执行主程序
main "$@"

