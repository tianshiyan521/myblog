---
title: MySQL 第3章 - 高级篇 (函数·视图·索引)
date: 2026-06-12
categories: 数据库
tags: [MySQL, 索引, 视图, 函数, EXPLAIN, 性能优化]
---

## 1. 字符串函数

```sql
-- 拼接
SELECT CONCAT('玩家', username, ' 等级:', level);      -- 任一NULL则结果NULL
SELECT CONCAT_WS('-', '2026', '06', '12');            -- 带分隔符，跳过NULL

-- 截取（从1开始！不是0！）
SELECT SUBSTRING('Hello World', 1, 5);                 -- Hello
SELECT LEFT('13800138000', 3);                         -- 138
SELECT RIGHT('13800138000', 4);                        -- 8000

-- 替换
SELECT REPLACE('138-0013-8000', '-', '');              -- 去短横线

-- 去空格
SELECT TRIM('   张三   ');                              -- 张三

-- 长度：CHAR_LENGTH（字符数，推荐）vs LENGTH（字节数）
SELECT CHAR_LENGTH('Hello世界');                        -- 7
SELECT LENGTH('Hello世界');                             -- 11（5 + 3×2）
```

<!-- more -->

### 实战：玩家数据格式化与脱敏

```sql
SELECT 
    id,
    TRIM(nickname) AS clean_nickname,
    CONCAT(LEFT(phone, 3), '****', RIGHT(phone, 4)) AS masked_phone
FROM test_players;
```

### 测试场景：API返回 vs 数据库比对

```sql
-- API返回的字符串数据（可能有空格、千分位逗号、"NULL"字符串），清洗后与数据库比对
SELECT 
    a.id,
    CASE WHEN TRIM(a.player_name) = b.player_name THEN '一致' ELSE '不一致' END AS name_match,
    CASE 
        WHEN REPLACE(TRIM(a.damage), ',', '') = 'NULL' AND b.damage IS NULL THEN '一致(空值)'
        WHEN CAST(REPLACE(TRIM(a.damage), ',', '') AS SIGNED) = b.damage THEN '一致'
        ELSE '不一致'
    END AS damage_match
FROM api_result a LEFT JOIN db_record b ON a.id = b.id;
```

## 2. 数学函数

```sql
SELECT ROUND(3.14159, 2);    -- 3.14（四舍五入）
SELECT CEIL(3.1);            -- 4（向上取整）
SELECT FLOOR(3.9);           -- 3（向下取整）
SELECT TRUNCATE(3.149, 2);   -- 3.14（截断，不四舍五入）
SELECT ABS(-100);            -- 100（绝对值）
SELECT MOD(17, 5);           -- 2（取模/求余）
SELECT POW(2, 10);           -- 1024（2的10次方）
SELECT RAND();               -- 0~1随机数
```

> ⚠️ ROUND vs TRUNCATE：ROUND(3.149, 2) = 3.15（四舍五入），TRUNCATE(3.149, 2) = 3.14（截断）

## 3. 日期时间函数

```sql
SELECT NOW();                              -- 2026-06-12 14:30:00
SELECT CURDATE();                          -- 2026-06-12
SELECT DATE_FORMAT(NOW(), '%Y年%m月%d日');  -- 2026年06月12日

-- 日期加减
SELECT DATE_ADD(NOW(), INTERVAL 7 DAY);     -- 7天后
SELECT DATE_SUB(NOW(), INTERVAL 1 MONTH);   -- 1个月前

-- 日期差值
SELECT DATEDIFF('2026-06-12', '2026-06-01');       -- 11（只算日期差）
SELECT TIMESTAMPDIFF(HOUR, login_time, NOW());     -- 离线小时数
SELECT TIMESTAMPDIFF(MINUTE, start_time, end_time); -- 精确分钟差

-- 提取分量
SELECT YEAR(NOW()), MONTH(NOW()), DAY(NOW());
SELECT DAYOFWEEK(NOW());     -- 星期几（1=周日）
```

### 测试实战：活动时间边界校验

```sql
-- 验证活动是否在正确的时间窗口内生效
SELECT 
    activity_name,
    DATE_FORMAT(start_time, '%m月%d日 %H:%i') AS 开始时间,
    NOW() BETWEEN start_time AND end_time AS 活动中_当前
FROM activities;

-- 验证活动开启边界：开启前不应有参与记录
SELECT * FROM player_activity 
WHERE activity_id = 1 AND join_time < '2026-06-08 00:00:00';
-- 预期：返回0行
```

## 4. 视图 VIEW

视图 = 保存的 SELECT 语句，虚拟表。三大用途：
1. **简化复杂查询**：把多表 JOIN 封装成简单查询
2. **数据安全**：隐藏敏感字段，只暴露需要的数据
3. **逻辑抽象**：封装校验逻辑，重复使用

```sql
-- 创建视图
CREATE OR REPLACE VIEW v_player_summary AS
SELECT id, name, level, vip_level, gold, last_login
FROM players WHERE status = 1;

-- 使用视图（像普通表一样查）
SELECT * FROM v_player_summary WHERE level >= 50;

-- 测试实战：封装每日数据校验视图
CREATE OR REPLACE VIEW v_order_recharge_check AS
SELECT o.id, o.player_id, o.amount AS order_amount,
       IFNULL(SUM(r.recharge_amount), 0) AS recharge_total,
       CASE WHEN o.amount = IFNULL(SUM(r.recharge_amount), 0) THEN '一致' ELSE '不一致' END AS check_result
FROM orders o LEFT JOIN recharge_log r ON o.player_id = r.player_id
GROUP BY o.id;
-- 每天跑一句就出校验结果
SELECT * FROM v_order_recharge_check WHERE check_result != '一致';
```

## 5. 索引基础

### 三种索引

| 类型 | 允许NULL | 允许重复 | 每表个数 | 典型场景 |
|------|:--:|:--:|:--:|------|
| 主键索引 | ✗ | ✗ | 1个 | ID |
| 唯一索引 | ✓ | ✗ | 多个 | 手机号/邮箱 |
| 普通索引 | ✓ | ✓ | 多个 | 等级/状态 |

### EXPLAIN 查看执行计划

```sql
EXPLAIN SELECT * FROM players WHERE player_name = '张三';
```

| type 值 | 含义 | 评价 |
|---------|------|------|
| `const` | 主键/唯一索引精确匹配 | ⭐最快 |
| `ref` | 普通索引等值匹配 | ⭐很快 |
| `range` | 索引范围扫描 | ⭐较快 |
| `index` | 全索引扫描 | 一般 |
| `ALL` | **全表扫描** | ❌最慢，要优化！ |

### 测试人员的工作流

```
接口慢 → 看SQL → EXPLAIN → 发现type=ALL → 建议加索引 → 验证type从ALL变ref → 回归通过
```

### 索引注意事项

- 索引不是越多越好（占用存储、拖慢写入）
- 一张表索引别超过5-6个
- WHERE/JOIN/ORDER BY 的高频列优先加索引
- WHERE 条件用函数会导致索引失效：`WHERE YEAR(created_at)=2026` 应改为 `WHERE created_at >= '2026-01-01'`

---

> 索引是数据库的"目录"，EXPLAIN 是验证索引是否生效的唯一标准。
