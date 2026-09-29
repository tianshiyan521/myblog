---
title: Git 常用命令速查 - 测试工程师版
date: 2026-06-24
categories: 工具与运维
tags: [Git, 命令, 版本控制, 工具]
---

作为测试工程师，经常要拉取代码、切换分支、提交自动化脚本。把最常用的 Git 命令整理成一份速查表，方便随时翻阅。

<!-- more -->

## 1. 仓库初始化与克隆

```bash
git clone https://github.com/username/repo.git
cd repo
git init
```

## 2. 日常提交

```bash
git status                  # 查看修改状态
git add .                   # 添加所有改动
git commit -m "fix: 修复登录脚本断言"  # 提交
git push origin main        # 推送到远程
```

## 3. 分支操作

```bash
git branch                  # 查看本地分支
git branch -a               # 查看所有分支
git checkout -b feature/login-test   # 新建并切换分支
git merge feature/login-test         # 合并分支
git branch -d feature/login-test     # 删除本地分支
```

## 4. 撤销与回退

```bash
git checkout -- file.py     # 撤销单个文件改动
git reset HEAD file.py      # 取消暂存
git reset --hard HEAD~1     # 回退到上一个提交（慎用）
```

## 5. 查看历史

```bash
git log --oneline           # 简洁提交历史
git log --graph --decorate  # 图形化分支历史
```

## 6. 常用组合

| 场景 | 命令 |
|------|------|
| 拉取最新代码 | `git pull origin main` |
| 暂存当前改动 | `git stash` / `git stash pop` |
| 查看差异 | `git diff` |
| 打标签 | `git tag -a v1.0 -m "自动化框架 v1.0"` |

> 建议配合 `.gitignore` 忽略日志、报告、截图等临时文件，保持仓库干净。
