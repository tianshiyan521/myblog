---
title: 接口测试入门 - Python requests 实战
date: 2026-09-22 09:00:00
categories: 自动化测试
tags: [接口测试, Python, requests, 自动化测试, API]
---

接口测试是自动化测试里**最容易上手、性价比最高**的一类。相比 UI 自动化，它更稳定、执行更快，是回归测试的主力。

这个栏目分两条线：**基础用法**（这篇）和**实战系列**（4 篇完整项目）。

<!-- more -->

## 一、环境准备

```bash
pip install requests pytest
```

## 二、发送请求

```python
import requests

# GET
r = requests.get("https://httpbin.org/get", params={"page": 1})
print(r.status_code, r.json())

# POST（JSON）
payload = {"username": "test", "password": "123456"}
headers = {"Content-Type": "application/json"}
r = requests.post("https://httpbin.org/post", json=payload, headers=headers)
```

## 三、★ 断言：接口测试的灵魂

```python
def test_login():
    r = requests.post("https://httpbin.org/post", json={"user": "admin"})
    data = r.json()

    # 协议层
    assert r.status_code == 200
    # 业务层
    assert data["json"]["user"] == "admin"
    # 数据层
    assert "application/json" in r.headers["Content-Type"]
```

> ⚠️ **只写 `assert r.status_code == 200` 等于没测。**
>
> 很多游戏网关的 HTTP 状态码永远是 200，**真实成败在响应体的 `code` 里**。
> 详细的分层校验见实战系列的**第 1 课**。

## 四、封装测试类

```python
class TestLogin:
    BASE_URL = "https://httpbin.org"

    def test_get(self):
        r = requests.get(f"{self.BASE_URL}/get")
        assert r.status_code == 200

    def test_post(self):
        r = requests.post(f"{self.BASE_URL}/post", json={"key": "value"})
        assert r.json()["json"]["key"] == "value"
```

## 五、进阶方向

- 用 pytest fixture 管理 session 和 token
- 用 YAML/JSON 管理接口数据，实现**数据驱动**
- 用 Allure 生成可视化报告
- 结合 CI/CD，每次代码提交自动跑接口用例

---

## ★ 实战系列（推荐先看这个）

基础语法半小时就能会。**真正的门槛在"用例怎么设计"和"接口拿不到怎么办"。**

| 篇目 | 内容 |
|------|------|
| **学习地图** | 能力模型诊断：为什么"会写脚本"不等于"会设计用例" |
| **第 1 课** | 先跑起来别管理论：**HTTP 200 ≠ 通过**、五大维度、幂等性 |
| **第 2 课** | 把手动点的事交给脚本：四块骨架、**用例隔离**、断言设计 |
| **第 3 课** | **从客户端日志逆推私有协议**：protobuf、0x0A 陷阱、**499 不是限流** |

### 第 3 课特别推荐

它讲了一个真实的极端场景：

- **没有接口文档**
- **不知道接口地址**（客户端是 C# 外壳，前端代码里找不到）
- **不会抓包**（不想装 Charles/Fiddler 和证书）
- 协议是**二进制**的

全程没用抓包工具，最后做出了 **36 条用例、35 通过**的自动化测试。

里面有三个别人很少写的坑：

1. **客户端日志比抓包更省事**（不用装工具、不用配代理、不用装证书，而且是历史累积的）
2. **日志会吃掉 body 开头的 `0x0A`**（protobuf 字段 1 的标签恰好是换行符），照抄日志会得到 `code=38`
3. **499 不是限流**，是协议层的确定性响应 —— **不要写进重试逻辑**

---

> **接口测试是游戏测试、Web 测试都绕不开的环节，建议优先掌握。**
