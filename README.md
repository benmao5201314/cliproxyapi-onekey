# CLIProxyAPI 一键安装脚本

本仓库提供 [`router-for-me/CLIProxyAPI`](https://github.com/router-for-me/CLIProxyAPI) 的交互式一键安装、升级和卸载脚本。脚本会自动识别 Linux `amd64` / `aarch64` 架构，下载官方 Release 二进制包，生成基础配置文件，并通过 systemd 托管服务。安装完成后，CLIProxyAPI 会启用内置 Web 管理面板，面板资源来自 [`router-for-me/Cli-Proxy-API-Management-Center`](https://github.com/router-for-me/Cli-Proxy-API-Management-Center)。

## 一条命令安装

在远程 Linux 主机上执行下面一条命令即可进入安装菜单。脚本菜单包含 **1. 安装/升级**、**2. 卸载**、**3. 退出**。

```bash
curl -fsSL https://raw.githubusercontent.com/benmao5201314/cliproxyapi-onekey/main/install.sh | sudo bash
```

如果你的系统没有 `curl`，可以先安装 `curl` 后再执行上述命令。

## 安装后访问地址

安装完成后，脚本会在终端输出实际端口和访问地址。假设服务器 IP 是 `8.219.118.131`，端口使用默认值 `8317`，常用地址如下。

| 用途 | 地址 |
|---|---|
| 服务根路径 | `http://8.219.118.131:8317/` |
| OpenAI 兼容 API Base URL | `http://8.219.118.131:8317/v1` |
| 模型列表接口 | `http://8.219.118.131:8317/v1/models` |
| Web 管理面板 | `http://8.219.118.131:8317/management.html` |

如果你已经通过 Nginx、1Panel、宝塔或云防火墙把服务反代到 80 端口，则可按你的反代地址访问，例如 `http://8.219.118.131/management.html`。

## API Key 与管理密钥策略

安装时可以不预置客户端 API Key。此时脚本会生成 `api-keys: []`，你可以安装完成后进入 Web 管理面板，在 API Keys 相关页面中新增客户端 API Key。客户端 API Key 用于 Cherry Studio、OpenAI SDK、Cursor、Chatbox 等客户端请求 `/v1/chat/completions`、`/v1/models` 等 OpenAI 兼容接口。

管理 `secret-key` 不能完全依赖安装后网页初始化，因为 Web 管理面板连接管理 API 时需要先通过管理密钥鉴权。脚本现在采用更安全的默认策略：**安装时管理 secret-key 留空会自动生成一个 `mgmt-cpa-...` 密钥**，并在安装完成后输出。你需要使用这个密钥登录或连接 Web 管理面板。若你输入 `none`，则会禁用 Web 管理面板和远程管理接口。

| 密钥类型 | 是否可安装时留空 | 用途 | 建议 |
|---|---|---|---|
| 客户端 API Key | 可以 | 客户端调用 `/v1` 接口鉴权 | 可以安装后在 Web 管理面板添加。 |
| 管理 secret-key | 可以，但会自动生成 | 访问 `/management.html` 和 `/v0/management` 管理接口 | 建议保留自动生成值并妥善保存。 |

## 可自定义参数

安装过程采用交互式提示，支持自定义 CLIProxyAPI 版本、安装目录、配置目录、数据目录、日志目录、运行用户、服务端口、监听地址、全局代理、调试日志、文件日志、预置客户端 API Key、管理 `secret-key`、是否允许远程访问 Web 管理面板和管理接口，以及额外启动参数。

| 项目 | 默认值 | 说明 |
|---|---:|---|
| 安装目录 | `/opt/cliproxyapi` | 保存 `cli-proxy-api` 二进制文件和官方示例配置。 |
| 配置目录 | `/etc/cliproxyapi` | 保存生成的 `config.yaml`。 |
| 数据目录 | `/var/lib/cliproxyapi` | 保存 OAuth/账号认证数据。 |
| 日志目录 | `/var/log/cliproxyapi` | 启用文件日志时作为日志目录。 |
| 服务名称 | `cliproxyapi` | systemd 服务名称。 |
| 默认端口 | `8317` | CLIProxyAPI 服务端口。 |
| Web 管理面板 | 启用 | 访问路径为 `/management.html`。 |

## 常用命令

安装完成后，可以使用以下命令管理服务。

```bash
systemctl status cliproxyapi --no-pager
journalctl -u cliproxyapi -f
systemctl restart cliproxyapi
```

如果需要重新进入菜单执行升级或卸载，可以再次运行一条命令安装命令，选择对应菜单项即可。

## 防火墙与安全组

如果外部无法访问，请确认 VPS 系统防火墙和云服务商安全组都已经放行服务端口，例如默认端口 `8317`。

```bash
ufw allow 8317/tcp
ss -lntp | grep 8317
```

如果你允许公网访问 Web 管理面板，请务必妥善保存管理 `secret-key`，不要在公开聊天、工单或日志中泄露。若密钥已经泄露，建议重新运行安装脚本或手动修改 `/etc/cliproxyapi/config.yaml` 后重启服务。

## 注意事项

脚本会从 CLIProxyAPI 官方 GitHub Release 下载二进制包，并在可用时校验 `checksums.txt` 中的 SHA256。执行远程脚本前，请确认你信任本仓库内容，并建议先阅读 `install.sh`。
