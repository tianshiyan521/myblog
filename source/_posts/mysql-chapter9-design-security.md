---
title: MySQL 实战 · 第6章：库表设计与安全测试
date: 2026-07-20 09:00:00
categories: 数据库
tags: [MySQL, 数据库设计, SQL注入, 安全测试, 建表]
---

**看懂数据库设计，是测试人员判断"这个功能会不会有 bug"的最有效手段之一。**

这篇讲两块：怎么设计一张合理的表（帮你看懂开发的设计），以及 SQL 注入怎么测（安全测试的基本功）。

<!-- more -->

## 一、表关系：三种基本形态

| 关系 | 实现方式 | 例子 |
|------|---------|------|
| **一对一** | 一方存另一方的主键（或共用主键） | 玩家 ↔ 玩家详情 |
| **一对多** | **"多"方存外键**，指向"一"方 | 用户 → 订单（一个用户多张订单） |
| **多对多** | **中间表**存两个外键 | 订单 ↔ 商品 |

### 一对多：多方存外键

```sql
CREATE TABLE orders (
    id      BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,                     -- 外键列
    FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE RESTRICT                       -- 有订单不能删用户
        ON UPDATE CASCADE                        -- 用户 ID 变了自动同步
);
```

### 多对多：中间表

```sql
CREATE TABLE order_items (
    id         BIGINT PRIMARY KEY AUTO_INCREMENT,
    order_id   BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    quantity   INT NOT NULL DEFAULT 1,
    unit_price DECIMAL(10,2) NOT NULL,           -- ★ 下单时价格（快照）
    FOREIGN KEY (order_id)   REFERENCES orders(id),
    FOREIGN KEY (product_id) REFERENCES products(id),
    UNIQUE KEY uk_order_product (order_id, product_id)   -- 同一订单不重复
);
```

### ★ 两个设计细节，测试时可以直接检查

**① `unit_price` 为什么要存"下单时的价格"？**

**因为商品价格会变。**

如果不存快照，只存 `product_id`，那么：

- 今天以 100 元买的
- 明天商品降价到 80 元
- 查历史订单时，金额显示成 **80 元** —— **账目全错了**

> **这是数据库设计里最容易被忽略、后果最严重的错误之一。**
> 凡是"历史记录"性质的金额（订单金额、流水金额），**必须存快照**，不能靠关联查当前值。
>
> **测试时看到订单表只存 `product_id` 不存价格，可以直接提疑问。**

**② `UNIQUE KEY uk_order_product` 的作用**

保证**同一订单里同一个商品只有一条记录**（要买 3 件就改 `quantity`，而不是插 3 行）。

**这是数据一致性的防线** —— 没有这个约束，并发插入可能产生重复行。

---

## 二、外键的级联操作

| 选项 | `ON DELETE` 含义 | `ON UPDATE` 含义 |
|------|-----------------|-----------------|
| **`CASCADE`** | 父行删了，**子行也删** | 父键改了，**子键跟着改** |
| **`SET NULL`** | 父行删了，**子键设 NULL** | 父键改了，子键设 NULL（子列须允许 NULL） |
| **`RESTRICT` / `NO ACTION`** | **阻止删除**（默认） | 阻止修改 |
| `SET DEFAULT` | 设为默认值（**MySQL 忽略此选项**） | 同上 |

### ⚠️ CASCADE 是双刃剑

```sql
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
```

**删一个用户，他的所有订单全被删掉。**

图方便，但**数据一删就没了**。生产环境里，用户数据通常只做"逻辑删除"（`status = 0`），不做物理删除——**正是因为级联删除太危险**。

> **测试时的检查点**：做"删除"相关功能时，确认**是物理删除还是逻辑删除**。
> 如果是物理删除 + CASCADE，要测清楚"删一个东西会连带删掉什么"，**这是最容易造成数据事故的路径**。

---

## 三、CHECK 约束（MySQL 8.0.16+ 才真正生效）

```sql
CREATE TABLE players (
    player_id INT PRIMARY KEY AUTO_INCREMENT,
    nickname  VARCHAR(50) NOT NULL,
    level     INT CHECK (level >= 1 AND level <= 100),   -- 等级范围
    hp        INT CHECK (hp > 0),                        -- 血量必须正数
    gender    ENUM('M','F','O') CHECK (gender IN ('M','F','O'))
);
```

> ⚠️ **版本差异**：**MySQL 8.0.16 之前，CHECK 写了也不检查**（只是语法上接受）。
> 老版本上做数据边界测试时，**不能指望 CHECK 帮你拦住非法值**，得靠应用层校验。

---

## 四、完整的建表脚本（可直接用）

```sql
CREATE DATABASE IF NOT EXISTS ecommerce
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ecommerce;

CREATE TABLE users (
  id            BIGINT PRIMARY KEY AUTO_INCREMENT,
  username      VARCHAR(50) NOT NULL UNIQUE COMMENT '用户名',
  password_hash CHAR(60) NOT NULL COMMENT '密码哈希(bcrypt)',
  nickname      VARCHAR(50) DEFAULT '' COMMENT '昵称',
  phone         CHAR(11) DEFAULT '' COMMENT '手机号',
  email         VARCHAR(100) DEFAULT '' COMMENT '邮箱',
  balance       DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '账户余额',
  status        TINYINT NOT NULL DEFAULT 1 COMMENT '1正常 0禁用',
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_phone (phone)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户表';

CREATE TABLE products (
  id          BIGINT PRIMARY KEY AUTO_INCREMENT,
  name        VARCHAR(200) NOT NULL COMMENT '商品名',
  price       DECIMAL(10,2) NOT NULL DEFAULT 0 COMMENT '售价',
  stock       INT NOT NULL DEFAULT 0 COMMENT '库存',
  status      TINYINT NOT NULL DEFAULT 1 COMMENT '1上架 0下架',
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商品表';
```

### 设计要点

| 要点 | 原因 |
|------|------|
| **`utf8mb4`** | **支持 emoji 和中文**（`utf8` 存不了 4 字节字符） |
| **`InnoDB`** | 支持事务、行锁、外键 |
| **`DECIMAL` 金额** | 精确，不用 FLOAT/DOUBLE |
| **`CHAR(60)` 密码哈希** | bcrypt 固定 60 字符 |
| **`created_at` / `updated_at`** | 审计必备；`ON UPDATE` 自动维护 |
| **`status` 逻辑删除** | 避免物理删除 |
| **`COMMENT`** | 字段自解释，减少沟通成本 |

> ⚠️ **`utf8mb4` 是重点**：MySQL 的 `utf8` 其实是 "utf8mb3"，**只支持 3 字节字符，存不了 emoji**。
> 玩家昵称带 emoji 时，插入会直接报错或截断。
>
> **测试昵称输入框时，emoji 是必测项** —— 这类 bug 在社交类游戏里很常见。

---

## 五、★ SQL 注入：测试人员怎么检测

### 原理

```sql
-- 应用层 SQL 是拼接出来的
SELECT * FROM users WHERE username = 'admin' AND password = '<用户输入>'

-- 用户输入：' OR '1'='1
-- 拼出来变成：
SELECT * FROM users WHERE username = 'admin' AND password = '' OR '1'='1'
--                                                          ↑ 永远为真
-- 结果：返回全部用户 → 绕过登录
```

### 常见 payload 类型

```sql
-- ① 永真注入（最常见）
' OR '1'='1
' OR 1=1 -- 
admin' --

-- ② 联合查询注入（查其他表数据）
' UNION SELECT username, password FROM users --

-- ③ 报错注入
' AND extractvalue(1, concat(0x7e, (SELECT database()), 0x7e))

-- ④ 布尔盲注（页面只有"成功/失败"两种状态）
' AND (SELECT SUBSTRING(database(),1,1))='s' --

-- ⑤ 时间盲注（连布尔状态都没有）
' OR IF(1=1, SLEEP(5), 0) --
-- 页面响应明显变慢 → 存在注入
```

### ★ 测试脚本：批量探测

```python
import requests

url = "http://test-api.local/player/search"

payloads = [
    "1' OR '1'='1",
    "1' UNION SELECT username, password FROM player--",
    "1' AND SLEEP(3)--",
]

for p in payloads:
    r = requests.get(url, params={"player_id": p})
    print(f"payload: {p!r:40s}  status: {r.status_code}  time: {r.elapsed.total_seconds():.2f}s")
    if "SQL" in r.text or "syntax" in r.text.lower():
        print("⚠️ 疑似 SQL 注入漏洞：响应中包含 SQL 错误信息")
```

**三种判断依据：**

| 现象 | 说明 |
|------|------|
| **响应时间 > 3s** | 时间盲注成功（`SLEEP` 生效了） |
| **返回数据异常**（多出字段、暴库信息） | 联合注入成功 |
| **状态码 500 + 暴露 SQL 错误** | 报错注入，且**错误信息泄露是独立的问题** |

> **最后一条要单独提一个 bug**：**错误信息直接返回给前端，本身就是信息安全问题**。
> 即使注入不成功，暴露了表名、字段名、SQL 语法也会帮攻击者缩小范围。
> **正确做法是统一返回"系统异常"，详细信息只记服务端日志。**

### ⚠️ 三个常见误区

**误区 1：转义等于防注入**

```sql
-- ❌ "我加了 addslashes 就安全了"
-- 真相：GBK 宽字节注入、整数型无引号、二次注入都能绕过
-- ✅ 正确：永远用参数化查询（PREPARE/EXECUTE 或 ORM）
```

**误区 2：数字型参数加引号就安全**

```python
# ❌ 看似安全其实没意义
sql = f"SELECT * FROM player WHERE id='{player_id}'"

# ✅ 数字型也用参数化
cur.execute("SELECT * FROM player WHERE id=%s", (player_id,))
```

**误区 3：应用账号用 root**

```sql
-- ✅ 应用账号只给必要权限
CREATE USER 'app_user'@'%' IDENTIFIED BY 'StrongPwd!2026';
GRANT SELECT, INSERT, UPDATE ON shop.* TO 'app_user'@'%';
-- 即使被注入，也无法 DROP TABLE / 读文件 / 提权
```

---

## 六、测试人员的数据库安全清单

| 检查项 | 怎么看 |
|--------|--------|
| **密码是否明文存储** | 查 `password` 字段，应该是哈希（如 bcrypt 的 60 字符） |
| **金额字段类型** | `DECIMAL` 还是 `FLOAT`？（FLOAT 会有精度问题） |
| **字符集是否 utf8mb4** | `utf8` 存不了 emoji |
| **敏感信息是否加密** | 手机号、身份证是否明文 |
| **错误信息是否外泄** | 接口报错是否返回 SQL 语句、堆栈 |
| **删除是物理还是逻辑** | 物理删除 + CASCADE 风险高 |
| **应用账号权限** | 是否用了 root |
| **关键字段有没有唯一约束** | 幂等、防重复依赖它 |

> **这份清单可以在做"数据库层面评审"时直接用。**
> 每一条都不需要你懂后端代码，**只要能看表结构和接口返回就能判断**。

---

## 七、小结

| 要点 | 内容 |
|------|------|
| **一对多** | 多方存外键 |
| **多对多** | 中间表存两个外键 + 唯一约束 |
| **金额快照** | ⚠️ 订单价格必须存快照，不能关联查当前值 |
| **CASCADE** | 双刃剑，物理删除风险高 |
| **utf8mb4** | `utf8` 存不了 emoji |
| **CHECK** | MySQL 8.0.16+ 才生效 |
| **SQL 注入** | 参数化查询是唯一正解；转义不够 |
| **错误外泄** | 独立的 bug，暴露表结构 |

> **本课要点**：金额要存快照｜utf8 存不了 emoji｜转义不等于防注入｜错误信息外泄是独立 bug
