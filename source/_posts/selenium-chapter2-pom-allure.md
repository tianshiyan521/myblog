---
title: Selenium 第2章 - Page Object Model 与 Allure 报告
date: 2026-06-12
categories: 自动化测试
tags: [POM, Allure, pytest, Selenium, 自动化测试]
---

## 1. 什么是 Page Object Model（POM）

POM 的核心思想：**每个页面封装成一个类，页面上的元素和操作都定义在类里**。好处是：
- 代码复用：一处修改，所有用到的地方自动更新
- 可读性强：测试代码读起来像自然语言
- 维护成本低：页面改版只改对应的 Page 类

<!-- more -->

## 2. POM 实战 — Bing 搜索页

```python
# pages/bing_page.py
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.keys import Keys

class BingPage:
    def __init__(self, driver):
        self.driver = driver
        self.wait = WebDriverWait(driver, 10)

    # 元素定位（统一管理，改一个地方就行）
    SEARCH_BOX = (By.ID, "sb_form_q")
    SEARCH_BUTTON = (By.ID, "sb_form_go")
    RESULT_TITLES = (By.CSS_SELECTOR, "h2 a")

    def open(self):
        self.driver.get("https://www.bing.com")
        return self

    def search(self, keyword):
        search_box = self.wait.until(EC.presence_of_element_located(self.SEARCH_BOX))
        search_box.clear()
        search_box.send_keys(keyword + Keys.RETURN)
        return self

    def get_search_count(self):
        results = self.driver.find_elements(*self.RESULT_TITLES)
        return len([r for r in results if r.text.strip()])
```

## 3. conftest.py — driver fixture

```python
# conftest.py
import pytest
from selenium import webdriver

@pytest.fixture(scope="function")
def driver():
    options = webdriver.EdgeOptions()
    options.add_experimental_option("excludeSwitches", ["enable-automation"])
    drv = webdriver.Edge(options=options)
    drv.maximize_window()
    yield drv
    drv.quit()
```

## 4. Allure 报告集成

```python
import allure

@allure.feature("Bing搜索")
class TestBingSearch:
    @allure.story("基础搜索")
    @allure.severity(allure.severity_level.CRITICAL)
    @allure.title("搜索Python能返回结果")
    def test_search_python(self, driver):
        page = BingPage(driver)
        with allure.step("打开Bing首页"):
            page.open()
        with allure.step("搜索Python"):
            page.search("Python")
        with allure.step("验证搜索结果"):
            count = page.get_search_count()
            assert count > 0, "搜索结果为空!"
            allure.attach(driver.get_screenshot_as_png(), "截图", allure.attachment_type.PNG)
```

## 5. Allure 使用要点

⚠️ **不能直接打开 `index.html`**，必须用：
```bash
allure serve ./allure-results   # 一键启动本地服务器
```

### 常用装饰器

| 装饰器 | 作用 |
|--------|------|
| `@allure.feature` | 大功能分类 |
| `@allure.story` | 子功能 |
| `@allure.severity` | 严重等级（blocker/critical/normal/minor/trivial） |
| `@allure.step` | 测试步骤 |
| `@allure.title` | 用例标题 |
| `allure.attach()` | 附加截图/日志 |

### 失败自动截图 hook

```python
# conftest.py
@pytest.hookimpl(tryfirst=True, hookwrapper=True)
def pytest_runtest_makereport(item, call):
    outcome = yield
    report = outcome.get_result()
    if report.when == "call" and report.failed:
        driver = item.funcargs.get("driver")
        if driver:
            allure.attach(driver.get_screenshot_as_png(), "失败截图", allure.attachment_type.PNG)
```

## 6. 一键运行脚本

```batch
@echo off
echo 清理旧报告...
rmdir /s /q allure-results
echo 运行测试...
pytest --alluredir=allure-results
echo 生成并打开报告...
allure serve allure-results
```

---

> Selenium 工具链总结：pytest 组织用例 → POM 管理页面 → Allure 生成报告 → Jenkins/GitHub Actions 跑 CI
