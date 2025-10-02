#!/bin/bash
# 调试日志函数，自动输出到 /tmp/openlist_update_debug.log 并同步到控制台
log_debug() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a /tmp/openlist_update_debug.log
}
###############################################################################
#
# OpenList Interactive Manager Script
#
# Version: 1.8.3
# Last Updated: 2025-10-02
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
###############################################################################

# 配置部分
GITHUB_REPO="OpenListTeam/OpenList"
VERSION_TAG="beta"
VERSION_FILE="/opt/openlist/.version"
MANAGER_VERSION="1.8.3"  # 每次更新脚本都要更新管理器版本号

# --- 代码省略，保持一致 ---

# 新增：设置管理员密码的函数
set_admin_password() {
    echo -e "${BLUE_COLOR}设置管理员密码${RES}"
    echo -e "您可以选择以下操作："
    echo -e "${GREEN_COLOR}1${RES} - 手动输入新密码"
    echo -e "${GREEN_COLOR}2${RES} - 随机生成密码"
    echo -e "${GREEN_COLOR}3${RES} - 返回主菜单"
    echo

    while true; do
        read -r -p "请选择操作 [1-3]: " sub_choice
        case "$sub_choice" in
            1)
                read -r -p "请输入新密码: " new_password
                if [ -n "$new_password" ]; then
                    /opt/openlist/openlist admin set "$new_password"
                    echo -e "${GREEN_COLOR}密码设置成功！${RES}"
                else
                    echo -e "${RED_COLOR}密码不能为空，请重试。${RES}"
                fi
                ;;
            2)
                new_password=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
                /opt/openlist/openlist admin set "$new_password"
                echo -e "${GREEN_COLOR}随机密码设置成功！ 新密码：$new_password ${RES}"
                ;;
            3) return ;;
            *) echo -e "${RED_COLOR}无效选项，请重新选择${RES}" ;;
        esac
    done
}

# --- 更新 show_main_menu，插入设置管理员密码选项 ---
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
        echo -e "${YELLOW_COLOR}* 提示：输入 'openlist' 可再次唤出脚本${RES}"
        echo
        echo -e "${GREEN_COLOR}1${RES} - 安装 OpenList"
        echo -e "${GREEN_COLOR}2${RES} - 更新 OpenList"
        echo -e "${GREEN_COLOR}3${RES} - 卸载 OpenList"
        echo -e "${GREEN_COLOR}4${RES} - 迁移 Alist 数据"
        echo -e "${GREEN_COLOR}5${RES} - 设置管理员密码"
        echo -e "${GREEN_COLOR}6${RES} - 启动服务"
        echo -e "${GREEN_COLOR}7${RES} - 停止服务"
        echo -e "${GREEN_COLOR}8${RES} - 重启服务"
        echo -e "${GREEN_COLOR}9${RES} - 查看状态"
        echo -e "${GREEN_COLOR}10${RES} - 查看日志"
        echo -e "${GREEN_COLOR}0${RES} - 退出脚本"
        echo
        read -r -p "请选择操作 [0-10]: " choice
        case "$choice" in
            1) check_disk_space && install_openlist ;;
            2) check_disk_space && update_openlist ;;
            3) uninstall_openlist ;;
            4) check_disk_space && migrate_alist_data ;;
            5) set_admin_password ;;  # 调用新函数
            6) control_service start "启动" ;;
            7) control_service stop "停止" ;;
            8) control_service restart "重启" ;;
            9) show_status ;;
            10) show_logs ;;
            0)
                echo -e "${GREEN_COLOR}谢谢使用！${RES}"
                exit 0
                ;;
            *) echo -e "${RED_COLOR}无效选项，请重新选择${RES}"; sleep 2 ;;
        esac
    done
}