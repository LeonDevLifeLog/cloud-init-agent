# agent-runtime

[![build-image](https://github.com/LeonDevLifeLog/agent-runtime/actions/workflows/build.yml/badge.svg)](https://github.com/LeonDevLifeLog/agent-runtime/actions/workflows/build.yml)

AI agent 研发用的独立工作环境容器镜像。基于 Ubuntu 24.04，预装常用命令行工具与
Node.js / Python / Go / Java 语言工具链，由 GitHub Actions 自动构建并推送到 GHCR。

镜像仓库：`ghcr.io/leondevlifelog/agent-runtime`

## 镜像分层

采用**分层多 tag**：`base` 只含系统工具与三个包管理器入口，各语言在 `base` 之上独立成层。
同一宿主上多个 tag 共享 `base` 层，不重复占用磁盘。

| tag | 内容 | 压缩体积 |
|-----|------|---------|
| `base` | 系统 CLI + Python + 三包管理器入口，无其它语言 SDK | ~496 MB |
| `node` | base + Node.js | ~548 MB |
| `go` | base + Go | ~610 MB |
| `java` | base + Java | ~722 MB |
| `full` (= `latest`) | base + Node + Go + Java | ~887 MB |

> 体积为 GHCR 压缩传输大小；本地解压后约为其 2.5–3 倍。

### base 包含

- **基础系统**：Ubuntu 24.04；非 root 用户 `agent`（带免密 sudo）；时区 `Asia/Shanghai`
- **Python**：3.12（+ pip / venv / uv）
- **三个包管理器入口**：
  - **apt**（Ubuntu 默认源）
  - **x-cmd**（POSIX shell 工具集，per-user 安装，交互式 shell 自动激活）
  - **Homebrew**（Linuxbrew，全局 PATH 可用）
- **版本控制**：git、git-lfs、gh（GitHub CLI）、glab（GitLab CLI）、multica
- **常用 CLI**：yq、jq、ripgrep、fd、bat、tree、less、file、htop、tmux、screen、
  rsync、httpie、网络诊断（ping / dig / netcat / traceroute）、压缩归档（zip / xz / 7z）
- **构建工具链**：build-essential、gcc / g++、make、cmake、pkg-config

### 各语言层

- **`node`** = base + Node.js（Ubuntu 源，+ npm / pnpm）
- **`go`** = base + Go（经 x-cmd `x env use go` 安装，链接到 `/usr/local/bin`，非交互可用）
- **`java`** = base + OpenJDK 21（Ubuntu 源，`JAVA_HOME` 已设）
- **`full`** = base + 以上全部（Python 已在 base）

> 二进制类工具（yq / glab / multica）版本在 `Dockerfile` 顶部 `ARG` 锚定；apt 装的随 Ubuntu 源浮动。

## 使用

```bash
# 全能镜像（= full），开箱即用
docker run -it --rm ghcr.io/leondevlifelog/agent-runtime:latest

# 只要某一种语言，拉对应 tag（更小、更快）
docker run -it --rm ghcr.io/leondevlifelog/agent-runtime:go
docker run -it --rm ghcr.io/leondevlifelog/agent-runtime:node

# 挂载当前目录进容器工作
docker run -it --rm -v "$PWD":/home/agent/work -w /home/agent/work \
  ghcr.io/leondevlifelog/agent-runtime:latest
```

### tag 方案

镜像分两条产出线：**正式发布**（打 `vX.Y.Z` git tag）与 **edge**（push `main`）。

正式发布（`vX.Y.Z`）：
- `latest` —— 最新正式发布的 `full`
- `vX.Y.Z` —— 该版本的 `full`（如 `v1.2.3`）
- `<target>-vX.Y.Z` —— 各分层的该版本（如 `go-v1.2.3`、`base-v1.2.3`）
- `base` / `node` / `go` / `java` / `full` —— 各分层滚动指向最新正式发布

edge（`main`）：
- `<target>-edge` —— 各分层的最新开发构建（如 `full-edge`、`go-edge`）

通用（两条线都有）：
- `<target>-<gitsha>` —— 锁定到具体提交与分层，可复现（如 `go-00600e3`）

> **版本号规范：`v<x.y.z>`，`v` 不可省略**，镜像版本 tag 与 git tag 完全一致。
> 镜像内嵌版本信息：环境变量 `AGENT_RUNTIME_VERSION` 与 OCI label
> `org.opencontainers.image.version`（`docker inspect` 可查；edge 构建为 `v0.0.0-edge.<sha>`）。

## 认证 / 凭据注入

镜像内**不烤入任何凭据**，token 在 `docker run` 时通过环境变量注入（生产环境建议用
挂载文件 / docker secrets，避免 token 出现在 `docker inspect`）：

| 工具 | 注入方式 |
|------|---------|
| gh (GitHub) | `-e GH_TOKEN=<token>`，原生读取，无需登录 |
| glab (GitLab) | `-e GITLAB_TOKEN=<token>`（可选 `-e GITLAB_HOST=`）|
| multica | 容器内 `multica login --token <mul_...>`（支持 headless）|
| git push | token 就绪后运行 `gh auth setup-git` 打通 HTTPS 凭据 |

```bash
docker run -it --rm \
  -e GH_TOKEN="$GH_TOKEN" \
  -e GITLAB_TOKEN="$GITLAB_TOKEN" \
  ghcr.io/leondevlifelog/agent-runtime:latest
```

## 本地构建

```bash
# 构建某个分层（--target 选 base / node / go / java / full）
docker build --target full -t agent-runtime:full .
docker run -it --rm agent-runtime:full
```

## 自动构建（CI）

推送到 `main`、打 `v*` tag 或手动触发（workflow_dispatch）时，
`.github/workflows/build.yml` 用 buildx **矩阵**并行构建全部分层并推送到 GHCR，
按 target 分 scope 复用 GHA 缓存。

### 发布流程

打一个语义化版本 tag 即触发正式发布（构建带版本号的镜像 + 自动创建 GitHub Release）：

```bash
git tag v0.1.0
git push origin v0.1.0
```

CI 会产出 `v0.1.0` / `latest` / `<target>-v0.1.0` 等 tag，并在 GitHub Releases 生成对应条目。
main 分支的日常提交只产出 `<target>-edge` 与 `<target>-<sha>`，不影响 `latest`。

## 目录结构

```
.
├── Dockerfile                 # 多 stage：base → node/go/java → full
├── scripts/                   # 各语言安装脚本（供单语言 stage 与 full 复用）
│   ├── install-node.sh
│   ├── install-java.sh
│   └── install-go.sh
├── rootfs/home/               # agent 用户 dotfiles（.bashrc / .gitconfig）
├── .github/workflows/build.yml
└── README.md
```
