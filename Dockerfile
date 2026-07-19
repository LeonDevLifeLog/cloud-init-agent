FROM ubuntu:24.04

# ---- 版本锚定（改这里即可升级） ----
# Java/Node 改用 apt（Ubuntu 默认源），Go 改用 x-cmd 安装，故不再 pin 这三者版本
ARG YQ_VERSION=4.45.1
ARG GLAB_VERSION=1.108.0
ARG MULTICA_VERSION=0.4.4
ARG XCMD_VERSION=v0.9.13
ARG TARGETARCH=amd64

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=Asia/Shanghai

# ---- 基础系统包 + 常用 CLI ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    # 基础/证书/权限
      ca-certificates curl wget gnupg sudo \
      software-properties-common apt-transport-https \
    # 版本控制
      git git-lfs \
    # 构建工具链
      build-essential pkg-config make cmake gcc g++ \
    # Python（运行时 + venv）
      python3 python3-pip python3-venv \
    # Java（Ubuntu 默认源 OpenJDK 21）
      openjdk-21-jdk \
    # Node.js（Ubuntu 默认源 + npm）
      nodejs npm \
    # 网络诊断
      iputils-ping dnsutils net-tools netcat-openbsd traceroute rsync openssh-client \
    # 文本/搜索/JSON
      jq ripgrep fd-find bat tree less diffutils file \
    # 终端/会话
      vim nano tmux screen bash-completion \
    # 进程/系统观测
      htop procps lsof strace ncdu \
    # 压缩归档
      unzip zip xz-utils p7zip-full \
    # HTTP 客户端
      httpie \
    # 本地化
      locales tzdata \
    && rm -rf /var/lib/apt/lists/*

# ---- uv (Python 包管理，pin 版本) ----
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

# ---- Java (Ubuntu OpenJDK 21，apt 已装，仅设 JAVA_HOME) ----
ENV JAVA_HOME="/usr/lib/jvm/java-21-openjdk-${TARGETARCH}"

# ---- Node.js (Ubuntu 默认源已装，补 pnpm) ----
RUN npm install -g pnpm

# ---- GitHub CLI (gh) ----
RUN set -eux; \
    mkdir -p -m 755 /etc/apt/keyrings; \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /etc/apt/keyrings/githubcli-archive-keyring.gpg; \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list; \
    apt-get update && apt-get install -y --no-install-recommends gh; \
    rm -rf /var/lib/apt/lists/*

# ---- yq (YAML 处理) ----
RUN set -eux; \
    curl -fsSL "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${TARGETARCH}" \
      -o /usr/local/bin/yq; \
    chmod +x /usr/local/bin/yq

# ---- glab (GitLab CLI) ----
RUN set -eux; \
    curl -fsSL "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_linux_${TARGETARCH}.tar.gz" \
      | tar -C /tmp -xz; \
    install -m 755 /tmp/bin/glab /usr/local/bin/glab; \
    rm -rf /tmp/bin

# ---- multica CLI (managed agents platform) ----
RUN set -eux; \
    curl -fsSL "https://github.com/multica-ai/multica/releases/download/v${MULTICA_VERSION}/multica-cli-${MULTICA_VERSION}-linux-${TARGETARCH}.tar.gz" \
      | tar -C /usr/local/bin -xz multica; \
    chmod +x /usr/local/bin/multica

# ---- 非 root 用户 ----
RUN useradd -ms /bin/bash agent \
    && echo 'agent ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/agent \
    && chmod 0440 /etc/sudoers.d/agent

# ---- 常见配置（dotfiles）----
COPY --chown=agent:agent rootfs/home/ /home/agent/

USER agent
WORKDIR /home/agent

# ---- x-cmd (POSIX shell 工具集，per-user 安装到 $HOME/.x-cmd.root) ----
# 必须在 USER agent + COPY dotfiles 之后：它写 $HOME 并向 .bashrc 追加激活行
# 安装器收尾时会尝试写 /setup.log（无权限）导致非 0 退出，属 cosmetic；
# 以入口文件 $HOME/.x-cmd.root/X 是否生成作为真正的成功判据。
RUN ___X_CMD_TOINSTALL_VERSION="${XCMD_VERSION}" ___X_CMD_XBINEXP_EXIT=1 \
      sh -c "$(curl -fsSL https://get.x-cmd.com)" || true; \
    test -e "$HOME/.x-cmd.root/X"

# ---- Go (通过 x-cmd 安装) ----
# x-cmd 仅在交互式 shell 激活，故装完后把真实二进制符号链接到 /usr/local/bin，
# 保证 `docker run img go build` 这类非交互调用也能用（go 会顺着 symlink 解析 GOROOT）。
RUN set -ex; \
    export ___X_CMD_ROOT="$HOME/.x-cmd.root"; \
    . "$___X_CMD_ROOT/X"; \
    x env use go; \
    gobin="$(go env GOROOT)/bin"; \
    sudo ln -sf "$gobin/go" /usr/local/bin/go; \
    sudo ln -sf "$gobin/gofmt" /usr/local/bin/gofmt; \
    go version

CMD ["/bin/bash"]
