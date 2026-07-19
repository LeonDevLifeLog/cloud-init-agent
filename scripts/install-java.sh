#!/usr/bin/env bash
# Java（Ubuntu 默认源 OpenJDK 21）。以 agent 用户运行，apt 用 sudo。
# 注意：JAVA_HOME 由 Dockerfile 的 ENV 设置（脚本内 export 不会持久到镜像）。
set -eux
sudo apt-get update
sudo apt-get install -y --no-install-recommends openjdk-21-jdk
sudo rm -rf /var/lib/apt/lists/*
