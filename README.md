# OpenList 交互式管理脚本

一个功能强大且用户友好的 OpenList 交互式管理脚本，旨在简化 OpenList 的安装、配置和日常维护任务。

[![版本](https://img.shields.io/badge/版本-v1.4.2-blue.svg)](onelist.sh)

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
- **Docker 支持**: 提供通过 Docker 安装和管理 OpenList 的选项，简化部署流程。

## 系统要求

- 操作系统：支持 systemd 的主流 Linux 发行版 (如 Ubuntu, Debian, CentOS 等)
- 用户权限：需要 `root` 权限来执行安装和服务管理等操作。
- 必要命令：`curl`、`tar` (以及 `docker` 如果您计划使用 Docker 相关功能)。
- 系统架构：`x86_64 (amd64)` 或 `aarch64 (arm64)`。

## 使用方法



    
    curl -fsSL "https://raw.githubusercontent.com/ypq123456789/openlist/refs/heads/main/openlist.sh" -o openlist.sh && chmod +x openlist.sh && sudo ./openlist.sh
    

## 脚本菜单详解

### 基本操作

-   **1. 安装 OpenList**：首次安装或覆盖安装 OpenList。脚本会自动处理下载、解压、创建服务等所有步骤。
-   **2. 更新 OpenList**：将已安装的 OpenList 更新到最新版本或指定版本。
-   **3. 卸载 OpenList**：从系统中彻底移除 OpenList，包括程序文件、数据和系统服务。
-   **4. 迁移 Alist 数据**：将 Alist 的数据（数据库和配置）迁移到 OpenList，方便从 Alist 过渡。

### 服务管理

-   **5. 启动服务**：启动 `openlist.service`。
-   **6. 停止服务**：停止 `openlist.service`。
-   **7. 重启服务**：重启 `openlist.service`。
-   **8. 查看状态**：显示 OpenList 的运行状态、版本信息、文件路径和网络访问地址等。
-   **9. 查看日志**：提供多种日志查看选项，包括实时日志、错误日志和查找初始密码。

### 高级操作

-   **10. 修改管理员密码**：
    -   **随机生成密码**：调用 `openlist admin random` 生成一个随机的新密码。
    -   **手动设置密码**：调用 `openlist admin set <密码>` 手动指定一个新密码。

### Docker 管理 (Docker Management)

-   **11. 通过 Docker 安装 OpenList**: 使用 Docker 快速部署 OpenList。脚本将拉取最新的 `ghcr.io/openlistteam/openlist-git:main` 镜像并在容器中运行 OpenList。
-   **12. 管理 Docker 中的 OpenList**: 进入 Docker 管理子菜单，对已通过 Docker 安装的 OpenList 实例进行维护。

### 退出

-   **0. 退出脚本**：安全退出本管理脚本。

#### Docker 管理子菜单详解 (OpenList Docker Management)

当您选择主菜单中的“管理 Docker 中的 OpenList”后，将进入此子菜单：

-   **1. 设置管理员密码**: 修改在 Docker 容器中运行的 OpenList 实例的管理员密码。
-   **2. 重启容器**: 重启 `openlist` Docker 容器。
-   **3. 查看容器状态**: 显示 `openlist` Docker 容器的当前状态 (类似于 `docker ps` 命令)。
-   **4. 查看容器日志**: 查看 `openlist` Docker 容器的日志，可选择查看最近的日志或实时跟踪日志。
-   **5. 查看初始密码**: 从 Docker 容器日志中查找并显示 OpenList 的初始管理员密码。
-   **6. 停止容器**: 停止运行中的 `openlist` Docker 容器。
-   **7. 启动已停止的容器**: 启动一个已存在但当前已停止的 `openlist` Docker 容器。
-   **8. 移除容器**: 停止并移除 `openlist` Docker 容器。注意：此操作可能会导致数据丢失，除非数据存储在外部卷上。
-   **0. 返回主菜单**: 退出 Docker 管理子菜单，返回到主脚本菜单。

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

