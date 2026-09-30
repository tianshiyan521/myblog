---
title: MySQL 实战 · 第2章：聚合、分组与多表关联
date: 2026-06-19 09:00:00
categories: 数据库
tags: [MySQL, SQL, JOIN, 聚合函数, GROUP BY]
---

真实的项目里，**数据几乎不会只存在一张表里**。

玩家信息在 `players`，背包在 `backpack`，装备属性在 `equipment`，战斗记录在 `battle_records`……

**想看"某个玩家的攻击力总和"，就得跨表查。** 这就是关联查询。

<!-- more -->

## 一、五大聚合函数

```sql
COUNT / SUM / AVG / MAX / MIN
```

```sql
-- COUNT：统计行数
SELECT COUNT(*) FROM players;                   -- 所有行（含 NULL）
SELECT COUNT(level) FROM players;               -- level 非 NULL 的行数
SELECT COUNT(DISTINCT server_id) FROM players;  -- 不同服务器数

-- SUM / AVG / MAX / MIN
SELECT SUM(gold) FROM players;
SELECT AVG(level) FROM players;
SELECT MAX(level), MIN(level) FROM players;
```

### ⚠️ `COUNT(*)` vs `COUNT(字段)` 的区别

**这是最容易出错的地方：**

```sql
SELECT COUNT(*) FROM players;         -- 统计总行数
SELECT COUNT(phone) FROM players;     -- 只统计 phone 不为 NULL 的行数
```

如果 100 个玩家里有 30 个没填手机号：

- `COUNT(*)` → **100**
- `COUNT(phone)` → **70**

**"这个字段有没有填"的统计，必须用 `COUNT(字段)`。**

### ⚠️ AVG 会自动忽略 NULL

```sql
-- 假设有 3 个玩家：level 分别是 10、20、NULL
SELECT AVG(level) FROM players;    -- 结果 15，不是 10
```

**AVG 的分母是"非 NULL 的行数"，不是总行数。**

统计时如果没意识到这点，算出来的"平均等级"会偏高。要包含 NULL 就得用：

```sql
SELECT SUM(level) / COUNT(*) FROM players;
```

---

## 二、GROUP BY 分组

```sql
-- 按服务器统计玩家数
SELECT server_id, COUNT(*) AS player_count
FROM players
GROUP BY server_id;

-- 多字段分组
SELECT server_id, vip_level, COUNT(*) AS player_count
FROM players
GROUP BY server_id, vip_level;

-- 分组 + 多种聚合
SELECT server_id,
       AVG(level) AS avg_level,
       SUM(gold)  AS total_gold
FROM players
GROUP BY server_id;
```

### ★ WHERE vs HAVING（高频考点）

| | WHERE | HAVING |
|---|-------|--------|
| **执行时机** | **分组前** | **分组后** |
| **过滤对象** | 原始行 | 分组结果 |
| **能否用聚合函数** | ❌ 不能 | ✅ 能 |

```sql
-- ✅ WHERE 过滤原始行（分组前）
SELECT server_id, COUNT(*) FROM players
WHERE status = 1              -- 只要正常状态的玩家
GROUP BY server_id;

-- ✅ HAVING 过滤分组结果（分组后）
SELECT server_id, COUNT(*) AS cnt FROM players
GROUP BY server_id
HAVING cnt > 100;             -- 只看玩家数超过 100 的服务器
```

**记忆方法**：

> **WHERE 管"哪些行参与统计"，HAVING 管"哪些统计结果要显示"。**

**执行顺序**：

```
FROM → WHERE → GROUP BY → 聚合 → HAVING → SELECT → ORDER BY → LIMIT
```

> 这也解释了为什么 **WHERE 里不能用聚合函数** —— 执行 WHERE 时还没算聚合呢。

---

## 三、四种 JOIN

| 类型 | 行为 | 结果 |
|------|------|------|
| **INNER JOIN** | 取**交集** | 只返回两表都匹配的行 |
| **LEFT JOIN** | **左表全保留** | 右表匹配不到填 NULL |
| **RIGHT JOIN** | **右表全保留** | 左表匹配不到填 NULL |
| **CROSS JOIN** | **笛卡尔积** | 左表行数 × 右表行数 |

```sql
-- INNER JOIN：只查出有背包物品的玩家
SELECT a.player_name, b.item_name
FROM player a
INNER JOIN backpack b ON a.player_id = b.player_id;

-- LEFT JOIN：所有玩家都显示，没物品的 item_name 为 NULL
SELECT a.player_name, b.item_name
FROM player a
LEFT JOIN backpack b ON a.player_id = b.player_id;
```

### ★ LEFT JOIN 最常见的用途：找"没有关联数据"的记录

**这是测试场景里的高频需求。**

> "找出所有**没有**登录过的玩家"
> "找出所有**没有**绑定手机的账号"
> "找出所有**没有**收到奖励的玩家"

```sql
-- 找出没有背包物品的玩家
SELECT a.player_name
FROM player a
LEFT JOIN backpack b ON a.player_id = b.player_id
WHERE b.player_id IS NULL;      -- ← 关键：右表匹配不到的，就是没有关联的
```

> **这个套路很值得记**：LEFT JOIN 之后 `WHERE 右表.主键 IS NULL`，就能筛出"左表有、右表没有"的记录。
>
> **测试中验证"数据该发的都发了吗"，用的就是这招。**

### ⚠️ CROSS JOIN 的坑

```sql
SELECT a.player_name, b.skin_name
FROM player a
CROSS JOIN skin b;
```

**有 100 个玩家、50 款皮肤 → 结果 5000 行。**

**如果不小心在 JOIN 时漏写 ON 条件，就等于在做 CROSS JOIN**：

```sql
-- ⚠️ 漏了 ON 条件（或 ON 条件写错）
SELECT a.player_name, b.item_name
FROM player a, backpack b;
-- 结果 = 玩家数 × 背包记录数，可能几百万行，数据库直接卡死
```

**这是"慢查询"最常见的成因之一**，排查时第一眼就该看 JOIN 条件写全了没。

---

## 四、多表关联（3 表以上）

```sql
-- 查：玩家名 + 装备名 + 装备属性
SELECT p.player_name, e.equip_name, e.attack_power, e.defense_power
FROM player p
INNER JOIN backpack bp ON p.player_id = bp.player_id
INNER JOIN equipment e ON bp.equip_id = e.equip_id
WHERE e.attack_power > 100;
```

**链路**：`player → backpack（中间表） → equipment`

> 这种"**通过中间表关联**"的结构很常见：
> 玩家和装备是**多对多**关系（一个玩家多件装备，一件装备可被多个玩家拥有），
> 所以需要一个中间表 `backpack` 来承载这层关系。

### 自连接

```sql
-- 查每个玩家的推荐人是谁（推荐人也在 player 表里）
SELECT p.player_name, r.player_name AS referrer
FROM player p
LEFT JOIN player r ON p.referrer_id = r.player_id;
```

**同一张表 JOIN 自己**，必须起两个不同的别名。

**游戏里的应用场景**：推荐关系、师徒关系、公会层级关系（层级树）。

---

## 五、给测试的实用查询

### ① 统计各模块的 BUG 分布

```sql
SELECT module, COUNT(*) AS bug_count
FROM bug_records
WHERE create_time >= '2026-09-01'
GROUP BY module
ORDER BY bug_count DESC;
```

**用数据说话比"感觉 XX 模块问题多"有说服力得多。**

### ② 找出"应该发奖但没发"的玩家

```sql
SELECT p.player_id, p.username
FROM players p
LEFT JOIN reward_records r
       ON p.player_id = r.player_id AND r.reward_id = 1001
WHERE p.vip_level >= 5
  AND r.player_id IS NULL;     -- ← 满足条件但没收到奖励
```

**这是上面那个 LEFT JOIN 套路的实战应用。**

### ③ 验证数据一致性（跨表核对）

```sql
-- 玩家表记录的金币 vs 流水表加总，是否一致？
SELECT p.player_id,
       p.gold AS 表中金币,
       COALESCE(SUM(t.amount), 0) AS 流水加总
FROM players p
LEFT JOIN gold_transactions t ON p.player_id = t.player_id
GROUP BY p.player_id, p.gold
HAVING p.gold != COALESCE(SUM(t.amount), 0);
```

**这条查询能直接找出账目对不上的玩家**——是数据一致性问题排查的经典手法。

> 💡 **`HAVING 字段 != 聚合值`** 这个写法是找"账对不上"的通用套路。
> 换到别的业务也一样：库存 vs 出入库流水、积分 vs 积分流水。

---

## 六、小结

| 要点 | 内容 |
|------|------|
| **COUNT(\*)** | 统计总行数；`COUNT(字段)` 只统计非 NULL |
| **AVG** | ⚠️ 自动忽略 NULL，分母是非 NULL 行数 |
| **WHERE vs HAVING** | WHERE 分组前（不能用聚合）；HAVING 分组后 |
| **INNER JOIN** | 交集 |
| **LEFT JOIN** | 左表全保留；`WHERE 右表 IS NULL` 找"没有关联的" |
| **CROSS JOIN** | ⚠️ 漏写 ON 条件 = 笛卡尔积 = 慢查询 |
| **测试用途** | 统计分布 / 找漏发数据 / 核对账目一致性 |

> **本课要点**：COUNT(*) 与 COUNT(字段) 不同｜AVG 忽略 NULL｜WHERE 管行 HAVING 管组｜LEFT JOIN + IS NULL 找漏数据
