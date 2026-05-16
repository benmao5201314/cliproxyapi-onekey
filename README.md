# CLIProxyAPI 极简一键安装脚本

本仓库提供 [`router-for-me/CLIProxyAPI`](https://github.com/router-for-me/CLIProxyAPI) 的极简一键安装、升级和卸载脚本。脚本保留菜单入口，菜单包含 **1. 安装/升级**、**2. 卸载**、**3. 退出**；选择安装后不再询问版本、目录、端口、密钥或其他参数，全部采用默认值并自动生成管理 `secret-key`。安装完成后，CLIProxyAPI 会启用内置 Web 管理面板，面板资源来自 [`router-for-me/Cli-Proxy-API-Management-Center`](https://github.com/router-for-me/Cli-Proxy-API-Management-Center)。

## 一条命令运行

在远程 Linux 主机上执行下面一条命令即可进入菜单。选择 **1. 安装/升级** 后，脚本会自动完成下载、配置、systemd 服务创建和启动。

```bash
curl -fsSL https://github.com/benmao5201314/cliproxyapi-onekey/raw/refs/heads/main/install.sh | sudo bash
```

如果系统没有 `curl`，请先通过系统包管理器安装 `curl`，再执行上述命令。脚本需要 root 权限运行，推荐保留命令中的 `sudo bash`。

## 极简安装默认行为

安装流程不会要求填写任何参数。脚本会自动获取 CLIProxyAPI 最新 Release，识别 `amd64` 或 `aarch64` 架构，下载官方 Linux 二进制包，生成基础配置文件，并通过 systemd 托管服务。

| 项目 | 默认值或行为 | 说明 |
|---|---|---|
| 版本 | 最新 Release | 自动获取上游最新版本。 |
| 安装目录 | `/opt/cliproxyapi` | 保存 `cli-proxy-api` 二进制文件和官方示例配置。 |
| 配置目录 | `/etc/cliproxyapi` | 生成 `/etc/cliproxyapi/config.yaml`。 |
| 数据目录 | `/var/lib/cliproxyapi` | 保存 OAuth、账号认证和运行数据。 |
| 日志目录 | `/var/log/cliproxyapi` | 启用文件日志后的日志目录。 |
| systemd 服务 | `cliproxyapi` | 自动写入并启动 `cliproxyapi.service`。 |
| 运行用户 | `cliproxyapi` | 自动创建系统用户。 |
| 监听地址 | 空 | 表示监听所有地址。 |
| 服务端口 | `8317` | 默认访问端口。 |
| Web 管理面板 | 启用 | 访问路径为 `/management.html`。 |
| 管理 `secret-key` | 自动生成 | 形如 `mgmt-cpa-...`，安装完成后终端输出。 |
| 客户端 API Key | 不预置 | 安装后在 Web 管理面板的 API Keys 页面添加。 |
| Debug 日志 | 关闭 | 默认 `debug: false`。 |
| 文件日志 | 开启 | 默认 `logging-to-file: true`。 |

## 安装后访问地址

安装完成后，脚本会在终端输出实际端口、管理面板地址和自动生成的管理 `secret-key`。假设服务器 IP 是 `8.219.118.131`，默认端口是 `8317`，常用地址如下。

| 用途 | 地址 |
|---|---|
| 服务根路径 | `http://8.219.118.131:8317/` |
| OpenAI 兼容 API Base URL | `http://8.219.118.131:8317/v1` |
| 模型列表接口 | `http://8.219.118.131:8317/v1/models` |
| Web 管理面板 | `http://8.219.118.131:8317/management.html` |

如果你已经通过 Nginx、Caddy、1Panel、宝塔或云服务商规则把服务反代到 80 或 443 端口，则可以直接访问你的反代地址，例如 `http://8.219.118.131/management.html` 或 `https://你的域名/management.html`。

## API Key 与管理密钥策略

客户端 API Key 默认不在安装阶段预置。安装成功后，请先使用终端输出的管理 `secret-key` 打开 Web 管理面板，再在 API Keys 相关页面中新增客户端 API Key。客户端 API Key 用于 Cherry Studio、OpenAI SDK、Cursor、Chatbox 等客户端请求 `/v1/chat/completions`、`/v1/models` 等 OpenAI 兼容接口。

管理 `secret-key` 是进入 `/management.html` 和调用 `/v0/management/*` 管理接口的管理员密钥。脚本会自动生成一个 `mgmt-cpa-...` 密钥并在安装完成时输出，请务必立即保存。如果密钥泄露，建议重新运行安装流程或手动修改 `/etc/cliproxyapi/config.yaml` 中的 `remote-management.secret-key` 后重启服务。

| 密钥类型 | 默认行为 | 用途 | 操作建议 |
|---|---|---|---|
| 客户端 API Key | 安装时不预置 | 客户端调用 `/v1` 接口鉴权 | 登录 Web 管理面板后添加。 |
| 管理 `secret-key` | 自动生成并输出 | 访问 Web 管理面板和管理接口 | 妥善保存，不要公开泄露。 |

## 卸载行为

再次运行一条命令进入菜单并选择 **2. 卸载**，脚本会直接执行彻底卸载，不再询问是否保留配置、数据、日志或系统用户。卸载会停止并禁用服务，删除 systemd 单元文件、环境文件、程序目录、配置目录、数据目录、日志目录、默认系统用户以及脚本使用过的临时目录。

| 删除对象 | 默认路径或名称 |
|---|---|
| systemd 服务 | `/etc/systemd/system/cliproxyapi.service` |
| systemd 环境文件 | `/etc/default/cliproxyapi` |
| 程序目录 | `/opt/cliproxyapi` |
| 配置目录 | `/etc/cliproxyapi` |
| 数据目录 | `/var/lib/cliproxyapi` |
| 日志目录 | `/var/log/cliproxyapi` |
| 系统用户 | `cliproxyapi` |

> **注意：卸载是彻底删除模式。** 如果你需要保留账号认证数据、配置文件或日志，请在选择卸载前自行备份相关目录。

## 常用服务命令

安装完成后，可以使用以下命令管理服务和查看日志。

```bash
systemctl status cliproxyapi --no-pager
journalctl -u cliproxyapi -f
systemctl restart cliproxyapi
```

如果外部无法访问，请确认 VPS 系统防火墙和云服务商安全组已经放行默认端口 `8317`。

```bash
ufw allow 8317/tcp
ss -lntp | grep 8317
```

## 注意事项

脚本会从 CLIProxyAPI 官方 GitHub Release 下载二进制包，并在可用时校验 `checksums.txt` 中的 SHA256。执行远程脚本前，请确认你信任本仓库内容，并建议先阅读 `install.sh`。
