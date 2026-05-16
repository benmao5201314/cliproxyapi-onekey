# CLIProxyAPI 一键安装脚本

本仓库提供 `router-for-me/CLIProxyAPI` 的交互式一键安装、升级和卸载脚本。脚本会自动识别 Linux `amd64` / `aarch64` 架构，下载官方 Release 二进制包，生成基础配置文件，并通过 systemd 托管服务。[1]

## 一条命令安装

在远程 Linux 主机上执行下面一条命令即可进入安装菜单。脚本菜单包含 **1. 安装/升级**、**2. 卸载**、**3. 退出**。

```bash
curl -fsSL https://raw.githubusercontent.com/benmao5201314/cliproxyapi-onekey/main/install.sh | sudo bash
```

如果你的系统没有 `curl`，可以先安装 `curl` 后再执行上述命令。

## 可自定义参数

安装过程采用交互式提示，支持自定义 CLIProxyAPI 版本、安装目录、配置目录、数据目录、日志目录、运行用户、服务端口、监听地址、全局代理、调试日志、文件日志、客户端 API Key、管理接口 secret-key、是否允许远程管理，以及额外启动参数。

| 项目 | 默认值 | 说明 |
|---|---:|---|
| 安装目录 | `/opt/cliproxyapi` | 保存 `cli-proxy-api` 二进制文件和官方示例配置。 |
| 配置目录 | `/etc/cliproxyapi` | 保存生成的 `config.yaml`。 |
| 数据目录 | `/var/lib/cliproxyapi` | 保存 OAuth/账号认证数据。 |
| 日志目录 | `/var/log/cliproxyapi` | 启用文件日志时作为日志目录。 |
| 服务名称 | `cliproxyapi` | systemd 服务名称。 |
| 默认端口 | `8317` | CLIProxyAPI 官方示例配置使用的常见端口。[1] |

## 常用命令

安装完成后，可以使用以下命令管理服务。

```bash
systemctl status cliproxyapi --no-pager
journalctl -u cliproxyapi -f
systemctl restart cliproxyapi
```

如果需要重新进入菜单执行升级或卸载，可以再次运行一条命令安装命令，选择对应菜单项即可。

## 注意事项

脚本会从 CLIProxyAPI 官方 GitHub Release 下载二进制包，并在可用时校验 `checksums.txt` 中的 SHA256。执行远程脚本前，请确认你信任本仓库内容，并建议先阅读 `install.sh`。

## References

[1]: https://github.com/router-for-me/CLIProxyAPI "router-for-me/CLIProxyAPI"
