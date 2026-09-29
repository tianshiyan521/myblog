---
title: pytest 入门 - 测试框架与常用断言
date: 2026-06-24
categories: 自动化测试
tags: [pytest, Python, 自动化测试, 测试框架]
---

pytest 是 Python 生态里最受欢迎的测试框架之一，语法简洁、插件丰富，适合写单元测试、接口测试和 UI 自动化测试。

<!-- more -->

## 1. 安装

```bash
pip install pytest pytest-html
```

## 2. 第一个测试用例

文件名必须以 `test_` 开头，函数名也必须以 `test_` 开头。

```python
def add(x, y):
    return x + y

def test_add():
    assert add(1, 2) == 3
```

运行：

```bash
pytest test_demo.py -v
```

## 3. 常用断言

| 写法 | 说明 |
|------|------|
| `assert a == b` | 等于 |
| `assert a in b` | 包含 |
| `assert a > b` | 大于 |
| `assert not condition` | 否定 |

## 4. 参数化测试

同一套逻辑用多组数据跑：

```python
import pytest

@pytest.mark.parametrize("a,b,expected", [
    (1, 2, 3),
    (10, 20, 30),
    (-1, 1, 0),
])
def test_add_param(a, b, expected):
    assert a + b == expected
```

## 5. 生成 HTML 报告

```bash
pytest --html=report.html --self-contained-html
```

## 6. 小技巧

- 用 `conftest.py` 写公共 fixture
- 用 `-k` 按名称过滤用例：`pytest -k "login"`
- 失败用例重跑可装插件：`pytest-rerunfailures`

> 学会 pytest 后，写 Selenium、Airtest、接口测试都会顺手很多。
