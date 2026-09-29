---
title: MySQL 第2章 - 进阶篇 (聚合·JOIN·子查询·UNION)
date: 2026-06-12
categories: 数据库
tags: [MySQL, JOIN, 子查询, GROUP BY, UNION, SQL]
---

## 1. 五大聚合函数

```sql
SELECT COUNT(*) FROM players;              -- 统计行数（含NULL）
SELECT SUM(gold) FROM players;             -- 所有金币总和
SELECT AVG(level) FROM players;            -- 平均等级
SELECT MAX(level), MIN(level) FROM players; -- 最高/最低等级
SELECT COUNT(DISTINCT server_id) FROM players; -- 去重统计
```

<!-- more -->

## 2. GROUP BY 分组 + HAVING 筛选

### SQL 执行顺序（重要！）
```
书写顺序：SELECT → FROM → WHERE → GROUP BY → HAVING → ORDER BY → LIMIT
执行顺序：FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT
```

**口诀**：先找表(FROM) → 再筛行(WHERE) → 然后分组(GROUP BY) → 再筛组(HAVING) → 选列(SELECT) → 排序(ORDER BY) → 截取(LIMIT)

### WHERE vs HAVING

| 对比项 | WHERE | HAVING |
|--------|-------|--------|
| 作用时机 | 分组**前**筛选行 | 分组**后**筛选组 |
| 能否用聚合函数 | ❌ 不能 | ✅ 可以 |

### 实战：各服务器统计

```sql
SELECT
    server_id,
    COUNT(*) AS player_count,
    ROUND(AVG(level), 1) AS avg_level,
    SUM(gold) AS total_gold
FROM players
WHERE status = 'active'
GROUP BY server_id
HAVING player_count > 100       -- 只看玩家数超100的服务器
ORDER BY player_count DESC;
```

### 测试场景：充值数据验证

```sql
-- 按日期统计充值总额和人数
SELECT
    recharge_date,
    COUNT(*) AS recharge_count,
    COUNT(DISTINCT player_id) AS unique_payers,
    SUM(amount) AS total_amount
FROM recharge_records
GROUP BY recharge_date
ORDER BY recharge_date;

-- 找出单日充值超过10000的高峰日
SELECT recharge_date, SUM(amount) AS daily_total
FROM recharge_records
GROUP BY recharge_date
HAVING daily_total > 10000;
```

## 3. 多表关联 JOIN

### 四种 JOIN 速记

```
INNER JOIN：  A ∩ B        — 只取交集
LEFT JOIN：   A + (A ∩ B)  — A全要，B匹配不到就NULL
RIGHT JOIN：  B + (A ∩ B)  — B全要，A匹配不到就NULL（少用）
CROSS JOIN：  A × B        — 笛卡尔积，每行配每行（慎用！）
```

### 测试常用：找出"没装备"的玩家

```sql
-- LEFT JOIN + IS NULL：找出背包为空的玩家
SELECT p.player_id, p.player_name
FROM player p
LEFT JOIN backpack bp ON p.player_id = bp.player_id
WHERE bp.equip_id IS NULL;
```

### 测试实战：验证充值记录与订单表一致性

```sql
-- 找出有充值记录但没有对应订单的异常数据
SELECT r.recharge_id, r.player_id, r.amount
FROM recharge r
LEFT JOIN orders o ON r.order_id = o.order_id
WHERE o.order_id IS NULL;
-- 如果查出数据 → 充值成功但订单没生成，这就是BUG！
```

### JOIN 易错点

- ❌ 忘记写 ON 条件 → 笛卡尔积灾难
- ❌ LEFT JOIN 后在 WHERE 里过滤右表 → 退化成了 INNER JOIN
- ✅ 右表条件写在 ON 里，不要写在 WHERE 里

## 4. 子查询

### 三种位置

```sql
-- ① WHERE 子查询（最常用）
SELECT * FROM player WHERE 战力 > (SELECT AVG(战力) FROM player);

-- ② FROM 子查询（派生表，必须起别名）
SELECT * FROM (SELECT id, name FROM player) AS t;

-- ③ SELECT 子查询（标量子查询）
SELECT name, 战力, (SELECT AVG(战力) FROM player) AS 全服平均 FROM player;
```

### EXISTS vs IN 的选择

| 场景 | 推荐 | 原因 |
|------|------|------|
| 子集数据量大 | EXISTS | 短路求值，找到即停 |
| 子集数据量小 | IN | 都可以 |
| 两表都很大 | EXISTS | 性能优势明显 |

### 测试实战：数据一致性检查

```sql
-- 找出背包里有SSR装备但装备表里没记录的异常数据
SELECT bp.player_id, bp.equip_id
FROM backpack bp
WHERE NOT EXISTS (
    SELECT 1 FROM equipment e WHERE e.id = bp.equip_id
);
```

## 5. UNION 集合操作

```sql
-- UNION：合并并去重
SELECT nickname FROM players_qq
UNION
SELECT nickname FROM players_wechat;

-- UNION ALL：合并不去重（性能更好）
SELECT nickname, 'QQ' AS source FROM players_qq
UNION ALL
SELECT nickname, '微信' AS source FROM players_wechat;
```

**MySQL 没有 INTERSECT/MINUS，用替代方案**：
- 交集 → INNER JOIN
- 差集 → LEFT JOIN + IS NULL 或 NOT EXISTS（最安全）

---

> 多表关联的核心：通过共同字段把分散的数据串起来，分清谁是主表、匹配不到怎么办。
