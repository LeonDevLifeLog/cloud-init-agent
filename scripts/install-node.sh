#!/usr/bin/env bash
# Node.js（Ubuntu 默认源）+ pnpm。以 agent 用户运行，apt/npm-g 用 sudo。
set -eux
sudo apt-get update
sudo apt-get install -y --no-install-recommends nodejs npm
sudo rm -rf /var/lib/apt/lists/*
sudo npm install -g pnpm
