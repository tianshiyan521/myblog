---
title: Selenium - Web 自动化测试
date: 2026-06-12 10:00:00
categories: 自动化测试
tags: [Selenium, Python, POM, Web自动化, Allure]
---

Selenium 是 Web 端自动化测试的事实标准，支持 Python / Java / JS 等多语言。

本专栏以 Python + Selenium 为主线，从零搭到能跑的实际项目。

<!-- more -->

## 学习路径

```
环境搭建 → 元素定位 → 等待机制 → POM 分层 → 数据驱动 → 报告输出 → CI 集成
```

每一步都是为了解决前一步暴露的问题：

| 阶段 | 解决的问题 |
|------|-----------|
| 元素定位 | 怎么找到页面上的按钮 |
| 等待机制 | 页面没加载完就点，报错了 |
| POM 分层 | 页面一改，几十个脚本全要改 |
| 数据驱动 | 用例数据写死在代码里，加用例要改代码 |
| 报告输出 | 跑完了，怎么知道哪条挂了 |
| CI 集成 | 每次发版都要手动跑一遍 |

---

## 核心内容

### ① 环境速建

```bash
pip install selenium webdriver-manager
```

```python
from selenium import webdriver
from selenium.webdriver.edge.service import Service
from webdriver_manager.microsoft import EdgeChromiumDriverManager

service = Service(EdgeChromiumDriverManager().install())
driver = webdriver.Edge(service=service)
driver.get("https://example.com")
```

> ⚠️ 实测踩过的坑：用 `webdriver-manager` 自动下载的驱动版本可能和你本机浏览器**不完全匹配**。如果报 `session not created`，直接去官网下对应版本，手动指定路径：
> ```python
> service = Service(executable_path="C:/path/to/msedgedriver.exe")
> ```

### ② 元素定位八种方式

| 方式 | 示例 |
|------|------|
| id | `find_element(By.ID, "login")` |
| name | `find_element(By.NAME, "user")` |
| class | `find_element(By.CLASS_NAME, "btn")` |
| tag | `find_element(By.TAG_NAME, "input")` |
| link text | `find_element(By.LINK_TEXT, "登录")` |
| partial link | `find_element(By.PARTIAL_LINK_TEXT, "登")` |
| xpath | `find_element(By.XPATH, "//div[@id='login']")` |
| css selector | `find_element(By.CSS_SELECTOR, "#login")` |

**优先级建议**：id > name > css > xpath。xpath 最灵活也最脆弱，页面结构一调就断。

### ③ 等待机制（最容易出问题的地方）

```python
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

# ✅ 显式等待：等条件满足，最多 10 秒
WebDriverWait(driver, 10).until(
    EC.element_to_be_clickable((By.ID, "submit"))
).click()
```

**⚠️ 千万别用 `time.sleep()`**。写死 3 秒，网络快的时候白等，慢的时候还是挂。显式等待是**等条件**，不是等时间。

### ④ Page Object Model

把页面元素和操作封装成类，用例只调方法：

```python
class LoginPage:
    def __init__(self, driver):
        self.driver = driver
        self.username = (By.ID, "username")
        self.password = (By.ID, "password")
        self.submit = (By.ID, "submit")

    def login(self, user, pwd):
        self.driver.find_element(*self.username).send_keys(user)
        self.driver.find_element(*self.password).send_keys(pwd)
        self.driver.find_element(*self.submit).click()
```

**收益**：页面改版时只改 POM 类，用例脚本完全不用动。

### ⑤ 报告输出

```bash
pytest --alluredir=./results
allure serve ./results
```

Allure 报告能看到每条用例的步骤、截图、耗时，**给非技术同事看比控制台输出友好得多**。

---

## 三个实战经验

**① 定位不到元素时，先截图**

```python
driver.save_screenshot("debug.png")
```

九成情况是页面没加载完、进了 iframe、或者弹窗挡住了。**截图比猜快。**

**② iframe 是定位失败的常见原因**

```python
driver.switch_to.frame("iframe_id")
# ... 操作 iframe 内元素
driver.switch_to.default_content()   # 记得切回来
```

**③ 无头模式提速，但调试时要关掉**

```python
options = webdriver.EdgeOptions()
options.add_argument("--headless")   # CI 里开，本地调试点时关
```

---

> 适合人群：想系统入门 Web 自动化的测试新人。逻辑清晰、案例实用。
