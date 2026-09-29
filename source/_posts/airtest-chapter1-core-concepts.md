---
title: Airtest 第1章 - 核心概念与恐龙岛实战
date: 2026-06-12
categories: 自动化测试
tags: [Airtest, 游戏测试, 恐龙岛, 自动化]
---

## 1. Airtest 是什么

Airtest 是网易开源的跨平台 UI 自动化测试框架，主要面向**手机游戏和 App** 的自动化测试。它最大的特点是**图像识别 + UI 控件操作**两种模式双管齐下。

安装版本：airtest 1.4.3 + pocoui 1.0.94

<!-- more -->

## 2. Airtest vs Selenium 操作对比

| 操作 | Selenium 写法 | Airtest 写法 |
|------|--------------|-------------|
| 打开网页/App | `driver.get("url")` | `start_app("包名")` |
| 点击元素 | `element.click()` | `touch(Template("截图"))` |
| 输入文字 | `send_keys("xx")` | `text("要输入的文字")` |
| 等待元素 | `WebDriverWait` | `wait(Template("截图"))` |
| 断言验证 | `assert "xx" in title` | `assert_exists(Template())` |
| 滑动屏幕 | `ActionChains(复杂)` | `swipe(起点, 终点)` |
| 截图保存 | `save_screenshot("f.png")` | `snapshot("f.png")` |

## 3. 适用场景

- **Selenium 适合**：Web 网页测试、精确操作 DOM 元素、接口+UI 联合测试
- **Airtest 适合**：游戏测试（Unity/Cocos/UE引擎）、手机 App 测试、截图定位无需代码定位、跨平台（Android/iOS/Windows/Web）

## 4. 恐龙岛项目实战 — 自动挂机测试

```python
from airtest.core.api import *
from poco.drivers.unityengine import UnityPoco

# 1. 连接设备
connect_device("Android:///")

# 2. 启动游戏
start_app("com.dinosaur.game")
sleep(5)

# 3. Poco 读取游戏 UI 控件
poco = UnityPoco()

# 进入自动培养池
poco("Btn_CultivatePool").click()
sleep(2)
assert_exists(Template("cultivate_pool.png"), "培养池界面")

# 选择恐龙
poco(text="霸王龙").click()
poco("Btn_StartCultivate").click()
sleep(1)

# 验证培养状态
status = poco("Text_Status").get_text()
print(f"培养状态: {status}")
assert "培养中" in status, "培养未开始!"

# 截图保存
snapshot("cultivate_pool_test.png")

# 退出
stop_app("com.dinosaur.game")
```

## 5. 学习路线

1. **下载 AirtestIDE**（可视化编辑器，边操作边录脚本，新手首选）
2. 学会图像识别操作：`touch` / `wait` / `assert_exists` / `snapshot`
3. 学会 Poco 控件操作：`poco("控件名").click()` / `poco(text="文字").get_text()`
4. 数据驱动 + pytest 集成：从 Excel 读测试数据，批量执行
5. CI/CD 集成：Jenkins/GitLab CI 自动跑脚本

---

> 工具地址：https://airtest.netease.com/
