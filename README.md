# agent-env

AI agent 研发用的独立工作环境镜像。基于 Ubuntu 24.04，预装常用命令行工具与
Node.js / Python / Go / Java 四套语言工具链，由 GitHub Actions 自动构建并推送到 GHCR。

## 包含内容

- **基础系统**：Ubuntu 24.04，非 root 用户 `agent`（带免密 sudo），时区 `Asia/Shanghai`
- **语言工具链**
  - Node.js（Ubuntu 源，+ npm / pnpm）
  - Python 3.12（+ pip / venv / uv）
  - Go（经 x-cmd 安装，已链接到 /usr/local/bin）
  - Java（Ubuntu OpenJDK 21）
- **常用 CLI**：git / git-lfs、gh、glab、multica、yq、jq、ripgrep、fd、bat、tree、
  htop、tmux、screen、rsync、httpie、网络诊断工具（ping/dig/netcat 等）、
  构建工具链（gcc/g++/make/cmake）等
- **x-cmd**：POSIX shell 工具集（per-user 安装，交互式 shell 自动激活）

版本在 `Dockerfile` 顶部的 `ARG` 中锚定，改一行即可升级。

## 使用

```bash
# 拉取并进入交互式环境
docker run -it --rm ghcr.io/<owner>/<repo>/agent-env:latest

# 挂载当前目录进容器工作
docker run -it --rm -v "$PWD":/home/agent/work -w /home/agent/work \
  ghcr.io/<owner>/<repo>/agent-env:latest
```

镜像 tag：
- `latest` —— 默认分支最新构建
- `sha-<gitsha>` —— 锁定到具体提交（可复现）
- `<version>` —— 打 `v*` tag 时的语义化版本

## 本地构建

```bash
docker build -t agent-env:dev .
docker run -it --rm agent-env:dev
```

## 自动构建

推送到 `main`、打 `v*` tag，或手动触发（workflow_dispatch）时，
`.github/workflows/build.yml` 会用 buildx 构建并推送到 GHCR。
