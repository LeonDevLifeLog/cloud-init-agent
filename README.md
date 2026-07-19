# agent-env

AI agent 研发用的独立工作环境镜像。基于 Ubuntu 24.04，预装常用命令行工具与
Node.js / Python / Go / Java 四套语言工具链，由 GitHub Actions 自动构建并推送到 GHCR。

## 包含内容

镜像采用**分层多 tag**：`base` 只含系统工具与三个包管理器入口，各语言在 `base` 上独立成层。

- **`base`**（约 400MB）
  - 基础系统：Ubuntu 24.04，非 root 用户 `agent`（带免密 sudo），时区 `Asia/Shanghai`
  - Python 3.12（+ pip / venv / uv）
  - 三个包管理器入口：**apt**、**x-cmd**（POSIX shell 工具集）、**Homebrew**（Linuxbrew）
  - 常用 CLI：git / git-lfs、gh、glab、multica、yq、jq、ripgrep、fd、bat、tree、
    htop、tmux、screen、rsync、httpie、网络诊断工具（ping/dig/netcat 等）、
    构建工具链（gcc/g++/make/cmake）等
- **`node`** = base + Node.js（Ubuntu 源，+ npm / pnpm）
- **`go`** = base + Go（经 x-cmd 安装，链接到 /usr/local/bin）
- **`java`** = base + OpenJDK 21（Ubuntu 源）
- **`full`**（= `latest`）= base + Node + Go + Java（Python 已在 base）

二进制类工具（yq/glab/multica）版本在 `Dockerfile` 顶部 `ARG` 锚定；apt 装的随 Ubuntu 源。

## 使用

```bash
# 全能镜像（= full），开箱即用
docker run -it --rm ghcr.io/<owner>/<repo>/agent-env:latest

# 只要某一种语言，拉对应 tag（更小、更快）
docker run -it --rm ghcr.io/<owner>/<repo>/agent-env:go
docker run -it --rm ghcr.io/<owner>/<repo>/agent-env:node

# 挂载当前目录进容器工作
docker run -it --rm -v "$PWD":/home/agent/work -w /home/agent/work \
  ghcr.io/<owner>/<repo>/agent-env:latest
```

镜像 tag：
- `latest` —— 默认分支的 `full`
- `base` / `node` / `go` / `java` / `full` —— 各分层
- `<target>-sha-<gitsha>` —— 锁定到具体提交与分层（可复现）

## 本地构建

```bash
# 构建某个分层（--target 选 base/node/go/java/full）
docker build --target full -t agent-env:full .
docker run -it --rm agent-env:full
```

## 自动构建

推送到 `main`、打 `v*` tag，或手动触发（workflow_dispatch）时，
`.github/workflows/build.yml` 会用 buildx **矩阵**构建全部分层并推送到 GHCR。
