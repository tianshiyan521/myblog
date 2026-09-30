---
title: Linux 命令速查
date: 2026-06-12 10:00:00
categories: 工具与运维
tags: [Linux, 命令, 运维, 日志排查]
---

测试工程师迟早要跟 Linux 打交道。不一定要搭服务器，但**查日志、看进程、清磁盘**这几件事躲不掉。

本专栏用每日一条命令的形式积累，每条都配测试场景的用法。

<!-- more -->

## 测试为什么要会 Linux

三个高频场景：

**① 查日志**

测试环境出了问题，日志在服务器上。不会 `grep` / `tail`，你只能找开发帮你看——**别人看的结果和自己看，理解的深度完全不同。**

```bash
# 实时看日志，重点盯 ERROR
tail -f /var/log/game/server.log | grep -i error

# 查某个玩家相关的全部日志
grep "player_id=12345" server.log

# 查某个时间段的日志（日志里常有时间戳）
sed -n '/2026-09-29 14:00/,/2026-09-29 15:00/p' server.log
```

**② 看资源占用**

压测的时候服务器 CPU、内存、磁盘、网络什么情况，光看测试报告不够：

```bash
top          # CPU / 内存实时占用
df -h        # 磁盘使用率（日志爆盘是常见事故）
netstat -an  # 网络连接数与端口占用
```

**③ 清场与重启**

```bash
ps aux | grep game_server   # 找到进程
kill 12345                   # 优雅终止
kill -9 12345                # 强制杀死（卡死时用）
```

---

## 专栏结构

### 文件与目录操作

`ls` / `cd` / `cp` / `mv` / `rm` / `find` / `tar` / `ln` / `pwd`

### 权限管理

`chmod` / `chown` / `sudo` / `umask`

### 进程与性能监控

`ps` / `top` / `htop` / `kill` / `df` / `du` / `free` / `uptime`

### 网络排查

`ping` / `netstat` / `ss` / `curl` / `telnet` / `traceroute`

### 文本处理（测试最常用）

`grep` / `awk` / `sed` / `sort` / `uniq` / `wc` / `cut` / `head` / `tail`

### 定时任务与脚本

`crontab` / `vim` / `echo` / 管道与重定向 / Shell 变量与循环

---

## 三条救命命令

如果只记三条，记这三个：

### 1. `tail -f` —— 实时看日志

```bash
tail -f server.log
```

日志滚动刷新，边操作边看。配合 `grep` 过滤：

```bash
tail -f server.log | grep --line-buffered "ERROR"
```

> ⚠️ 管道里不加 `--line-buffered`，`grep` 会攒够缓冲区才输出，看起来像"卡住了"。

### 2. `grep -A 5 -B 5` —— 带上下文搜

```bash
grep -A 5 -B 5 "NullPointerException" server.log
```

`-A 5` 显示匹配行的后 5 行，`-B 5` 显示前 5 行。**报错日志的关键信息往往不在报错那一行，而在前后几行。**

### 3. `df -h` —— 查磁盘

```bash
df -h
```

测试环境莫名起不来服务，**第一个要怀疑的就是磁盘满了**。日志没有轮转策略的话，几天就能把盘写满。

---

## 学习建议

Linux 命令没必要背全表。**按场景记更牢**：

| 场景 | 需要的命令 |
|------|-----------|
| 查日志 | tail、grep、sed、awk |
| 看性能 | top、free、df、netstat |
| 清场重启 | ps、kill、systemctl |
| 部署环境 | tar、chmod、cp、ln |
| 定时任务 | crontab |

> 适合人群：零 Linux 基础的测试/运维新人。
