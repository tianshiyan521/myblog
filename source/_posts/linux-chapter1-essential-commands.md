---
title: Linux 第1章 - 测试工程师常用命令速查
date: 2026-06-12
categories: 工具与运维
tags: [Linux, 命令, 运维, Shell]
---

## 1. 为什么测试要学 Linux

- 部署测试环境离不开Linux服务器
- 查日志定位BUG需要 `grep` / `tail` / `less`
- 看服务器状态（CPU/内存/磁盘）用 `top` / `free` / `df`
- 接口测试跑脚本用 Shell 比手工快100倍

<!-- more -->

## 2. 文件与目录操作

| 命令 | 用途 | 示例 |
|------|------|------|
| `ls -la` | 列出所有文件（含隐藏） | `ls -la /var/log/` |
| `cd` | 切换目录 | `cd /opt/game_server/logs` |
| `pwd` | 显示当前路径 | `pwd` |
| `mkdir -p` | 递归创建目录 | `mkdir -p test/reports/2026` |
| `cp -r` | 递归复制 | `cp -r config/ config_backup/` |
| `mv` | 移动/重命名 | `mv old_name.txt new_name.txt` |
| `rm -rf` | 递归强制删除 ⚠️ | `rm -rf /tmp/test_cache/` |
| `find` | 查找文件 | `find . -name "*.log" -mtime -1` |
| `touch` | 创建空文件 | `touch test.log` |

## 3. 查看文件内容（日志分析必备）

| 命令 | 用途 |
|------|------|
| `cat file.log` | 输出全部内容（小文件） |
| `less file.log` | 分页查看，可上下滚动 |
| `head -n 20 file.log` | 查看前20行 |
| `tail -f file.log` | 实时追踪日志（游戏服务器最常用！） |
| `tail -n 100 file.log` | 查看最后100行 |

## 4. 文本搜索（grep — 最重要的命令之一）

```bash
# 在日志中搜索错误
grep "ERROR" server.log

# 忽略大小写搜索
grep -i "error" server.log

# 显示匹配行的前后3行上下文
grep -C 3 "NullPointerException" game.log

# 递归搜索目录下所有文件
grep -r "player_id=10086" /var/log/game/

# 反向搜索（排除某些行）
grep -v "DEBUG" server.log | grep "ERROR"

# 统计匹配行数
grep -c "timeout" server.log
```

## 5. 进程与系统状态

```bash
top                    # 实时查看CPU/内存/进程（按q退出）
free -h                # 查看内存使用（人类可读）
df -h                  # 查看磁盘空间
du -sh /var/log/       # 统计目录大小
ps aux | grep nginx    # 查找特定进程
kill -9 <PID>          # 强制结束进程 ⚠️
```

## 6. 权限管理

```bash
chmod +x script.sh     # 给脚本添加可执行权限
chmod 755 file         # rwxr-xr-x
chown user:group file  # 修改文件所属
sudo command           # 以管理员身份执行
```

## 7. 文本处理三剑客（入门）

### grep — 搜索
```bash
grep "ERROR" server.log | wc -l   # 统计错误行数
```

### sed — 替换
```bash
sed 's/old_text/new_text/g' file.txt   # 全文替换
sed -i 's/DEBUG/INFO/g' config.ini     # 原地修改文件
```

### awk — 列处理
```bash
awk '{print $1, $3}' data.txt          # 打印第1列和第3列
awk -F',' '{print $2}' users.csv       # 以逗号为分隔符，打印第2列
```

## 8. 测试工作常用组合

```bash
# 1. 查看最近1小时的游戏错误日志
find /var/log/game/ -name "*.log" -mmin -60 | xargs grep "ERROR"

# 2. 统计各玩家ID的报错次数
grep "player_id" game.log | awk '{print $5}' | sort | uniq -c | sort -rn | head -10

# 3. 监控日志新内容，过滤关键信息
tail -f game.log | grep --line-buffered -E "ERROR|CRASH|timeout"

# 4. 批量重命名（把 .txt 改为 .log）
for f in *.txt; do mv "$f" "${f%.txt}.log"; done
```

## 9. Shell 脚本基础

```bash
#!/bin/bash
# 一个简单的测试环境启动脚本

SERVER_DIR="/opt/game_server"
LOG_FILE="/var/log/game/startup.log"

echo "===== $(date) =====" >> $LOG_FILE

# 检查进程是否已运行
if ps aux | grep -v grep | grep game_server > /dev/null; then
    echo "服务已在运行中" >> $LOG_FILE
else
    cd $SERVER_DIR && ./game_server &
    echo "服务已启动，PID: $!" >> $LOG_FILE
fi
```

---

> Linux 不是选修课，是测试工程师的必备技能。每天记一条命令，30天后就能熟练操作。
