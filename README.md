# OpenList 交互式管理脚本

一个功能强大且用户友好的 OpenList 交互式管理脚本，旨在简化 OpenList 的安装、配置和日常维护任务。

[![版本](https://img.shields.io/badge/版本-v1.5.0-blue.svg)](onelist.sh)

## 环境检测与推荐

- 脚本启动后会自动检测：
  - **Docker 是否已安装**
  - **OpenList Docker 容器是否已安装**（只要有官方4个镜像的容器即视为已安装）
  - **域名绑定状态**（主界面会自动检测并显示当前已绑定的域名，如未绑定则提示“未绑定域名”）
- 主菜单顶部会醒目推荐：
  - **二进制文件安装**（适合大多数用户，兼容性好）
  - **Docker 安装**（适合有 Docker 环境的用户，隔离性强）

## 简介

此脚本通过一个清晰的交互式菜单，提供了对 OpenList 的全方位管理功能，从首次安装到后期的服务监控、数据迁移和密码管理，一切尽在掌握。无需记忆复杂的命令，只需运行脚本并根据菜单提示进行选择即可。

## 功能特性

- **一键安装与部署**：自动检测系统环境，下载并安装最新或指定版本的 OpenList。
- **服务全周期管理**：轻松启动、停止、重启 OpenList 服务，并实时查看服务状态。
- **便捷的更新与卸载**：安全地更新 OpenList 到新版本，或将其从系统中完全卸载。
- **强大的日志系统**：支持查看实时日志、历史日志、错误日志，并能快速定位初始密码。
- **灵活的密码管理**：支持随机生成密码或手动设置新的管理员密码。
- **数据迁移**：提供从 Alist 无缝迁移数据到 OpenList 的功能。
- **系统兼容性**：支持 x86_64 和 aarch64 架构，并在主流 Linux 发行版（如 Ubuntu, Debian, CentOS）上经过测试。
- **智能依赖检查**：自动检查并提示安装 `curl` 和 `tar` 等必要依赖。
- **Docker 一键管理**：支持通过 Docker 镜像一键安装、启动、进入容器、设置密码、重启、查看日志和状态，并可选择官方多种镜像标签。
- **域名绑定与反向代理**：支持一键检测/安装 Nginx，自动生成反代配置，提示域名A记录指向本机IP。
- **定时自动更新**：支持二进制服务和 Docker 两种模式，提供常用定时选项和自定义 crontab，支持一键取消和查看当前任务。

## 系统要求

- 操作系统：支持 systemd 的主流 Linux 发行版 (如 Ubuntu, Debian, CentOS 等)
- 用户权限：需要 `root` 权限来执行安装和服务管理等操作。
- 必要命令：`curl` 和 `tar`。
- 系统架构：`x86_64 (amd64)` 或 `aarch64 (arm64)`。
- Docker 相关功能需支持 Docker 环境（脚本可自动安装 Docker）。

## 使用方法

### 推荐：一键运行脚本（无需下载，适合快速体验/云主机/临时环境）
安装完成后想再进入脚本就继续一键运行脚本，脚本自动更新

```bash
curl -fsSL "https://raw.githubusercontent.com/ypq123456789/openlist/refs/heads/main/openlist.sh" | sudo bash
```

### 可选：本地下载后运行（适合需自定义或长期维护的用户）
安装完成后想再进入脚本只需输入最后一步，但脚本没法自动更新

```bash
curl -fsSL "https://raw.githubusercontent.com/ypq123456789/openlist/refs/heads/main/openlist.sh" -o openlist.sh
chmod +x openlist.sh
sudo ./openlist.sh
```

## 脚本菜单详解

### 二进制文件服务模式

-   **1. 安装 OpenList**：首次安装或覆盖安装 OpenList。脚本会自动处理下载、解压、创建服务等所有步骤。
-   **2. 更新 OpenList**：将已安装的 OpenList 更新到最新版本或指定版本。
-   **3. 卸载 OpenList**：从系统中彻底移除 OpenList，包括程序文件、数据和系统服务。
-   **4. 迁移 Alist 数据**：将 Alist 的数据（数据库和配置）迁移到 OpenList，方便从 Alist 过渡。
-   **5. 启动服务**：启动 `openlist.service`。
-   **6. 停止服务**：停止 `openlist.service`。
-   **7. 重启服务**：重启 `openlist.service`。
-   **8. 查看状态**：显示 OpenList 的运行状态、版本信息、文件路径和网络访问地址等。
-   **9. 查看日志**：提供多种日志查看选项，包括实时日志、错误日志和查找初始密码。

### Docker 管理

-   **10. Docker 一键安装/启动 OpenList**：
    - 支持选择官方镜像标签（`beta`、`beta-ffmpeg`、`beta-aio`、`beta-aria2`），也可自定义标签。
    - 自动检测并安装 Docker 环境。
    - 自动拉取镜像并启动容器。
-   **11. 进入 OpenList 容器**：进入容器内执行命令（输入 exit 可返回脚本交互界面）。
-   **12. 容器内设置管理员密码**：在容器内一键设置新密码。
-   **13. 重启 OpenList 容器**：重启当前镜像对应的容器。
-   **14. 查看容器状态**：列出所有基于 OpenList 官方4个镜像（`beta`、`beta-ffmpeg`、`beta-aio`、`beta-aria2`）的容器状态。
-   **15. 查看容器日志**：实时查看容器日志（Ctrl+C 停止日志查看，按回车返回菜单）。

> **注意：** Docker 相关操作会自动记忆上次选择的镜像标签，后续操作无需重复选择。

### 域名绑定/反向代理

-   **16. 域名绑定/反代设置**：一键检测/安装 Nginx，输入域名自动生成反代配置，提示A记录指向本机IP。

### 定时自动更新

-   **17. 定时自动更新设置**：支持二进制服务和 Docker 两种模式，提供每小时、每3小时、每天、每周和自定义定时任务，支持一键取消和查看当前任务。

### 退出

-   **0. 退出脚本**：安全退出本管理脚本。

## 贡献与反馈

如果您发现任何 bug 或有功能建议，欢迎通过提交 Issue 来告诉我们！ 

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=ypq123456789/openlist-manger&type=Date)](https://star-history.com/#ypq123456789/openlist-manger&Date)

## 支持作者
<span><small>非常感谢您对本项目的兴趣！维护开源项目确实需要大量时间和精力投入。若您认为这个项目为您带来了价值，希望您能考虑给予一些支持，哪怕只是一杯咖啡的费用。
您的慷慨相助将激励我继续完善这个项目，使其更加实用。它还能让我更专心地参与开源社区的工作。如果您愿意提供赞助，可通过下列渠道：</small></span>
<ul>
    <li>给该项目点赞 &nbsp;<a style="vertical-align: text-bottom;" href="https://github.com/ypq123456789/openlist-manger">
      <img src="https://img.shields.io/github/stars/ypq123456789/openlist-manger?style=social" alt="给该项目点赞" />
    </a></li>
    <li>关注我的 Github &nbsp;<a style="vertical-align: text-bottom;"  href="https://github.com/ypq123456789/openlist-manger">
      <img src="https://img.shields.io/github/followers/ypq123456789?style=social" alt="关注我的 Github" />
    </a></li>
</ul>
<table>
    <thead><tr>
        <th>微信</th>
        <th>支付宝</th>
    </tr></thead>
    <tbody><tr>
        <td><img style="max-width: 50px" src="https://github.com/ypq123456789/TrafficCop/assets/114487221/fb265eef-e624-4429-b14a-afdf5b2ca9c4" alt="微信" /></td>
        <td><img style="max-width: 50px" src="https://github.com/ypq123456789/TrafficCop/assets/114487221/884b58bd-d76f-4e8f-99f4-cac4b9e97168" alt="支付宝" /></td>
    </tr></tbody>
</table>
