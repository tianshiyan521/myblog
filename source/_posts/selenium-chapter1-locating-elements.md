---
title: Selenium 第1章 - 8种元素定位方式详解
date: 2026-06-12
categories: 自动化测试
tags: [Selenium, CSS选择器, XPath, WebDriver, 自动化测试]
---

## 1. Selenium 8种元素定位方式

在网页上操作任何东西之前，先要"找到"它：

<!-- more -->

| # | 方式 | 示例 | 评价 |
|---|------|------|------|
| 1 | **By.ID** | `driver.find_element(By.ID, "username")` | ⭐最常用、最稳定 |
| 2 | By.NAME | `driver.find_element(By.NAME, "q")` | ⭐⭐常用于表单 |
| 3 | By.CLASS_NAME | `driver.find_element(By.CLASS_NAME, "btn")` | ⭐注意可能多个 |
| 4 | By.TAG_NAME | `driver.find_element(By.TAG_NAME, "input")` | ⭐范围太大 |
| 5 | By.LINK_TEXT | `driver.find_element(By.LINK_TEXT, "登录")` | ⭐⭐精准匹配链接 |
| 6 | By.PARTIAL_LINK_TEXT | `driver.find_element(By.PARTIAL_LINK_TEXT, "登")` | ⭐部分匹配 |
| 7 | **By.CSS_SELECTOR** | `driver.find_element(By.CSS_SELECTOR, "#login .btn")` | ⭐⭐⭐最强大 |
| 8 | By.XPATH | `driver.find_element(By.XPATH, "//input[@id='username']")` | ⭐⭐万能但有坑 |

## 2. find_element vs find_elements

```python
# find_element  — 找第一个匹配的，找不到就报错
btn = driver.find_element(By.ID, "submit")

# find_elements — 找所有匹配的，返回列表，找不到返回空列表(不报错)
items = driver.find_elements(By.CLASS_NAME, "list-item")
for item in items:
    print(item.text)
```

## 3. 等待机制 — 为什么不能用 time.sleep

```python
# ❌ 笨等5秒，不管元素有没有出现都要等
time.sleep(5)

# ✅ 聪明地等，元素一出现就立刻继续，最多等X秒
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

wait = WebDriverWait(driver, 10)

# 等元素出现
element = wait.until(EC.presence_of_element_located((By.ID, "username")))

# 等元素可点击
button = wait.until(EC.element_to_be_clickable((By.ID, "submit")))

# 等元素可见
text = wait.until(EC.visibility_of_element_located((By.CLASS_NAME, "result")))
```

**常见等待条件**：
- `presence_of_element_located` — 元素出现在DOM中
- `visibility_of_element_located` — 元素可见（显示在页面上）
- `element_to_be_clickable` — 元素可点击
- `title_contains("xxx")` — 页面标题包含xxx
- `url_contains("xxx")` — URL包含xxx

## 4. 实战：用多种方式定位必应搜索框

```python
driver.get("https://www.bing.com")

# 方式1: By.ID
el1 = driver.find_element(By.ID, "sb_form_q")
# 方式2: By.NAME
el2 = driver.find_element(By.NAME, "q")
# 方式3: By.CSS_SELECTOR
el3 = driver.find_element(By.CSS_SELECTOR, "#sb_form_q")
# 方式4: By.XPATH
el4 = driver.find_element(By.XPATH, "//input[@id='sb_form_q']")

# 执行搜索
el1.send_keys("selenium python")
el1.send_keys(Keys.ENTER)
```

## 5. 本节要点

- **优先用 By.ID 和 By.CSS_SELECTOR**（快且稳定）
- XPath 是万能的但写起来麻烦，CSS选择器够用就行
- **永远用 WebDriverWait，不要 time.sleep**
- `find_element` 找不到会报错，`find_elements` 找不到返回空列表
