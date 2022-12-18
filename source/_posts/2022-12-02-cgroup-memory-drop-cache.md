---
title: 2022-12-02-cgroup memory drop cache
date: 2022-12-02 15:43:32
tags: 网络, etcd, soft lockup
categories: 问题排查与解决
---

# cgroup memory drop cache

## 服务器环境

- 架构

  海光X86

- 内核版本

  4.19.90-23.15.v2101.ky10.x86_64

<!--more-->

## 问题现象描述

- 网络丢包
- 网卡up/down
- etcd超时
- soft lockup等多发现象



## 问题分析

系统日志中出现 `soft lockup` （软锁死：当进程占用cpu时间超过2*watchdog_thresh会触发soft lockup）情况