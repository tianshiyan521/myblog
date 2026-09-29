---
title: 接口测试入门 - Python requests 实战
date: 2026-06-24
categories: 自动化测试
tags: [接口测试, Python, requests, 自动化测试, API]
---

接口测试是自动化测试里最容易上手、性价比最高的一类。相比 UI 自动化，接口测试更稳定、执行更快，适合作为回归测试的主力。

<!-- more -->

## 1. 环境准备

```bash
pip install requests pytest
```

## 2. 发送 GET 请求

```python
import requests

r = requests.get("https://httpbin.org/get", params={"page": 1})
print(r.status_code)
print(r.json())
```

## 3. 发送 POST 请求

```python
import requests

payload = {
    "username": "test",
    "password": "123456"
}
headers = {"Content-Type": "application/json"}

r = requests.post(
    "https://httpbin.org/post",
    json=payload,
    headers=headers
)
assert r.status_code == 200
```

## 4. 常用断言点

```python
def test_login():
    r = requests.post("https://httpbin.org/post", json={"user": "admin"})
    data = r.json()

    assert r.status_code == 200
    assert data["json"]["user"] == "admin"
    assert "application/json" in r.headers["Content-Type"]
```

## 5. 封装测试类

```python
import requests

class TestLogin:
    BASE_URL = "https://httpbin.org"

    def test_get(self):
        r = requests.get(f"{self.BASE_URL}/get")
        assert r.status_code == 200

    def test_post(self):
        r = requests.post(f"{self.BASE_URL}/post", json={"key": "value"})
        assert r.json()["json"]["key"] == "value"
```

## 6. 进阶方向

- 用 pytest fixture 管理 session 和 token
- 用 YAML/JSON 管理接口数据，实现数据驱动
- 用 Allure 生成可视化接口测试报告
- 结合 CI/CD，每次代码提交自动跑接口用例

> 接口测试是游戏测试、Web 测试都绕不开的环节，建议优先掌握。
