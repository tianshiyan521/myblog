---
title: MySQL 实战 · 第1章：CRUD 基础与查询入门
date: 2026-06-16 09:00:00
categories: 数据库
tags: [MySQL, SQL, CRUD, 数据库, 测试]
---

MySQL 是测试工程师的**分水岭技能**。会不会写 SQL，决定了你排查问题时是"等开发查"还是"自己上手定位"。

这个系列按 30 天的学习过程整理成章。

第 1 章从最基础的 CRUD 开始。

<!-- more -->

## 一、环境准备

```sql
-- 连接服务器
-- mysql -h localhost -P 3306 -u root -p

SHOW DATABASES;      -- 有哪些库
USE game_test;       -- 选库
SHOW TABLES;         -- 有哪些表
DESC player;         -- 看表结构
SELECT VERSION();    -- 版本
SELECT NOW();        -- 当前时间
```

**客户端工具推荐 DBeaver**（免费、支持多数据库、界面清爽）。

### ⚠️ 三条新手必踩的坑

1. **忘记分号** —— SQL 语句必须以 `;` 结尾
2. **root 密码忘了** —— 重置很麻烦，装完立刻存好
3. **⚠️ 生产环境严禁直接操作**（这条最重要，后面细说）

---

## 二、建表：先有个测试对象

```sql
CREATE TABLE IF NOT EXISTS player (
    id          INT PRIMARY KEY AUTO_INCREMENT,
    username    VARCHAR(50) NOT NULL UNIQUE,
    level       INT DEFAULT 1,
    gold        DECIMAL(10,2) DEFAULT 0.00,
    vip         BOOLEAN DEFAULT FALSE,
    created_at  DATETIME DEFAULT NOW()
);
```

**几个设计选择值得注意：**

| 字段 | 选择 | 原因 |
|------|------|------|
| `id` | `INT PRIMARY KEY AUTO_INCREMENT` | 自增主键，唯一标识 |
| `username` | `VARCHAR(50) NOT NULL UNIQUE` | **UNIQUE 保证不重名** |
| `level` | `INT DEFAULT 1` | 默认值，插入时可省 |
| `gold` | **`DECIMAL(10,2)`** | **⚠️ 金额绝不能用 FLOAT** |

> **为什么金额不能用 FLOAT？**
>
> FLOAT 是**二进制浮点数**，无法精确表示十进制小数。
> ```sql
> SELECT 0.1 + 0.2;     -- FLOAT 会得到 0.30000000000000004
> ```
> 游戏里的金币、充值金额用 FLOAT，**迟早出现对不上账的问题**。
>
> **正确选择**：
> - `DECIMAL(M,D)` — 精确小数（金额首选）
> - `BIGINT` — 存"分"为单位的整数（性能更好）
>
> **这是数据库设计里最经典的错误之一**，测试时看到金额字段是 FLOAT/DOUBLE，可以直接提。

---

## 三、INSERT：造数据

```sql
-- 写法 1：指定列名（推荐！）
INSERT INTO player (username, level, gold)
VALUES ('张三', 10, 500.00);

-- 写法 2：一次插入多行（效率高得多）
INSERT INTO player (username, level, gold, vip)
VALUES
    ('李四', 20, 1200.00, TRUE),
    ('王五', 5,  100.00,  FALSE),
    ('赵六', 35, 9999.99, TRUE);
```

### ⚠️ 为什么推荐"指定列名"的写法

```sql
-- ❌ 危险写法
INSERT INTO player VALUES (1, '张三', 10, 500.00, FALSE, NOW());

-- ✅ 安全写法
INSERT INTO player (username, level, gold) VALUES ('张三', 10, 500.00);
```

**原因**：第一种写法依赖**列的物理顺序**。将来表加了一列，这条 SQL 就全错位了——而且**报错可能不明显，数据会悄悄写错**。

**测试场景**：批量造数据时，这个差别特别明显。

```sql
-- 用 INSERT ... SELECT 批量复制数据
INSERT INTO player (username, level, gold)
SELECT CONCAT('test_', id), FLOOR(RAND()*50)+1, RAND()*1000
FROM player LIMIT 100;
```

> 💡 **造测试数据是测试人员用 MySQL 最高频的场景之一**，比查询还高频。
> 要测 100 级的角色？要测背包满？要测 30 天没登录的账号？**自己一条 SQL 搞定，不用等开发。**

---

## 四、SELECT：查询

```sql
SELECT * FROM player;                    -- 查全部列
SELECT username, level, gold FROM player; -- 查指定列
SELECT username AS 昵称, level FROM player; -- 起别名
```

### ⚠️ 别在生产环境用 `SELECT *`

两个原因：

1. **性能**：`SELECT *` 会返回所有列，包括不需要的大字段（如 TEXT）
2. **可读性**：看结果时不知道有哪些列，还得去对表结构

**测试环境无所谓，但养成写具体列名的习惯。**

---

## 五、UPDATE 与 DELETE：测试人员的高危操作

```sql
-- UPDATE
UPDATE player SET level = 60 WHERE id = 1;

-- DELETE
DELETE FROM player WHERE id = 1;
```

### ⚠️⚠️ 忘记 WHERE 的代价

```sql
UPDATE player SET gold = 0;      -- ⚠️ 全表玩家的金币清零
DELETE FROM player;              -- ⚠️ 删光整张表
```

**没有 WHERE 就是全表操作。** 这是数据库操作里最经典的灾难。

### 安全操作三步法

```sql
-- ① 先用 SELECT 确认范围
SELECT COUNT(*) FROM player WHERE level < 10;
SELECT id, username FROM player WHERE level < 10 LIMIT 10;

-- ② 确认影响的行数符合预期

-- ③ 再执行 DML
UPDATE player SET level = 10 WHERE level < 10;
```

**再加两条保险：**

- **加 `LIMIT` 限制影响行数**：`DELETE FROM player WHERE level < 10 LIMIT 100;`
- **生产环境操作前先备份**，或先在测试库演练

> **测试人员最常犯的错误，就是把测试环境的习惯带到生产环境。**
>
> 现实中的建议是：**能用测试库就别碰生产库**；非要在生产操作，一定先 `SELECT` 一遍确认范围。
>
> 另外，很多公司会给测试同学只读账号——**这是合理的权限设计，不是不信任你。**

---

## 六、测试人员的 MySQL 三件套

给测试同学的 MySQL 用法，90% 集中在三件事：

### ① 验证接口落库

```sql
-- 接口返回"领取成功，金币 1100"
SELECT gold FROM player WHERE id = 1001;
-- 数据库里是不是真的 1100？
```

**只信接口响应是自欺欺人** —— 接口返回成功但数据没落库，是最典型的"看着没问题其实是事故"。

### ② 构造测试数据

```sql
-- 把玩家改成 100 级，测高级玩法
UPDATE player SET level = 100, exp = 999999999 WHERE id = 1001;

-- 重置每日任务，重复测试
UPDATE user_daily_task SET progress = 0, status = 0
WHERE user_id = 1001 AND task_date = CURDATE();
```

### ③ 定位问题

```sql
-- 玩家反馈"道具没到账"
SELECT * FROM user_item
WHERE user_id = 1001 AND item_id = 8888
ORDER BY create_time DESC LIMIT 10;
```

- **没有记录** → 是没发下来（发奖逻辑问题）
- **有记录但状态异常** → 是状态流转问题

**一条查询就能把问题甩给正确的方向。**

---

## 七、小结

| 要点 | 内容 |
|------|------|
| **DDL** | CREATE TABLE，注意金额用 DECIMAL 不用 FLOAT |
| **INSERT** | 指定列名；`INSERT ... SELECT` 批量造数据 |
| **SELECT** | 别在生产用 `SELECT *` |
| **UPDATE/DELETE** | ⚠️ **没 WHERE 就是全表操作** |
| **安全三步** | 先 SELECT 确认 → 加 LIMIT → 再执行 |
| **测试三件套** | 验证落库 / 造数据 / 定位问题 |

> **本课要点**：金额不用 FLOAT｜INSERT 指定列名｜没 WHERE 是全表操作｜测试用 MySQL 就三件事
