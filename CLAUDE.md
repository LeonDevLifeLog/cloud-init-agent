# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 这个仓库是什么

它**不是应用代码**，而是一套「AI agent 运行时」容器镜像的构建定义：一个多 stage `Dockerfile` +
语言安装脚本 + 一个 GitHub Actions 工作流。产物是推送到 GHCR 的镜像
`ghcr.io/leondevlifelog/agent-runtime`，供 AI agent 作为独立研发环境使用（容器最终在**中国境内**运行）。

## 验证方式（最重要）

本仓库没有测试/lint，**验证靠 CI**：改完 push，观察 GitHub Actions 是否绿。

```bash
git push                                   # 触发 main(edge) 构建
gh run list --limit 1 --json databaseId,status --jq '.[0]'
gh run watch <run-id> --exit-status        # 盯到结束
gh run view <run-id> --json conclusion,jobs --jq '{conclusion,jobs:[.jobs[]|{name,conclusion}]}'
gh run view <run-id> --log-failed > /tmp/f.log   # 失败时导出日志用 Read 看（管道 grep 在本机会被 wrapper 干扰）
```

本机 `docker build` 常因网络拉不到 `ubuntu:24.04` 基础镜像而失败——**不要依赖本地构建做验证**，以 CI 为准。
构建产出的 tag/内嵌版本可用 GHCR registry API 核对（token 见 `gh auth token`，blob 需 `curl -L` 跟随重定向）。

单独构建某一层（本机网络允许时）：`docker build --target <base|node|go|java|full> -t agent-runtime:<t> .`

## 镜像架构

多 stage 分层，`scripts/install-*.sh` 把语言安装逻辑抽出、被单语言 stage 与 `full` 共用：

- **`base`** = 系统 CLI + Python(3 + uv) + **三个包管理器入口 apt / x-cmd / brew** + gh/glab/yq/multica + `agent` 用户。**不含** Node/Go/Java SDK。
- **`node` / `go` / `java`** = `FROM base` 各叠一种语言。
- **`full`**（→ `latest`）= base + Node + Go + Java。

CI (`.github/workflows/build.yml`) 用 **matrix** 并行构建全部 5 个 target 推 GHCR，按 target 分 scope 复用 gha 缓存。

## 版本 / 发布规范

git tag 驱动，**版本号 `v<x.y.z>`，`v` 不可省略**，镜像 tag 与 git tag 一字一致：

- push `main` → edge：产出 `<target>-edge`、`<target>-<sha>`，**不动** `latest`/bare tag。
- push tag `vX.Y.Z` → release：产出 `vX.Y.Z`、`<target>-vX.Y.Z`、滚动 bare `<target>`、`latest`，并由 `release` job 自动建 GitHub Release。
- 发布：`git tag vX.Y.Z && git push origin vX.Y.Z`。
- 版本号经 `ver` 步骤算出 → 作为 build-arg `VERSION` 注入 → 镜像内 `AGENT_RUNTIME_VERSION` 环境变量 + OCI `org.opencontainers.image.version` label（三处一致，含 `v`）。

## 改动时必须知道的约束（踩过的坑）

- **工具安装优先级**：apt > x-cmd > brew > 官方二进制/tarball > 脚本。降级需在注释写明原因。
- **gh/glab/yq/multica 一律二进制安装，禁止改回 apt 源**：镜像内残留指向境外（如 `cli.github.com`）的 apt 源，会让容器在**境内**运行时 `apt update` 整体卡死。Node/Java 用 Ubuntu 默认源可以。
- **ARG 作用域按 stage 独立**：`TARGETARCH`（及任何 base 里声明、子 stage 要用的 ARG）必须在 `java`/`full` 等子 stage **重新声明**，否则 `JAVA_HOME` 等会拿到空值。
- **x-cmd**：per-user 装到 `$HOME/.x-cmd.root`，必须放在 `USER agent` + COPY dotfiles **之后**；安装器收尾会因写 `/setup.log` 无权限而非 0 退出，属 cosmetic，故用 `|| true` 后以 `test -e $HOME/.x-cmd.root/X` 作真正成功判据。
- **Go 经 x-cmd 装**（`x env use go`）再 symlink 到 `/usr/local/bin`，保证非交互（`docker run img go build`）也能用。source x-cmd 的 `X` 前必须 `export ___X_CMD_ROOT` 且**不能开 `set -u`**（nounset 会撞未设变量报错）。
- **VERSION 的 ARG/ENV/LABEL 放在 base 末尾**（brew 之后），避免版本变动破坏前面 apt/brew/x-cmd 重层缓存。
- 镜像以非 root `agent` 用户运行，带免密 sudo；脚本里 apt/写 `/usr/local` 用 `sudo`。
- 纯 Docker 方案，**没有 cloud-init**（仓库曾叫 cloud-init-agent，勿被历史命名误导）。

## 尚未落地（改动前先看是否已存在）

- 凭据注入 entrypoint（gh/glab/multica 的 token 目前靠运行时手动注入，README「认证」节有说明）。
- apt/Homebrew 的境内镜像源（当前只有 gh 做了境内适配）。
