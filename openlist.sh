#!/bin/bash
###############################################################################
#
# OpenList Manager Script
#
# Version: 1.0.0
# Last Updated: 2025-06-15
#
# Description: 
#   A management script for OpenList (https://github.com/OpenListTeam/OpenList)
#   Provides installation, update, uninstallation and management functions
#
# Requirements:
#   - Linux with systemd
#   - Root privileges for installation
#   - curl, tar
#   - x86_64 or arm64 architecture
#
# Author: Modified for OpenList
# Repository: https://github.com/OpenListTeam/OpenList
# License: MIT
#
###############################################################################

# 在脚本开头添加错误处理函数
handle_error() {
    local exit_code=$1
    local error_msg=$2
    echo -e "${RED_COLOR}错误：${error_msg}${RES}"
    exit ${exit_code}
}

# 在关键操作处使用错误处理
if ! command -v curl >/dev/null 2>&1; then
    handle_error 1 "未找到 curl 命令，请先安装"
fi

# 配置部分
#######################
# GitHub 相关配置
GH_DOWNLOAD_URL="${GH_PROXY}https://github.com/OpenListTeam/OpenList/releases/latest/download"
#######################

# 颜色配置
RED_COLOR='\e[1;31m'
GREEN_COLOR='\e[1;32m'
YELLOW_COLOR='\e[1;33m'
RES='\e[0m'

# 添加一个函数来获取已安装的 OpenList 路径
GET_INSTALLED_PATH() {
    # 从 service 文件中获取工作目录
    if [ -f "/etc/systemd/system/openlist.service" ]; then
        installed_path=$(grep "WorkingDirectory=" /etc/systemd/system/openlist.service | cut -d'=' -f2)
        if [ -f "$installed_path/openlist" ]; then
            echo "$installed_path"
            return 0
        fi
    fi
    
    # 如果未找到或路径无效，返回默认路径
    echo "/opt/openlist"
}

# 设置安装路径
if [ ! -n "$2" ]; then
    INSTALL_PATH='/opt/openlist'
else
    INSTALL_PATH=${2%/}
    if ! [[ $INSTALL_PATH == */openlist ]]; then
        INSTALL_PATH="$INSTALL_PATH/openlist"
    fi
    
    # 创建父目录（如果不存在）
    parent_dir=$(dirname "$INSTALL_PATH")
    if [ ! -d "$parent_dir" ]; then
        mkdir -p "$parent_dir" || {
            echo -e "${RED_COLOR}错误：无法创建目录 $parent_dir${RES}"
            exit 1
        }
    fi
    
    # 在创建目录后再检查权限
    if ! [ -w "$parent_dir" ]; then
        echo -e "${RED_COLOR}错误：目录 $parent_dir 没有写入权限${RES}"
        exit 1
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
  # 检查目标目录是否存在，如果不存在则创建
  if [ ! -d "$(dirname "$INSTALL_PATH")" ]; then
    echo -e "${GREEN_COLOR}目录不存在，正在创建...${RES}"
    mkdir -p "$(dirname "$INSTALL_PATH")" || {
      echo -e "${RED_COLOR}错误：无法创建目录 $(dirname "$INSTALL_PATH")${RES}"
      exit 1
    }
  fi

  # 检查是否已安装
  if [ -f "$INSTALL_PATH/openlist" ]; then
    echo "此位置已经安装，请选择其他位置，或使用更新命令"
    exit 0
  fi

  # 创建或清空安装目录
  if [ ! -d "$INSTALL_PATH/" ]; then
    mkdir -p $INSTALL_PATH || {
      echo -e "${RED_COLOR}错误：无法创建安装目录 $INSTALL_PATH${RES}"
      exit 1
    }
  else
    rm -rf $INSTALL_PATH && mkdir -p $INSTALL_PATH
  fi

  echo -e "${GREEN_COLOR}安装目录准备就绪：$INSTALL_PATH${RES}"
}

# 添加全局变量存储账号密码
ADMIN_USER=""
ADMIN_PASS=""

# 添加下载函数，包含重试机制
download_file() {
    local url="$1"
    local output="$2"
    local max_retries=3
    local retry_count=0
    local wait_time=5

    while [ $retry_count -lt $max_retries ]; do
        if curl -L --connect-timeout 10 --retry 3 --retry-delay 3 "$url" -o "$output"; then
            if [ -f "$output" ] && [ -s "$output" ]; then  # 检查文件是否存在且不为空
                return 0
            fi
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            echo -e "${YELLOW_COLOR}下载失败，${wait_time} 秒后进行第 $((retry_count + 1)) 次重试...${RES}"
            sleep $wait_time
            wait_time=$((wait_time + 5))  # 每次重试增加等待时间
        else
            echo -e "${RED_COLOR}下载失败，已重试 $max_retries 次${RES}"
            return 1
        fi
    done
    return 1
}

INSTALL() {
  # 保存当前目录
  CURRENT_DIR=$(pwd)
  
    # 询问是否使用代理
    echo -e "${GREEN_COLOR}是否使用 GitHub 代理？（默认无代理）${RES}"
    echo -e "${GREEN_COLOR}代理地址必须为 https 开头，斜杠 / 结尾 ${RES}"
    echo -e "${GREEN_COLOR}例如：https://ghproxy.com/ ${RES}"
    read -p "请输入代理地址或直接按回车继续: " proxy_input

  # 如果用户输入了代理地址，则使用代理拼接下载链接
  if [ -n "$proxy_input" ]; then
    GH_PROXY="$proxy_input"
    GH_DOWNLOAD_URL="${GH_PROXY}https://github.com/OpenListTeam/OpenList/releases/latest/download"
    echo -e "${GREEN_COLOR}已使用代理地址: $GH_PROXY${RES}"
  else
    # 如果不需要代理，直接使用默认链接
    GH_DOWNLOAD_URL="https://github.com/OpenListTeam/OpenList/releases/latest/download"
    echo -e "${GREEN_COLOR}使用默认 GitHub 地址进行下载${RES}"
  fi

  # 下载 OpenList 程序
  echo -e "\r\n${GREEN_COLOR}下载 OpenList ...${RES}"
  
  # 使用拼接后的 GitHub 下载地址
  if ! download_file "${GH_DOWNLOAD_URL}/openlist-linux-$ARCH.tar.gz" "/tmp/openlist.tar.gz"; then
    echo -e "${RED_COLOR}下载失败！${RES}"
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
    
    # 创建data目录（如果不存在）
    mkdir -p $INSTALL_PATH/data
    
    # 获取初始账号密码（临时切换目录）
    cd $INSTALL_PATH
    # 首次运行会生成管理员密码，从日志中提取
    timeout 10 $INSTALL_PATH/openlist > /tmp/openlist_init.log 2>&1 &
    OPENLIST_PID=$!
    sleep 3
    kill $OPENLIST_PID 2>/dev/null
    
    # 从日志中提取密码信息
    if [ -f "/tmp/openlist_init.log" ]; then
        ADMIN_PASS=$(grep "initial password is:" /tmp/openlist_init.log | sed 's/.*initial password is: //')
        ADMIN_USER="admin"
        rm -f /tmp/openlist_init.log
    fi
    
    # 切回原目录
    cd "$CURRENT_DIR"
  else
    echo -e "${RED_COLOR}安装失败！${RES}"
    rm -rf $INSTALL_PATH
    mkdir -p $INSTALL_PATH
    exit 1
  fi

  # 清理临时文件
  rm -f /tmp/openlist*
}

INIT() {
  if [ ! -f "$INSTALL_PATH/openlist" ]; then
    echo -e "\r\n${RED_COLOR}出错了${RES}，当前系统未安装 OpenList\r\n"
    exit 1
  fi

  # 创建 systemd 服务文件
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

SUCCESS() {
  clear  # 只在开始时清屏一次
  print_line() {
    local text="$1"
    local width=51
    printf "│ %-${width}s │\n" "$text"
  }

  # 获取本地 IP
  LOCAL_IP=$(ip addr show | grep -w inet | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1 | head -n1)
  # 获取公网 IP
  PUBLIC_IP=$(curl -s4 ip.sb || curl -s4 ifconfig.me || echo "获取失败")
  
  echo -e "┌────────────────────────────────────────────────────┐"
  print_line "OpenList 安装成功！"
  print_line ""
  print_line "访问地址："
  print_line "  局域网：http://${LOCAL_IP}:5244/"
  print_line "  公网：  http://${PUBLIC_IP}:5244/"
  print_line "配置文件：$INSTALL_PATH/data/config.json"
  print_line ""
  if [ ! -z "$ADMIN_USER" ] && [ ! -z "$ADMIN_PASS" ]; then
    print_line "账号信息："
    print_line "默认账号：$ADMIN_USER"
    print_line "初始密码：$ADMIN_PASS"
  else
    print_line "初始密码请查看启动日志获取"
  fi
  echo -e "└────────────────────────────────────────────────────┘"
  
  # 安装命令行工具
  if ! INSTALL_CLI; then
    echo -e "${YELLOW_COLOR}警告：命令行工具安装失败，但不影响 OpenList 的使用${RES}"
  fi
  
  echo -e "\n${GREEN_COLOR}启动服务中...${RES}"
  systemctl restart openlist
  echo -e "管理: 在任意目录输入 ${GREEN_COLOR}openlist${RES} 打开管理菜单"
  
  echo -e "\n${YELLOW_COLOR}温馨提示：如果端口无法访问，请检查服务器安全组、防火墙和服务状态${RES}"
  echo
  exit 0  # 直接退出，不再返回菜单
}

UPDATE() {
    if [ ! -f "$INSTALL_PATH/openlist" ]; then
        echo -e "\r\n${RED_COLOR}错误：未在 $INSTALL_PATH 找到 OpenList${RES}\r\n"
        exit 1
    fi

    echo -e "${GREEN_COLOR}开始更新 OpenList ...${RES}"

    # 询问是否使用代理
    echo -e "${GREEN_COLOR}是否使用 GitHub 代理？（默认无代理）${RES}"
    echo -e "${GREEN_COLOR}代理地址必须为 https 开头，斜杠 / 结尾 ${RES}"
    echo -e "${GREEN_COLOR}例如：https://ghproxy.com/ ${RES}"
    read -p "请输入代理地址或直接按回车继续: " proxy_input

    # 如果用户输入了代理地址，则使用代理拼接下载链接
    if [ -n "$proxy_input" ]; then
        GH_PROXY="$proxy_input"
        GH_DOWNLOAD_URL="${GH_PROXY}https://github.com/OpenListTeam/OpenList/releases/latest/download"
        echo -e "${GREEN_COLOR}已使用代理地址: $GH_PROXY${RES}"
    else
        # 如果不需要代理，直接使用默认链接
        GH_DOWNLOAD_URL="https://github.com/OpenListTeam/OpenList/releases/latest/download"
        echo -e "${GREEN_COLOR}使用默认 GitHub 地址进行下载${RES}"
    fi

    # 停止 OpenList 服务
    echo -e "${GREEN_COLOR}停止 OpenList 进程${RES}\r\n"
    systemctl stop openlist

    # 备份二进制文件
    cp $INSTALL_PATH/openlist /tmp/openlist.bak

    # 下载新版本
    echo -e "${GREEN_COLOR}下载 OpenList ...${RES}"
    if ! download_file "${GH_DOWNLOAD_URL}/openlist-linux-$ARCH.tar.gz" "/tmp/openlist.tar.gz"; then
        echo -e "${RED_COLOR}下载失败，更新终止${RES}"
        echo -e "${GREEN_COLOR}正在恢复之前的版本...${RES}"
        mv /tmp/openlist.bak $INSTALL_PATH/openlist
        systemctl start openlist
        exit 1
    fi

    # 解压文件
    if ! tar zxf /tmp/openlist.tar.gz -C $INSTALL_PATH/; then
        echo -e "${RED_COLOR}解压失败，更新终止${RES}"
        echo -e "${GREEN_COLOR}正在恢复之前的版本...${RES}"
        mv /tmp/openlist.bak $INSTALL_PATH/openlist
        systemctl start openlist
        rm -f /tmp/openlist.tar.gz
        exit 1
    fi

    # 验证更新是否成功
    if [ -f $INSTALL_PATH/openlist ]; then
        echo -e "${GREEN_COLOR}下载成功，正在更新${RES}"
    else
        echo -e "${RED_COLOR}更新失败！${RES}"
        echo -e "${GREEN_COLOR}正在恢复之前的版本...${RES}"
        mv /tmp/openlist.bak $INSTALL_PATH/openlist
        systemctl start openlist
        rm -f /tmp/openlist.tar.gz
        exit 1
    fi

    # 清理临时文件
    rm -f /tmp/openlist.tar.gz /tmp/openlist.bak

    # 重启 OpenList 服务
    echo -e "${GREEN_COLOR}启动 OpenList 进程${RES}\r\n"
    systemctl restart openlist

    echo -e "${GREEN_COLOR}更新完成！${RES}"
}

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
            
            echo -e "${GREEN_COLOR}停止 OpenList 进程${RES}"
            systemctl stop openlist
            systemctl disable openlist
            
            echo -e "${GREEN_COLOR}删除 OpenList 文件${RES}"
            rm -rf $INSTALL_PATH
            rm -f /etc/systemd/system/openlist.service
            systemctl daemon-reload
            
            # 删除管理脚本和命令链接
            if [ -f "$MANAGER_PATH" ] || [ -L "$COMMAND_LINK" ]; then
                echo -e "${GREEN_COLOR}删除命令行工具${RES}"
                rm -f "$MANAGER_PATH" "$COMMAND_LINK" || {
                    echo -e "${YELLOW_COLOR}警告：删除命令行工具失败，请手动删除：${RES}"
                    echo -e "${YELLOW_COLOR}1. $MANAGER_PATH${RES}"
                    echo -e "${YELLOW_COLOR}2. $COMMAND_LINK${RES}"
                }
            fi
            
            echo -e "${GREEN_COLOR}OpenList 已完全卸载${RES}"
            ;;
        *)
            echo -e "${GREEN_COLOR}已取消卸载${RES}"
            ;;
    esac
}

RESET_PASSWORD() {
    if [ ! -f "$INSTALL_PATH/openlist" ]; then
        echo -e "\r\n${RED_COLOR}错误：系统未安装 OpenList，请先安装！${RES}\r\n"
        exit 1
    fi

    echo -e "\n${RED_COLOR}注意：OpenList 的密码存储在数据库中，${RES}"
    echo -e "${RED_COLOR}重置密码需要删除数据库文件重新初始化${RES}"
    echo -e "${YELLOW_COLOR}这将会丢失所有配置和数据！${RES}"
    echo
    read -p "是否确认重置密码？[y/N]: " choice

    case "${choice}" in
        [yY])
            echo -e "${GREEN_COLOR}正在重置密码...${RES}"
            
            # 停止服务
            systemctl stop openlist
            
            # 备份数据库
            if [ -f "$INSTALL_PATH/data/data.db" ]; then
                cp "$INSTALL_PATH/data/data.db" "$INSTALL_PATH/data/data.db.backup.$(date +%Y%m%d_%H%M%S)"
                echo -e "${GREEN_COLOR}数据库已备份${RES}"
            fi
            
            # 删除数据库文件
            rm -f "$INSTALL_PATH/data/data.db"*
            
            # 启动服务
            systemctl start openlist
            
            # 等待服务启动并获取新密码
            echo -e "${GREEN_COLOR}正在获取新密码...${RES}"
            sleep 5
            
            # 从日志中获取密码
            NEW_PASS=$(journalctl -u openlist --since "1 minute ago" | grep "initial password is:" | tail -1 | sed 's/.*initial password is: //')
            
            if [ ! -z "$NEW_PASS" ]; then
                echo -e "\n${GREEN_COLOR}账号信息：${RES}"
                echo -e "账号: admin"
                echo -e "密码: $NEW_PASS"
            else
                echo -e "${YELLOW_COLOR}无法自动获取密码，请查看服务日志：${RES}"
                echo -e "journalctl -u openlist -f"
            fi
            ;;
        *)
            echo -e "${GREEN_COLOR}已取消重置${RES}"
            ;;
    esac
}

# 在文件开头添加管理脚本路径配置
MANAGER_PATH="/usr/local/sbin/openlist-manager"  # 管理脚本存放路径
COMMAND_LINK="/usr/local/bin/openlist"          # 命令软链接路径

# 修改 INSTALL_CLI() 函数
INSTALL_CLI() {
    # 检查是否有 root 权限
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED_COLOR}错误：安装命令行工具需要 root 权限${RES}"
        return 1
    fi

    # 获取当前脚本信息（不显示调试信息）
    SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
    SCRIPT_NAME=$(basename "$0")
    SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_NAME"

    # 验证脚本文件是否存在
    if [ ! -f "$SCRIPT_PATH" ]; then
        echo -e "${RED_COLOR}错误：找不到源脚本文件${RES}"
        echo -e "路径: $SCRIPT_PATH"
        return 1
    fi
    
    # 创建管理脚本目录
    mkdir -p "$(dirname "$MANAGER_PATH")" || {
        echo -e "${RED_COLOR}错误：无法创建目录 $(dirname "$MANAGER_PATH")${RES}"
        return 1
    }
    
    # 复制脚本到管理目录
    cp "$SCRIPT_PATH" "$MANAGER_PATH" || {
        echo -e "${RED_COLOR}错误：无法复制管理脚本${RES}"
        echo -e "源文件：$SCRIPT_PATH"
        echo -e "目标文件：$MANAGER_PATH"
        return 1
    }
    
    # 设置权限
    chmod 755 "$MANAGER_PATH" || {
        echo -e "${RED_COLOR}错误：设置权限失败${RES}"
        rm -f "$MANAGER_PATH"
        return 1
    }
    
    # 确保目录权限正确
    chmod 755 "$(dirname "$MANAGER_PATH")" || {
        echo -e "${YELLOW_COLOR}警告：设置目录权限失败${RES}"
    }
    
    # 创建命令软链接目录
    mkdir -p "$(dirname "$COMMAND_LINK")" || {
        echo -e "${RED_COLOR}错误：无法创建目录 $(dirname "$COMMAND_LINK")${RES}"
        rm -f "$MANAGER_PATH"
        return 1
    }
    
    # 创建命令软链接
    ln -sf "$MANAGER_PATH" "$COMMAND_LINK" || {
        echo -e "${RED_COLOR}错误：创建命令链接失败${RES}"
        rm -f "$MANAGER_PATH"
        return 1
    }
    
    echo -e "${GREEN_COLOR}命令行工具安装成功！${RES}"
    echo -e "\n现在你可以使用以下命令："
    echo -e "1. ${GREEN_COLOR}openlist${RES}          - 快捷命令"
    echo -e "2. ${GREEN_COLOR}openlist-manager${RES}  - 完整命令"
    return 0
}

SHOW_MENU() {
  # 获取实际安装路径
  INSTALL_PATH=$(GET_INSTALLED_PATH)

  echo -e "\n欢迎使用 OpenList 管理脚本\n"
  echo -e "${GREEN_COLOR}1、安装 OpenList${RES}"
  echo -e "${GREEN_COLOR}2、更新 OpenList${RES}"
  echo -e "${GREEN_COLOR}3、卸载 OpenList${RES}"
  echo -e "${GREEN_COLOR}-------------------${RES}"
  echo -e "${GREEN_COLOR}4、查看状态${RES}"
  echo -e "${GREEN_COLOR}5、重置密码${RES}"
  echo -e "${GREEN_COLOR}-------------------${RES}"
  echo -e "${GREEN_COLOR}6、启动 OpenList${RES}"
  echo -e "${GREEN_COLOR}7、停止 OpenList${RES}"
  echo -e "${GREEN_COLOR}8、重启 OpenList${RES}"
  echo -e "${GREEN_COLOR}-------------------${RES}"
  echo -e "${GREEN_COLOR}9、查看日志${RES}"
  echo -e "${GREEN_COLOR}-------------------${RES}"
  echo -e "${GREEN_COLOR}0、退出脚本${RES}"
  echo
  read -p "请输入选项 [0-9]: " choice
  
  case "$choice" in
    1)
      # 安装时重置为默认路径
      INSTALL_PATH='/opt/openlist'
      CHECK
      INSTALL
      INIT
      SUCCESS
      return 0
      ;;
    2)
      UPDATE
      exit 0
      ;;
    3)
      UNINSTALL
      exit 0
      ;;
    4)
      if [ ! -f "$INSTALL_PATH/openlist" ]; then
        echo -e "\r\n${RED_COLOR}错误：系统未安装 OpenList，请先安装！${RES}\r\n"
        return 1
      fi
      # 检查服务状态
      if systemctl is-active openlist >/dev/null 2>&1; then
        echo -e "${GREEN_COLOR}OpenList 当前状态为：运行中${RES}"
        echo -e "访问地址：http://$(ip addr show | grep -w inet | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1 | head -n1):5244/"
      else
        echo -e "${RED_COLOR}OpenList 当前状态为：停止${RES}"
      fi
      return 0
      ;;
    5)
      RESET_PASSWORD
      return 0
      ;;
    6)
      if [ ! -f "$INSTALL_PATH/openlist" ]; then
        echo -e "\r\n${RED_COLOR}错误：系统未安装 OpenList，请先安装！${RES}\r\n"
        return 1
      fi
      systemctl start openlist
      echo -e "${GREEN_COLOR}OpenList 已启动${RES}"
      return 0
      ;;
    7)
      if [ ! -f "$INSTALL_PATH/openlist" ]; then
        echo -e "\r\n${RED_COLOR}错误：系统未安装 OpenList，请先安装！${RES}\r\n"
        return 1
      fi
      systemctl stop openlist
      echo -e "${GREEN_COLOR}OpenList 已停止${RES}"
      return 0
      ;;
    8)
      if [ ! -f "$INSTALL_PATH/openlist" ]; then
        echo -e "\r\n${RED_COLOR}错误：系统未安装 OpenList，请先安装！${RES}\r\n"
        return 1
      fi
      systemctl restart openlist
      echo -e "${GREEN_COLOR}OpenList 已重启${RES}"
      return 0
      ;;
    9)
      if [ ! -f "$INSTALL_PATH/openlist" ]; then
        echo -e "\r\n${RED_COLOR}错误：系统未安装 OpenList，请先安装！${RES}\r\n"
        return 1
      fi
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

# 修改主程序逻辑
if [ $# -eq 0 ]; then
  while true; do
    SHOW_MENU
    echo
    # 等待一会儿让用户看到执行结果
    if [ $? -eq 0 ]; then
      sleep 3  # 成功时等待3秒
    else
      sleep 5  # 失败时等待5秒
    fi
    clear  # 然后再清屏显示菜单
  done
elif [ "$1" = "install" ]; then
  CHECK
  INSTALL
  INIT
  SUCCESS
elif [ "$1" = "update" ]; then
  if [ $# -gt 1 ]; then
    echo -e "${RED_COLOR}错误：update 命令不需要指定路径${RES}"
    echo -e "正确用法: $0 update"
    exit 1
  fi
  UPDATE
elif [ "$1" = "uninstall" ]; then
  if [ $# -gt 1 ]; then
    echo -e "${RED_COLOR}错误：uninstall 命令不需要指定路径${RES}"
    echo -e "正确用法: $0 uninstall"
    exit 1
  fi
  UNINSTALL
else
  echo -e "${RED_COLOR}错误的命令${RES}"
  echo -e "用法: $0 install [安装路径]    # 安装 OpenList"
  echo -e "     $0 update              # 更新 OpenList"
  echo -e "     $0 uninstall          # 卸载 OpenList"
  echo -e "     $0                    # 显示交互菜单"
fi
