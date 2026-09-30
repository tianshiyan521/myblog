---
title: JMeter 性能测试 · 参数化：让压测数据活起来
date: 2026-07-03 09:00:00
categories: 自动化测试
tags: [JMeter, 性能测试, 参数化, CSV, 数据驱动]
---

硬编码的压测有个致命问题：**所有虚拟用户发的是一模一样的请求。**

这会导致两个后果：

1. **测不出真实场景**。真实玩家不会全都查同一个页面、买同一件商品
2. **服务端的缓存会骗你**。第一个请求查完数据库，后面 999 个都命中缓存，测出来的"高性能"是假的

参数化解决的就是这个问题。

<!-- more -->

## 一、静态参数化：CSV Data Set Config

最核心、最常用的参数化方式。

### 基本配置

| 参数 | 说明 |
|------|------|
| Filename | CSV 文件路径（支持相对/绝对） |
| Variable Names | 列名映射，逗号分隔 |
| Delimiter | 分隔符 |
| File Encoding | 编码（中文一定要设 UTF-8） |
| Ignore First Line | 是否跳过标题行 |
| **Recycle on EOF** | 读完是否循环（`TRUE`=循环 / `FALSE`=停止） |
| **Stop Thread on EOF** | 读完后是否停线程（`TRUE`=停 / `FALSE`=继续，变量变 `<EOF>`） |
| **Sharing Mode** | 线程间共享方式 |

### ★ Sharing Mode 详解（最容易配错的地方）

| 模式 | 行为 | 适用场景 |
|------|------|----------|
| `all` | **所有线程共享同一迭代指针**，轮流读不同行 | **每个虚拟用户读不同数据** |
| `thread` | **每个线程独立迭代指针**，各自从头读 | 所有用户用同一组数据 |
| `currentGroup` | 当前线程组内共享 | 线程组隔离 |

**这个选择直接决定测试是否有意义：**

> ⚠️ **常见踩坑**：设了 `all` 但线程数 > CSV 行数 → 读完循环后又从头开始，导致数据重复。
>
> 如果业务上有唯一性要求（比如注册不同用户名），可能出现"用户名已存在"的失败，**而这失败其实是测试数据没准备好，不是系统问题**。

**配错的表现**：

- 想让每个用户用不同账号，结果用了 `thread` → **所有用户都在用第一行数据**，等于没参数化
- 想让所有用户循环用同一组数据，结果用了 `all` → 线程数超过行数后数据错乱

### 实战配置

```
CSV 文件: day5_param_pages.csv
page_id,page_title,expected_status
1,Post One,200
2,Post Two,200
3,Post Three,200
4,Post Four,200
5,Post Five,200
```

**引用方式：**

```
URL 路径：/posts/${page_id}          →  第 1 次循环请求 /posts/1
断言参数：${expected_status}         →  动态期望状态码
JSON 断言：${page_id}                →  动态期望字段值
```

> 💡 最后一条值得注意：**期望值也能参数化**。这样同一个采样器就能覆盖"不同输入 → 不同期望输出"的多种场景，不用为每个场景单独建采样器。

### 多列 CSV

```
username,password,email,role
admin,admin123,admin@test.com,administrator
testuser1,pass111,user1@test.com,normal
```

POST 请求体同时引用 4 列：

```json
{
  "title": "Post by ${username}(${role})",
  "body": "Email:${email} | Password:${password}",
  "userId": ${__Random(1,10,user_id)}
}
```

---

## 二、用户定义变量（全局 / 局部）

### 两级作用域

| 级别 | 位置 | 作用域 | 优先级 |
|------|------|--------|--------|
| **TestPlan 级** | 测试计划 → 用户定义变量 | **所有线程组共享** | 低（可被覆盖） |
| **线程组级** | 线程组内 → Arguments 元件 | **只在本线程组内可见** | 高（覆盖上级） |

**覆盖规则**：子级覆盖父级，但**不能跨线程组引用局部变量**。

### 实战变量

| 变量 | 值 | 级别 | 用途 |
|------|-----|------|------|
| `BASE_URL` | `jsonplaceholder.typicode.com` | TestPlan 级 | 统一域名 |
| `PROTOCOL` | `http` | TestPlan 级 | 统一协议 |
| `TEST_TAG` | `Day5-ParamTest` | TestPlan 级 | 测试标记 |
| `LOCAL_TAG` | `ThreadGroup2-Demo` | 线程组级 | 线程组 2 专用 |
| `RANDOM_POST_ID` | `${__Random(1,100,rand_post)}` | 线程组级 | 动态变量 |

### HTTP 请求默认值 vs 用户定义变量

这两个容易混，区别在于：

| | HTTP Request Defaults | 用户定义变量 |
|---|----------------------|-------------|
| **作用** | 填**采样器留空**的字段 | **主动替换** `${变量}` 引用 |
| **感觉** | "默认值" | "变量" |

**实践建议**：域名、协议、端口用 **HTTP Request Defaults**；业务数据用**用户定义变量**。

---

## 三、动态参数化：内置函数

**静态数据（CSV）+ 动态数据（函数）** 组合，才能构造出真实、唯一、可追溯的请求。

### 常用函数速查

| 函数 | 语法 | 返回值 | 用途 |
|------|------|--------|------|
| `__Random` | `${__Random(min,max,var)}` | min~max 随机整数 | 随机 ID、随机字段 |
| `__counter` | `${__counter(TRUE,var)}` | 递增计数器 | 迭代编号、UA 标记 |
| `__threadNum` | `${__threadNum()}` | 当前线程号（1,2,...） | 区分不同线程的请求 |
| `__time` | `${__time(format,var)}` | 时间戳 | 请求 ID、日志标记 |
| `__UUID` | `${__UUID()}` | UUID 字符串 | 唯一标识符 |

### `__counter` 的参数很关键

| 参数 | 含义 |
|------|------|
| `TRUE`（per-thread） | **每个线程独立计数**：线程 1 是 1,2,3...；线程 2 也是 1,2,3... |
| `FALSE`（global） | **全局共享计数**：所有线程共用 1,2,3,4,5,6... |

> **选择标准**：要"每个用户的第几次操作"用 `TRUE`；要"全局唯一序号"用 `FALSE`。

### `__time` 格式参数

| 格式 | 示例 |
|------|------|
| 空或 `time` | `1783041196150`（Unix 毫秒时间戳） |
| `YMDHMS` | `20260703091316` |
| `YMD` | `20260703` |
| `HMS` | `091316` |

### ★ 组合案例：4 个函数拼出唯一请求体

```json
{
  "title": "${TEST_TAG}-Thread${__threadNum()}-Iter${__counter(TRUE,iter_cnt)}",
  "body": "Auto test at ${__time(YMDHMS,ts)} - randomId=${__Random(1,50,body_rand)}",
  "userId": ${__threadNum()}
}
```

**每个请求的 body 都独一无二：**

- 线程 1 第 1 次：`Day5-ParamTest-Thread1-Iter1 / 20260703091316-3247 / userId=1`
- 线程 2 第 2 次：`Day5-ParamTest-Thread2-Iter2 / 20260703091322-8751 / userId=2`

**请求头也用函数：**

```
X-Request-Id: ${__time(YMDHMS,)}-${__Random(1000,9999,req_rand)}
User-Agent: JMeter-Day5-Param/${__counter(FALSE,)}
```

> 💡 **为什么要给每个请求打唯一标记？**
>
> 当压测出现异常请求时，你可以**用这个标记去服务端日志里精确捞出对应记录**。
> 没有唯一标记的话，你只知道"有请求失败了"，但无法定位是哪一次、什么参数。
>
> **这是"可观测性"在压测里的体现** —— 好的压测不只是"发出去了"，还得能"查得回来"。

---

## 四、实测结果

| 指标 | 值 |
|------|-----|
| 总样本数 | 44 |
| 错误率 | 0.00% |
| 吞吐量 | 7.3/s |

---

## 五、小结

| 要点 | 内容 |
|------|------|
| **静态参数化** | CSV Data Set Config |
| **Sharing Mode** | `all`=各用户不同数据 / `thread`=各用户相同数据 |
| **Recycle / Stop on EOF** | 决定数据读完后的行为，配错会导致数据重复 |
| **两级变量** | TestPlan 级全局、线程组级局部（覆盖上级） |
| **动态函数** | Random / counter / threadNum / time / UUID |
| **组合价值** | 静态 + 动态 = 真实、唯一、可追溯的请求 |

> **本课要点**：硬编码的压测是假的｜Sharing Mode 决定测试有没有意义｜给每个请求打唯一标记
