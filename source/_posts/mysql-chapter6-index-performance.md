---
title: MySQL 实战 · 第3章：索引与慢查询优化
date: 2026-06-29 09:00:00
categories: 数据库
tags: [MySQL, 索引, 慢查询, EXPLAIN, 性能优化]
---

**测试人员为什么需要懂索引？**

因为**"接口慢"往往不是代码问题，是 SQL 没走索引**。而判断这件事的手段是 `EXPLAIN`——一个测试人员完全能掌握的技能。

学会它，你就能在开发说"这个是网络问题"的时候，拿出数据说话。

<!-- more -->

## 一、索引基础

```sql
-- 建索引
CREATE INDEX idx_name ON items_test(item_name);

-- 复合索引（联合索引）
CREATE INDEX idx_lev_vip_pow ON players_test(level, vip, power);

-- 查看表上的索引
SHOW INDEX FROM players_test;
SHOW CREATE TABLE players_test;

-- 删除索引
DROP INDEX idx_name ON items_test;
```

### 复合索引的列顺序很重要

```sql
CREATE INDEX idx_lev_vip_pow ON players_test(level, vip, power);
```

**"最左前缀原则"**：索引 `(level, vip, power)` 相当于一本按 `level → vip → power` 排序的目录。

| 查询条件 | 能否用索引 | 说明 |
|---------|-----------|------|
| `level = 20` | ✅ | 用最左列 |
| `level = 20 AND vip = 1` | ✅ | 用前两列 |
| `level = 20 AND vip = 1 AND power > 10000` | ✅ | 用全部三列 |
| **`vip = 2`** | ❌ | **跳过最左列，索引失效** |
| **`power > 10000`** | ❌ | **从第三列开始，索引失效** |

> **直观理解**：就像查字典时跳过首字母直接找第二个字母。
>
> 索引是按 `level → vip → power` 的顺序排的。你只给 `vip`，就相当于跳过首字母查字典 —— **只能翻全书**。

### ⚠️ 范围查询会截断后面的列

```sql
EXPLAIN SELECT * FROM players_test
WHERE level > 10 AND vip = 1 AND power > 10000;
```

**`level > 10` 是范围查询，它后面的 `vip` 就用不上索引的有序性了**（只能靠索引条件下推 ICP 部分优化）。

> **设计原则**：**等值条件放前面，范围条件放最后。**

---

## 二、★ EXPLAIN：索引失效的诊断工具

```sql
EXPLAIN SELECT * FROM game_players WHERE level = 30 AND power > 5000;
```

### 关键列速查

| 列 | 含义 | 好的表现 |
|----|------|---------|
| **type** | 访问类型 | **越靠左越好** |
| **key** | 实际使用的索引 | **`NULL` = 没用到索引 ⚠️** |
| **key_len** | 索引使用的字节长度 | 判断复合索引用了几列 |
| **rows** | 预估扫描行数 | **越少越好** |
| **Extra** | 附加信息 | 见下 |

### type 从优到劣

```
system > const > eq_ref > ref > range > index > ALL
```

| type | 含义 |
|------|------|
| `const` | 主键/唯一索引**精确匹配**，只读 1 行 |
| `eq_ref` | JOIN 时主键/唯一索引匹配，每次读 1 行 |
| `ref` | 非唯一索引匹配，可能读多行 |
| `range` | 索引**范围**扫描（BETWEEN / > / < / IN） |
| `index` | 全索引扫描（比 ALL 好一点，还是要扫整棵树） |
| **`ALL`** | **⚠️ 全表扫描，最差，必须优化** |

### Extra 关键信息

| Extra | 含义 | 好坏 |
|-------|------|------|
| **`Using index`** | **覆盖索引，不用回表** | ✅ 极佳 |
| `Using index condition` | 索引下推（ICP） | ✅ 好 |
| `Using where` | 在 server 层过滤 | 一般 |
| **`Using filesort`** | **额外排序（没走索引排序）** | ❌ 差 |
| **`Using temporary`** | **用了临时表（GROUP BY / DISTINCT / UNION）** | ❌ 更差 |

> **看到一个慢查询，先看这几项**：
> - `type: ALL` → 没走索引
> - `key: NULL` → 没走索引
> - `rows` 很大 → 扫描数据量太大
> - `Using filesort` / `Using temporary` → 有额外开销

---

## 三、索引失效的 7 大场景

**每一个都要记住，因为这是"慢查询"的主要成因。**

### ❌ 场景 1：在索引列上使用函数

```sql
-- 索引失效
EXPLAIN SELECT * FROM items_test WHERE UPPER(item_name) = '屠龙刀';

-- ✅ 修复：函数放值那侧
EXPLAIN SELECT * FROM items_test WHERE item_name = UPPER('屠龙刀');
```

**原因**：MySQL 不认识 `UPPER(item_name)` 之后的值，无法用索引查找。

### ❌ 场景 2：隐式类型转换

```sql
-- 索引失效（item_name 是字符串，却用数字查）
EXPLAIN SELECT * FROM items_test WHERE item_name = 12345;

-- ✅ 修复：类型保持一致
EXPLAIN SELECT * FROM items_test WHERE item_name = '12345';
```

**原因**：MySQL 会把字符串列**全部转成数字**再比较，等于对每一行都做了转换。

> ⚠️ **这个坑很隐蔽**：SQL 看起来没问题，报错也没有，**只是慢了**。
> 测试时如果发现某个查询莫名其妙慢，又怀疑是类型问题，**看 EXPLAIN 的 `type` 是不是 `ALL`**。

### ❌ 场景 3：LIKE 前导模糊

```sql
-- 索引失效（不知道前缀是什么）
EXPLAIN SELECT * FROM items_test WHERE item_name LIKE '%龙刀';

-- ✅ 后模糊可以用索引
EXPLAIN SELECT * FROM items_test WHERE item_name LIKE '屠龙%';
```

**记忆**：**`%` 在前，索引白建。**

真的需要前后模糊搜索时，考虑 Elasticsearch 或 FULLTEXT 索引。

### ❌ 场景 4：OR 条件中有一侧无索引

```sql
-- 可能导致全表扫描
EXPLAIN SELECT * FROM items_test WHERE price = 999 OR item_type = '武器';

-- ✅ 修复：改写为 UNION
EXPLAIN SELECT * FROM items_test WHERE price = 999
UNION
SELECT * FROM items_test WHERE item_type = '武器';
```

**原因**：OR 的语义是"满足任一个"，MySQL 需要在两侧都做完整查找才能合并结果。只要有一侧没索引，就可能退化成全表扫描。

### ❌ 场景 5：使用 `!=` 或 `<>`

```sql
-- 否定条件通常不走索引
EXPLAIN SELECT * FROM items_test WHERE item_type != '药品';

-- ✅ 修复：用 IN 列出已知合法值
EXPLAIN SELECT * FROM items_test WHERE item_type IN ('武器','消耗品','法宝');
```

**原因**：否定条件的匹配范围太大（除了一种，其他全要），MySQL 认为全表扫描更快。

### ❌ 场景 6：`IS NOT NULL`

```sql
EXPLAIN SELECT * FROM items_test WHERE item_name IS NOT NULL;
```

`IS NULL` 通常能走索引，**`IS NOT NULL` 大概率不走** —— 如果大部分数据非 NULL，全表扫描反而更快。

**优化方向**：加 `NOT NULL` 约束 + 默认值，从根本上避免 NULL 判断。

### ❌ 场景 7：`NOT IN` 的子查询里有 NULL

```sql
SELECT * FROM a WHERE id NOT IN (SELECT id FROM b);
-- 如果 b.id 里存在 NULL → 结果永远是空集！
```

> ⚠️ **这个不只是性能问题，是正确性问题。**
>
> `NOT IN` 的语义是"不等于集合里的任何一个值"。而 `NULL` 参与比较的结果是 `UNKNOWN`（不是 TRUE 也不是 FALSE）。
> **所以只要子查询结果里有 NULL，整个 `NOT IN` 就永远返回空结果。**
>
> **这是 SQL 里最反直觉的坑之一**，测试时看到 `NOT IN` 子查询，一定要确认子查询字段有没有 NULL。

---

## 四、★ 慢查询定位完整流程

### 第 1 步：开启慢查询日志

```sql
-- 查看是否开启
SHOW VARIABLES LIKE 'slow_query_log%';
SHOW VARIABLES LIKE 'long_query_time';

-- 临时开启（重启失效）
SET GLOBAL slow_query_log = ON;
SET GLOBAL long_query_time = 1;                      -- 超过 1 秒记录
SET GLOBAL log_queries_not_using_indexes = ON;       -- 记录未用索引的查询

-- 查看日志文件位置
SHOW VARIABLES LIKE 'slow_query_log_file';
```

**永久开启**（编辑 `my.cnf` / `my.ini`）：

```ini
[mysqld]
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 1
```

### 第 2 步：EXPLAIN 分析

```sql
EXPLAIN SELECT * FROM players WHERE server_id = 1 AND level > 50;
```

**逐列看**：`type` 是不是 `ALL`？`key` 是不是 `NULL`？`rows` 多大？`Extra` 有没有 filesort/temporary？

### 第 3 步：三种优化手段

| 手段 | 适用场景 | 效果 |
|------|---------|------|
| **加索引 / 改索引** | 索引缺失或顺序不对 | 最快见效 |
| **改写 SQL** | 索引失效场景（函数、隐式转换、OR） | 中等 |
| **架构调整** | 数据量太大、查询本身不合理 | 成本高但根本 |

### 第 4 步：验证效果

**改完必须重新 EXPLAIN 对比**：

```sql
-- 优化前
EXPLAIN SELECT * FROM game_chars_test WHERE fight_power > 5000;
-- type = ALL, rows ≈ 500

-- 加索引
CREATE INDEX idx_power ON game_chars_test(fight_power);

-- 优化后
EXPLAIN SELECT * FROM game_chars_test WHERE fight_power > 5000;
-- type = range, rows 大幅减少
```

> **注意：优化不是"改完就算完"，必须验证。**
> 拿优化前后的 `type`、`rows`、实际响应时间对比，**用数据证明有效**。

---

## 五、★ 用 EXPLAIN 做测试断言（测试人员独有的用法）

这是**测试人员用索引知识的最佳姿势**：把"性能要求"变成**可自动执行的断言**。

### 场景：策划要求"按区服+等级查角色必须快"

```sql
CREATE TABLE game_chars_test (
    id          INT PRIMARY KEY AUTO_INCREMENT,
    server_id   INT NOT NULL,
    char_level  INT NOT NULL,
    fight_power INT NOT NULL,
    INDEX idx_srv_level(server_id, char_level)
);

-- 测试用例 1：断言"按区服+等级查询必须走复合索引"
EXPLAIN SELECT * FROM game_chars_test
WHERE server_id = 3 AND char_level = 50;

-- 期望：type = ref, key = idx_srv_level
-- 如果 key = NULL 或 type = ALL → 索引失效，用例不通过
```

**这段 EXPLAIN 就可以作为一个测试用例。**

### 测试用例 2：验证最左前缀（反向断言）

```sql
-- 断言"仅按等级查询不走索引"（验证最左前缀原则生效）
EXPLAIN SELECT * FROM game_chars_test WHERE char_level = 50;

-- 期望：type = ALL, key = NULL
```

**这个"反向断言"很有价值** —— 它验证的是**索引设计符合预期**，而不只是"能查到数据"。

### 测试场景的批量造数

```sql
-- 造 500 行：5 个区服，每区 100 个角色
INSERT INTO game_chars_test (server_id, char_level, fight_power)
SELECT
    (n % 5) + 1 AS server_id,
    10 + (n % 90) AS char_level,
    1000 + (n * 13 % 9000) AS fight_power
FROM (
    SELECT @row := @row + 1 AS n
    FROM (SELECT 0 UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4) t1,
         (SELECT 0 UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4) t2,
         (SELECT 0 UNION SELECT 1 UNION SELECT 2 UNION SELECT 3) t3,
         (SELECT @row := -1) r
) nums;
```

> 💡 **这个"用 UNION 生成数字序列"的技巧很实用**：
> MySQL 没有内置的 `generate_series`，用几个 `SELECT 常数 UNION` 做笛卡尔积就能生成任意数量的序号。
> **批量造测试数据时非常方便，不依赖存储过程。**

---

## 六、小结

| 要点 | 内容 |
|------|------|
| **最左前缀** | 复合索引必须从最左列开始用，跳过就失效 |
| **范围截断** | 范围查询后面的列用不上索引有序性 |
| **EXPLAIN** | 看 `type` / `key` / `rows` / `Extra` |
| **`ALL` + `key: NULL`** | 全表扫描，必须优化 |
| **索引失效 7 场景** | 函数、隐式转换、前导模糊、OR、`!=`、`IS NOT NULL`、`NOT IN` 带 NULL |
| **优化三步** | 开启慢查询日志 → EXPLAIN 分析 → 加索引/改 SQL → **验证效果** |
| **测试用法** | **用 EXPLAIN 做断言，把性能要求变成可执行用例** |

> **本课要点**：`%` 在前索引白建｜`NOT IN` 带 NULL 会返回空集｜等值放前范围放后｜用 EXPLAIN 写测试断言
