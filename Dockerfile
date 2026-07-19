FROM ubuntu:24.04

# ---- 版本锚定（改这里即可升级） ----
ARG NODE_VERSION=22.14.0
ARG GO_VERSION=1.23.6
ARG JAVA_VERSION=21.0.6+7
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

# ---- Go ----
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz" \
      | tar -C /usr/local -xz
ENV PATH="/usr/local/go/bin:${PATH}"

# ---- Java (Temurin) ----
RUN set -eux; \
    JV="$(echo "$JAVA_VERSION" | tr '+' '_')"; \
    curl -fsSL "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-${JAVA_VERSION}/OpenJDK21U-jdk_x64_linux_hotspot_${JV}.tar.gz" \
      | tar -C /opt -xz && mv /opt/jdk-* /opt/java
ENV JAVA_HOME=/opt/java
ENV PATH="/opt/java/bin:${PATH}"

# ---- Node.js ----
RUN set -eux; \
    ARCH_NODE=$([ "$TARGETARCH" = "amd64" ] && echo x64 || echo arm64); \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${ARCH_NODE}.tar.xz" \
      | tar -C /usr/local --strip-components=1 -xJ
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
RUN ___X_CMD_TOINSTALL_VERSION="${XCMD_VERSION}" ___X_CMD_XBINEXP_EXIT=1 \
      sh -c "$(curl -fsSL https://get.x-cmd.com)"

CMD ["/bin/bash"]
