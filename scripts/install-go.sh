#!/usr/bin/env bash
# Go（通过 base 里的 x-cmd 安装）。x-cmd 仅在交互式 shell 激活，故安装后把真实
# 二进制符号链接到 /usr/local/bin，保证非交互调用（docker run img go build）也能用。
set -ex
export ___X_CMD_ROOT="$HOME/.x-cmd.root"
. "$___X_CMD_ROOT/X"
x env use go
gobin="$(go env GOROOT)/bin"
sudo ln -sf "$gobin/go" /usr/local/bin/go
sudo ln -sf "$gobin/gofmt" /usr/local/bin/gofmt
go version
