#!/bin/bash
###############################################################################
#
# OpenList Manager Script (Beta Version)
#
# Version: 1.1.0
# Last Updated: 2025-06-15
#
# Description: 
#   A management script for OpenList Beta (https://github.com/OpenListTeam/OpenList)
#   Provides installation, update, uninstallation and management functions
#   Supports beta version and auto-update functionality
#
# Requirements:
#   - Linux with systemd
#   - Root privileges for installation
#   - curl, tar, jq (optional for JSON parsing)
#   - x86_64 or arm64 architecture
#
# Author: Modified for OpenList Beta
# Repository: https://github.com/OpenListTeam/OpenList
# License: MIT
#
###############################################################################

# 错误处理函数
handle_error() {
    local exit_code=$1
    local error_msg=$2
    echo -e "${RED_COLOR}错误：${error_msg}${RES}"
    exit ${exit_code}
}

# 检查必要命令
if ! command -v curl >/dev/null 2>&1; then
    handle_error 1 "未找到 curl 命令，请先安装"
fi

# 配置部分
#######################
# GitHub 相关配置
GITHUB_REPO="OpenListTeam/OpenList"
VERSION_TAG="beta"  # 默认使用beta版本
GH_DOWNLOAD_URL="${GH_PROXY}https://github.com/${GITHUB_REPO}/releases/download/${VERSION_TAG}"
#######################

# 颜色配置
RED_COLOR='\e[1;31m'
GREEN_COLOR='\e[1;32m'
YELLOW_COLOR='\e[1;33m'
BLUE_COLOR='\e[1;34m'
RES='\e[0m'

# 版本信息文件
VERSION_FILE="/opt/openlist/.version"

# 获取已安装的 OpenList 路径
GET_INSTALLED_PATH() {
    if [ -f "/etc/systemd/system/openlist.service" ]; then
        installed_path=$(grep "WorkingDirectory=" /etc/systemd/system/openlist.service | cut -d'=' -f2)
        if [ -f "$installed_path/openlist" ]; then
            echo "$installed_path"
            return 0
        fi
    fi
    echo "/opt/openlist"
}

# 获取可用版本列表
GET_AVAILABLE_VERSIONS() {
    echo -e "${BLUE_COLOR}正在获取可用版本...${RES}"
    
    # 尝试获取所有releases
    if command -v jq >/dev/null 2>&1; then
        # 如果有jq，使用JSON解析
        VERSIONS=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases" | jq -r '.[].tag_name' 2>/dev/null)
    else
        # 没有jq，使用grep和sed
        VERSIONS=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
    fi
    
    if [ ! -z "$VERSIONS" ]; then
        echo -e "${GREEN_COLOR}可用版本：${RES}"
        echo "$VERSIONS" | head -10  # 显示前10个版本
        return 0
    else
        echo -e "${YELLOW_COLOR}无法获取版本信息，使用默认beta版本${RES}"
        return 1
    fi
}

# 检查是否有新版本
CHECK_UPDATE() {
    if [ ! -f "$VERSION_FILE" ]; then
        echo -e "${YELLOW_COLOR}未找到版本信息文件，无法检查更新${RES}"
        return 1
    fi
    
    CURRENT_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "unknown")
    echo -e "${BLUE_COLOR}当前版本：$CURRENT_VERSION${RES}"
    
    # 获取最新版本信息
    if [ "$VERSION_TAG" = "beta" ]; then
        echo -e "${BLUE_COLOR}检查beta版本更新...${RES}"
        # 对于beta版本，我们检查最后更新时间
        REMOTE_DATE=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases/tags/beta" | grep '"updated_at"' | cut -d'"' -f4)
        LOCAL_DATE=$(stat -c %Y "$INSTALL_PATH/openlist" 2>/dev/null || echo "0")
        
        if [ ! -z "$REMOTE_DATE" ]; then
            REMOTE_TIMESTAMP=$(date -d "$REMOTE_DATE" +%s 2>/dev/null || echo "0")
            if [ "$REMOTE_TIMESTAMP" -gt "$LOCAL_DATE" ]; then
                echo -e "${GREEN_COLOR}发现新的beta版本更新！${RES}"
                return 0
            else
                echo -e "${GREEN_COLOR}当前已是最新beta版本${RES}"
                return 1
            fi
        fi
    fi
    
    return 1
}

# 设置安装路径
if [ ! -n "$2" ]; then
    INSTALL_PATH='/opt/openlist'
else
    INSTALL_PATH=${2%/}
    if ! [[ $INSTALL_PATH == */openlist ]]; then
        INSTALL_PATH="$INSTALL_PATH/openlist"
    fi
    
    parent_dir=$(dirname "$INSTALL_PATH")
    if [ ! -d "$parent_dir" ]; then
        mkdir -p "$parent_dir" || handle_error 1 "无法创建目录 $parent_dir"
    fi
    
    if ! [ -w "$parent_dir" ]; then
        handle_error 1 "目录 $parent_dir 没有写入权限"
    fi
fi

# 如果是更新或卸载操作，使用已安装的路径
if [ "$1" = "update" ] || [ "$1" = "uninstall" ]; then
    INSTALL_PATH=$(GET_INSTALLED_PATH)
fi

clear

# 获取平台架构
if command -v arch >/dev/null 2>&1; then
  platform=$(arch)
else
  platform=$(uname -m)
fi

ARCH="UNKNOWN"
if [ "$platform" = "x86_64" ]; then
  ARCH=amd64
elif [ "$platform" = "aarch64" ]; then
  ARCH=arm64
fi

# 权限和环境检查
if [ "$(id -u)" != "0" ]; then
  if [ "$1" = "install" ] || [ "$1" = "update" ] || [ "$1" = "uninstall" ]; then
    echo -e "\r\n${RED_COLOR}错误：请使用 root 权限运行此命令！${RES}\r\n"
    echo -e "提示：使用 ${GREEN_COLOR}sudo $0 $1${RES} 重试\r\n"
    exit 1
  fi
elif [ "$ARCH" == "UNKNOWN" ]; then
  echo -e "\r\n${RED_COLOR}出错了${RES}，一键安装目前仅支持 x86_64 和 arm64 平台。\r\n"
  exit 1
elif ! command -v systemctl >/dev/null 2>&1; then
  echo -e "\r\n${RED_COLOR}出错了${RES}，无法确定你当前的 Linux 发行版。\r\n建议手动安装。\r\n"
  exit 1
fi

CHECK() {
  if [ ! -d "$(dirname "$INSTALL_PATH")" ]; then
    echo -e "${GREEN_COLOR}目录不存在，正在创建...${RES}"
    mkdir -p "$(dirname "$INSTALL_PATH")" || handle_error 1 "无法创建目录 $(dirname "$INSTALL_PATH")"
  fi

  if [ -f "$INSTALL_PATH/openlist" ]; then
    echo "此位置已经安装，请选择其他位置，或使用更新命令"
    exit 0
  fi

  if [ ! -d "$INSTALL_PATH/" ]; then
    mkdir -p $INSTALL_PATH || handle_error 1 "无法创建安装目录 $INSTALL_PATH"
  else
    rm -rf $INSTALL_PATH && mkdir -p $INSTALL_PATH
  fi

  echo -e "${GREEN_COLOR}安装目录准备就绪：$INSTALL_PATH${RES}"
}

# 选择版本函数
SELECT_VERSION() {
    echo -e "${BLUE_COLOR}请选择要安装的版本：${RES}"
    echo -e "${GREEN_COLOR}1、beta (推荐 - 最新功能)${RES}"
    echo -e "${GREEN_COLOR}2、查看所有可用版本${RES}"
    echo -e "${GREEN_COLOR}3、手动输入版本标签${RES}"
    echo
    read -p "请输入选项 [1-3]: " version_choice
    
    case "$version_choice" in
        1)
            VERSION_TAG="beta"
            echo -e "${GREEN_COLOR}已选择beta版本${RES}"
            ;;
        2)
            if GET_AVAILABLE_VERSIONS; then
                echo
                read -p "请输入要使用的版本标签: " custom_version
                if [ ! -z "$custom_version" ]; then
                    VERSION_TAG="$custom_version"
                    echo -e "${GREEN_COLOR}已选择版本：$VERSION_TAG${RES}"
                else
                    VERSION_TAG="beta"
                    echo -e "${YELLOW_COLOR}输入为空，使用beta版本${RES}"
                fi
            else
                VERSION_TAG="beta"
                echo -e "${YELLOW_COLOR}获取版本失败，使用beta版本${RES}"
            fi
            ;;
        3)
            read -p "请输入版本标签 (如: beta, v1.0.0): " custom_version
            if [ ! -z "$custom_version" ]; then
                VERSION_TAG="$custom_version"
                echo -e "${GREEN_COLOR}已选择版本：$VERSION_TAG${RES}"
            else
                VERSION_TAG="beta"
                echo -e "${YELLOW_COLOR}输入为空，使用beta版本${RES}"
            fi
            ;;
        *)
            VERSION_TAG="beta"
            echo -e "${YELLOW_COLOR}无效选项，使用beta版本${RES}"
            ;;
    esac
    
    # 更新下载URL
    GH_DOWNLOAD_URL="${GH_PROXY}https://github.com/${GITHUB_REPO}/releases/download/${VERSION_TAG}"
}

# 添加全局变量存储账号密码
ADMIN_USER=""
ADMIN_PASS=""

# 下载函数，包含重试机制
download_file() {
    local url="$1"
    local output="$2"
    local max_retries=3
    local retry_count=0
    local wait_time=5

    while [ $retry_count -lt $max_retries ]; do
        echo -e "${BLUE_COLOR}尝试下载: $url${RES}"
        if curl -L --connect-timeout 10 --retry 3 --retry-delay 3 "$url" -o "$output"; then
            if [ -f "$output" ] && [ -s "$output" ]; then
                # 检查文件是否为"Not Found"
                if ! grep -q "Not Found" "$output" 2>/dev/null; then
                    return 0
                else
                    echo -e "${RED_COLOR}文件不存在: $url${RES}"
                    rm -f "$output"
                    return 1
                fi
            fi
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            echo -e "${YELLOW_COLOR}下载失败，${wait_time} 秒后进行第 $((retry_count + 1)) 次重试...${RES}"
            sleep $wait_time
            wait_time=$((wait_time + 5))
        else
            echo -e "${RED_COLOR}下载失败，已重试 $max_retries 次${RES}"
            return 1
        fi
    done
    return 1
}

INSTALL() {
  CURRENT_DIR=$(pwd)
  
  # 选择版本
  SELECT_VERSION
  
  # 询问是否使用代理
  echo -e "${GREEN_COLOR}是否使用 GitHub 代理？（默认无代理）${RES}"
  echo -e "${GREEN_COLOR}代理地址必须为 https 开头，斜杠 / 结尾 ${RES}"
  echo -e "${GREEN_COLOR}例如：https://ghproxy.com/ ${RES}"
  read -p "请输入代理地址或直接按回车继续: " proxy_input

  if [ -n "$proxy_input" ]; then
    GH_PROXY="$proxy_input"
    GH_DOWNLOAD_URL="${GH_PROXY}https://github.com/${GITHUB_REPO}/releases/download/${VERSION_TAG}"
    echo -e "${GREEN_COLOR}已使用代理地址: $GH_PROXY${RES}"
  else
    GH_DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/${VERSION_TAG}"
    echo -e "${GREEN_COLOR}使用默认 GitHub 地址进行下载${RES}"
  fi

  echo -e "\r\n${GREEN_COLOR}下载 OpenList ${VERSION_TAG} ...${RES}"
  
  # 使用确认的GitHub下载地址
  if ! download_file "${GH_DOWNLOAD_URL}/openlist-linux-$ARCH.tar.gz" "/tmp/openlist.tar.gz"; then
    echo -e "${RED_COLOR}下载失败！${RES}"
    echo -e "${YELLOW_COLOR}请检查版本标签是否正确：$VERSION_TAG${RES}"
    exit 1
  fi

  # 验证下载的文件
  echo -e "${BLUE_COLOR}验证下载文件...${RES}"
  if ! tar -tf /tmp/openlist.tar.gz >/dev/null 2>&1; then
    echo -e "${RED_COLOR}下载的文件不是有效的tar.gz格式！${RES}"
    rm -f /tmp/openlist.tar.gz
    exit 1
  fi

  # 解压文件
  if ! tar zxf /tmp/openlist.tar.gz -C $INSTALL_PATH/; then
    echo -e "${RED_COLOR}解压失败！${RES}"
    rm -f /tmp/openlist.tar.gz
    exit 1
  fi

  if [ -f $INSTALL_PATH/openlist ]; then
    echo -e "${GREEN_COLOR}下载成功，正在安装...${RES}"
    
    # 创建data目录
    mkdir -p $INSTALL_PATH/data
    
    # 记录版本信息
    echo "$VERSION_TAG" > "$VERSION_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S')" >> "$VERSION_FILE"
    
    # 获取初始账号密码
    cd $INSTALL_PATH
    timeout 10 $INSTALL_PATH/openlist > /tmp/openlist_init.log 2>&1 &
    OPENLIST_PID=$!
    sleep 3
    kill $OPENLIST_PID 2>/dev/null
    
    if [ -f "/tmp/openlist_init.log" ]; then
        ADMIN_PASS=$(grep "initial password is:" /tmp/openlist_init.log | sed 's/.*initial password is: //')
        ADMIN_USER="admin"
        rm -f /tmp/openlist_init.log
    fi
    
    cd "$CURRENT_DIR"
  else
    echo -e "${RED_COLOR}安装失败！${RES}"
    rm -rf $INSTALL_PATH
    mkdir -p $INSTALL_PATH
    exit 1
  fi

  rm -f /tmp/openlist*
}

INIT() {
  if [ ! -f "$INSTALL_PATH/openlist" ]; then
    echo -e "\r\n${RED_COLOR}出错了${RES}，当前系统未安装 OpenList\r\n"
    exit 1
  fi

  cat >/etc/systemd/system/openlist.service <<EOF
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
  systemctl enable openlist >/dev/null 2>&1
}

AUTO_UPDATE() {
    echo -e "${BLUE_COLOR}检查更新...${RES}"
    
    if CHECK_UPDATE; then
        echo -e "${GREEN_COLOR}发现新版本，是否立即更新？[Y/n]: ${RES}"
        read -p "" auto_update_choice
        
        case "${auto_update_choice:-y}" in
            [yY]|"")
                echo -e "${GREEN_COLOR}开始自动更新...${RES}"
                # 获取当前版本
                CURRENT_VERSION_TAG=$(head -n1 "$VERSION_FILE" 2>/dev/null || echo "beta")
                VERSION_TAG="$CURRENT_VERSION_TAG"
                UPDATE
                ;;
            *)
                echo -e "${YELLOW_COLOR}跳过更新${RES}"
                ;;
        esac
    else
        echo -e "${GREEN_COLOR}当前已是最新版本${RES}"
    fi
}

UPDATE() {
    if [ ! -f "$INSTALL_PATH/openlist" ]; then
        echo -e "\r\n${RED_COLOR}错误：未在 $INSTALL_PATH 找到 OpenList${RES}\r\n"
        exit 1
    fi

    # 如果没有指定版本，使用已安装的版本
    if [ -f "$VERSION_FILE" ]; then
        VERSION_TAG=$(head -n1 "$VERSION_FILE" 2>/dev/null || echo "beta")
    else
        VERSION_TAG="beta"
    fi

    echo -e "${GREEN_COLOR}开始更新 OpenList ($VERSION_TAG) ...${RES}"

    # 询问是否使用代理
    echo -e "${GREEN_COLOR}是否使用 GitHub 代理？（默认无代理）${RES}"
    read -p "请输入代理地址或直接按回车继续: " proxy_input

    if [ -n "$proxy_input" ]; then
        GH_PROXY="$proxy_input"
        GH_DOWNLOAD_URL="${GH_PROXY}https://github.com/${GITHUB_REPO}/releases/download/${VERSION_TAG}"
    else
        GH_DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/${VERSION_TAG}"
    fi

    systemctl stop openlist
    cp $INSTALL_PATH/openlist /tmp/openlist.bak

    if ! download_file "${GH_DOWNLOAD_URL}/openlist-linux-$ARCH.tar.gz" "/tmp/openlist.tar.gz"; then
        echo -e "${RED_COLOR}下载失败，更新终止${RES}"
        mv /tmp/openlist.bak $INSTALL_PATH/openlist
        systemctl start openlist
        exit 1
    fi

    if ! tar zxf /tmp/openlist.tar.gz -C $INSTALL_PATH/; then
        echo -e "${RED_COLOR}解压失败，更新终止${RES}"
        mv /tmp/openlist.bak $INSTALL_PATH/openlist
        systemctl start openlist
        rm -f /tmp/openlist.tar.gz
        exit 1
    fi

    if [ -f $INSTALL_PATH/openlist ]; then
        echo -e "${GREEN_COLOR}更新成功${RES}"
        # 更新版本信息
        echo "$VERSION_TAG" > "$VERSION_FILE"
        echo "$(date '+%Y-%m-%d %H:%M:%S')" >> "$VERSION_FILE"
    else
        echo -e "${RED_COLOR}更新失败！${RES}"
        mv /tmp/openlist.bak $INSTALL_PATH/openlist
        systemctl start openlist
        rm -f /tmp/openlist.tar.gz
        exit 1
    fi

    rm -f /tmp/openlist.tar.gz /tmp/openlist.bak
    systemctl restart openlist
    echo -e "${GREEN_COLOR}OpenList 更新完成！${RES}"
}

# 继续其他函数...
UNINSTALL() {
    if [ ! -f "$INSTALL_PATH/openlist" ]; then
        echo -e "\r\n${RED_COLOR}错误：未在 $INSTALL_PATH 找到 OpenList${RES}\r\n"
        exit 1
    fi
    
    echo -e "${RED_COLOR}警告：卸载后将删除本地 OpenList 目录、数据库文件及命令行工具！${RES}"
    read -p "是否确认卸载？[Y/n]: " choice
    
    case "${choice:-y}" in
        [yY]|"")
            echo -e "${GREEN_COLOR}开始卸载...${RES}"
            systemctl stop openlist
            systemctl disable openlist
            rm -rf $INSTALL_PATH
            rm -f /etc/systemd/system/openlist.service
            rm -f "$VERSION_FILE"
            systemctl daemon-reload
            echo -e "${GREEN_COLOR}OpenList 已完全卸载${RES}"
            ;;
        *)
            echo -e "${GREEN_COLOR}已取消卸载${RES}"
            ;;
    esac
}

SHOW_VERSION() {
    if [ -f "$VERSION_FILE" ]; then
        VERSION_INFO=$(cat "$VERSION_FILE")
        echo -e "${GREEN_COLOR}版本信息：${RES}"
        echo "$VERSION_INFO"
    else
        echo -e "${YELLOW_COLOR}未找到版本信息${RES}"
    fi
    
    if [ -f "$INSTALL_PATH/openlist" ]; then
        echo -e "${GREEN_COLOR}二进制文件：${RES}"
        ls -la "$INSTALL_PATH/openlist"
    fi
}

SHOW_MENU() {
  INSTALL_PATH=$(GET_INSTALLED_PATH)

  echo -e "\n${BLUE_COLOR}欢迎使用 OpenList 管理脚本 (Beta版本支持)${RES}\n"
  echo -e "${GREEN_COLOR}1、安装 OpenList${RES}"
  echo -e "${GREEN_COLOR}2、更新 OpenList${RES}"
  echo -e "${GREEN_COLOR}3、卸载 OpenList${RES}"
  echo -e "${GREEN_COLOR}-------------------${RES}"
  echo -e "${GREEN_COLOR}4、查看状态${RES}"
  echo -e "${GREEN_COLOR}5、查看版本${RES}"
  echo -e "${GREEN_COLOR}6、检查更新${RES}"
  echo -e "${GREEN_COLOR}-------------------${RES}"
  echo -e "${GREEN_COLOR}7、启动 OpenList${RES}"
  echo -e "${GREEN_COLOR}8、停止 OpenList${RES}"
  echo -e "${GREEN_COLOR}9、重启 OpenList${RES}"
  echo -e "${GREEN_COLOR}-------------------${RES}"
  echo -e "${GREEN_COLOR}10、查看日志${RES}"
  echo -e "${GREEN_COLOR}-------------------${RES}"
  echo -e "${GREEN_COLOR}0、退出脚本${RES}"
  echo
  read -p "请输入选项 [0-10]: " choice
  
  case "$choice" in
    1)
      INSTALL_PATH='/opt/openlist'
      CHECK
      INSTALL
      INIT
      echo -e "${GREEN_COLOR}OpenList 安装完成！${RES}"
      systemctl start openlist
      return 0
      ;;
    2)
      UPDATE
      return 0
      ;;
    3)
      UNINSTALL
      return 0
      ;;
    4)
      if [ ! -f "$INSTALL_PATH/openlist" ]; then
        echo -e "\r\n${RED_COLOR}错误：系统未安装 OpenList，请先安装！${RES}\r\n"
        return 1
      fi
      if systemctl is-active openlist >/dev/null 2>&1; then
        echo -e "${GREEN_COLOR}OpenList 当前状态为：运行中${RES}"
        LOCAL_IP=$(ip addr show | grep -w inet | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1 | head -n1)
        echo -e "访问地址：http://${LOCAL_IP}:5244/"
      else
        echo -e "${RED_COLOR}OpenList 当前状态为：停止${RES}"
      fi
      return 0
      ;;
    5)
      SHOW_VERSION
      return 0
      ;;
    6)
      AUTO_UPDATE
      return 0
      ;;
    7)
      if [ ! -f "$INSTALL_PATH/openlist" ]; then
        echo -e "\r\n${RED_COLOR}错误：系统未安装 OpenList，请先安装！${RES}\r\n"
        return 1
      fi
      systemctl start openlist
      echo -e "${GREEN_COLOR}OpenList 已启动${RES}"
      return 0
      ;;
    8)
      systemctl stop openlist
      echo -e "${GREEN_COLOR}OpenList 已停止${RES}"
      return 0
      ;;
    9)
      systemctl restart openlist
      echo -e "${GREEN_COLOR}OpenList 已重启${RES}"
      return 0
      ;;
    10)
      echo -e "${GREEN_COLOR}查看 OpenList 日志（按 Ctrl+C 退出）:${RES}"
      journalctl -u openlist -f
      return 0
      ;;
    0)
      exit 0
      ;;
    *)
      echo -e "${RED_COLOR}无效的选项${RES}"
      return 1
      ;;
  esac
}

# 主程序逻辑
if [ $# -eq 0 ]; then
  while true; do
    SHOW_MENU
    echo
    if [ $? -eq 0 ]; then
      sleep 3
    else
      sleep 5
    fi
    clear
  done
elif [ "$1" = "install" ]; then
  CHECK
  INSTALL
  INIT
  echo -e "${GREEN_COLOR}OpenList 安装完成！${RES}"
  systemctl start openlist
elif [ "$1" = "update" ]; then
  UPDATE
elif [ "$1" = "uninstall" ]; then
  UNINSTALL
elif [ "$1" = "check-update" ]; then
  AUTO_UPDATE
else
  echo -e "${RED_COLOR}错误的命令${RES}"
  echo -e "用法: $0 install [安装路径]    # 安装 OpenList"
  echo -e "     $0 update              # 更新 OpenList"
  echo -e "     $0 uninstall          # 卸载 OpenList"
  echo -e "     $0 check-update       # 检查更新"
  echo -e "     $0                    # 显示交互菜单"
fi
