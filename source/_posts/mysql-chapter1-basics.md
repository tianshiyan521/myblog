---
title: MySQL 第1章 - 基础篇 (安装·建表·CRUD·条件排序)
date: 2026-06-12
categories: 数据库
tags: [MySQL, CRUD, SQL, WHERE, 数据库]
---

## 1. MySQL 是什么

MySQL 是全球最流行的开源关系型数据库。游戏玩家数据、装备数据、战斗记录，大概率就存在 MySQL 里。

**作为测试人员，学会 MySQL 意味着**：
- 能直接查数据库验证接口返回的数据是否正确
- 能自己构造测试数据，不依赖开发给账号
- 能看懂慢查询日志，发现性能问题

<!-- more -->

## 2. 环境速建

```sql
-- 连接数据库
mysql -h localhost -P 3306 -u root -p

-- 查看所有数据库
SHOW DATABASES;

-- 创建数据库（指定字符集防乱码）
CREATE DATABASE game_test
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 进入数据库
USE game_test;
SELECT DATABASE();  -- 确认进对库
```

## 3. 常用数据类型速查

| 类型 | 用法 | 说明 | 常用度 |
|------|------|------|:--:|
| INT | `INT` | 整数，约±21亿 | ⭐⭐⭐⭐⭐ |
| VARCHAR(n) | `VARCHAR(50)` | 变长字符串 | ⭐⭐⭐⭐⭐ |
| TEXT | `TEXT` | 长文本，不能设默认值 | ⭐⭐⭐ |
| DECIMAL(m,d) | `DECIMAL(10,2)` | 精确小数，金额专用 | ⭐⭐⭐⭐ |
| DATETIME | `DATETIME` | 日期+时间 | ⭐⭐⭐⭐⭐ |
| BOOLEAN | `BOOLEAN` | 0/1真假 | ⭐⭐⭐ |

> 💡 金币/金额用 DECIMAL 不用 FLOAT！FLOAT 有精度误差。

## 4. 建表

```sql
CREATE TABLE player (
    id          INT PRIMARY KEY AUTO_INCREMENT COMMENT '玩家ID',
    username    VARCHAR(50) NOT NULL UNIQUE COMMENT '用户名',
    level       INT DEFAULT 1 COMMENT '等级',
    gold        DECIMAL(10,2) DEFAULT 0.00 COMMENT '金币',
    email       VARCHAR(100) COMMENT '邮箱',
    vip         BOOLEAN DEFAULT FALSE COMMENT '是否VIP',
    created_at  DATETIME DEFAULT NOW() COMMENT '创建时间'
) COMMENT '玩家信息表';
```

## 5. CRUD 四大操作

### INSERT — 插入数据
```sql
-- 指定列名插入（推荐！表加字段也不会崩）
INSERT INTO player (username, level, gold) VALUES ('张三', 10, 500.00);

-- 批量插入
INSERT INTO player (username, level, gold, vip) VALUES
    ('李四', 20, 1200.00, TRUE),
    ('王五', 5,  100.00,  FALSE);
```

### SELECT — 查询数据
```sql
-- 查全部
SELECT * FROM player;

-- 查指定列 + 别名
SELECT username AS 用户名, level AS 等级, gold AS 金币 FROM player;

-- 去重
SELECT DISTINCT vip FROM player;
```

### UPDATE — 修改数据（⚠️ 必须有 WHERE！）
```sql
-- 修改单行
UPDATE player SET level = 15 WHERE username = '张三';

-- 充值：用加法，不是赋值！
UPDATE player SET gold = gold + 1000 WHERE username = '张三';
-- ❌ 错误写法：UPDATE player SET gold = 1000;  -- 所有人金币变成1000！
```

### DELETE — 删除数据（⚠️ 必须有 WHERE！）
```sql
DELETE FROM player WHERE username = 'test_user_001';

-- 清空全表（保留结构，不可回滚）
TRUNCATE TABLE player;
```

## 6. WHERE 条件过滤

```sql
-- 比较运算符：=  <>  >  <  >=  <=
SELECT * FROM player WHERE level >= 80;

-- 范围：BETWEEN（闭区间，包含两端）
SELECT * FROM player WHERE vip_level BETWEEN 4 AND 7;

-- 集合：IN / NOT IN
SELECT * FROM player WHERE vip_level IN (2, 6, 8);

-- 模糊匹配：LIKE（%任意长度，_单个字符）
SELECT * FROM player WHERE username LIKE '%龙%';
SELECT * FROM player WHERE username LIKE '黄_';  -- 两个字，黄开头

-- 逻辑组合：AND / OR / NOT
SELECT * FROM player WHERE level > 70 AND gold > 20000;

-- NULL判断：IS NULL / IS NOT NULL
SELECT * FROM player WHERE register_time IS NULL;
```

## 7. ORDER BY + LIMIT 排序分页

```sql
-- 按金币降序，取前3名
SELECT username, level, gold FROM player
ORDER BY gold DESC LIMIT 3;

-- 分页公式：LIMIT (页码-1)×每页条数, 每页条数
-- 第1页（每页3条）：LIMIT 0, 3
-- 第2页：LIMIT 3, 3

-- 多列排序：先按等级降序，等级相同按金币降序
SELECT * FROM player ORDER BY level DESC, gold DESC;
```

## 8. 测试工作流：查-改-查验证

```sql
-- Step1：记录修改前的值
SELECT id, username, level, gold FROM player WHERE id = 1;

-- Step2：调用修改接口（让接口去改数据库）
-- Step3：用SQL验证接口改对了没有
SELECT id, username, level, gold FROM player WHERE id = 1;
-- 对比前后差异 = 你的测试断言
```

---

> CRUD 是所有数据库操作的基石，测试人员的日常就是用这四招验数据对不对。
