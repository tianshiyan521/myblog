---
title: MySQL 实战 · 第5章：Python + MySQL 测试数据自动化
date: 2026-07-13 09:00:00
categories: 数据库
tags: [MySQL, Python, pymysql, 自动化测试, 测试数据]
---

前面几章都是手动敲 SQL。但**测试工作里最需要自动化的，恰恰是数据库操作**：

- 每次跑用例前重置数据
- 批量造 1000 条测试数据
- 用例执行后校验数据是否正确落库

**这些必须靠代码。**

<!-- more -->

## 一、pymysql 基础

```bash
pip install pymysql
```

```python
import pymysql

conn = pymysql.connect(
    host='localhost',
    port=3306,
    user='root',
    password='your_password',
    database='game_db',
    charset='utf8mb4',
    cursorclass=pymysql.cursors.DictCursor   # ★ 返回字典而不是元组
)
cursor = conn.cursor()
```

> **`DictCursor` 几乎是必选项。**
> 默认游标返回**元组** `(1, '张三', 50)`，你得记住第几列是什么。
> 用 `DictCursor` 返回 **`{'id': 1, 'name': '张三', 'level': 50}`**，可读性天差地别。

### ★ SQL 注入：参数化查询不是可选项

```python
# ❌ 危险：字符串拼接
cursor.execute(f"SELECT * FROM players WHERE name = '{player_name}'")
# 如果 player_name 是   ' OR '1'='1
# 拼出来就是：SELECT * FROM players WHERE name = '' OR '1'='1'  → 查出全表！

# ✅ 正确：参数化查询
cursor.execute("SELECT * FROM players WHERE name = %s", (player_name,))
```

**注意 pymysql 用 `%s` 占位符**（不是 `?`，那是 sqlite3）。

> ⚠️ **测试人员特别要注意这点**：我们经常用**脏数据**测试（特殊字符、超长串、引号），
> 如果用拼接写法，**测试脚本自己就会崩**，甚至误删数据。
>
> **参数化查询既是安全要求，也是测试脚本稳定性的要求。**

### 获取结果

```python
row   = cursor.fetchone()        # 单行
rows  = cursor.fetchmany(10)     # 指定数量
all_  = cursor.fetchall()        # 全部
n     = cursor.rowcount          # 影响行数
newid = cursor.lastrowid         # 最后插入的 ID
```

---

## 二、事务管理

```python
# 手动事务
try:
    cursor.execute("UPDATE accounts SET balance = balance - 100 WHERE id = 1")
    cursor.execute("UPDATE accounts SET balance = balance + 100 WHERE id = 2")
    conn.commit()          # 提交
except Exception as e:
    conn.rollback()        # 回滚
    print(f"事务失败: {e}")
```

### ⚠️ `with conn.cursor()` 不管事务

```python
with conn.cursor() as cursor:
    cursor.execute("UPDATE ...")
    cursor.execute("UPDATE ...")
conn.commit()      # ← 这句仍然必须写！
```

**`with` 只负责关闭游标，不会自动提交。**

**这是很容易误解的地方** —— 很多人以为 `with` 就自带事务保护，其实没有。不 commit 的话，改动不会生效。

---

## 三、连接池（生产环境必备）

```python
# pip install DBUtils
from dbutils.pooled_db import PooledDB

pool = PooledDB(
    creator=pymysql,
    maxconnections=10,    # 最大连接数
    mincached=2,          # 初始空闲连接数
    blocking=True,        # 连接耗尽时等待而非报错
    host='localhost', user='root', password='xxx',
    database='game_db', charset='utf8mb4',
    cursorclass=pymysql.cursors.DictCursor
)

conn = pool.connection()
```

> **为什么需要连接池？**
>
> 每次 `pymysql.connect()` 都要经过 TCP 握手、认证等过程，**开销不小**。
> 频繁创建销毁连接，性能很差，而且容易把数据库的连接数打满。
>
> **连接池预先建好一批连接，用完归还而不是关闭。**

---

## 四、★ 封装一个数据库类

**核心目标：让测试代码里只出现"业务语义"，不出现连接管理和 SQL 拼接。**

```python
"""
game_db.py - 游戏数据库操作封装类
"""
import pymysql
from typing import Optional, List, Dict


class GameDB:
    """游戏数据库操作类"""

    def __init__(self, host='localhost', port=3306, user='root',
                 password='root', database='game_db', charset='utf8mb4'):
        self.config = {
            'host': host, 'port': port, 'user': user,
            'password': password, 'database': database,
            'charset': charset, 'cursorclass': pymysql.cursors.DictCursor
        }
        self._conn: Optional[pymysql.Connection] = None

    def connect(self):
        if self._conn is None or not self._conn.open:
            self._conn = pymysql.connect(**self.config)
        return self

    def close(self):
        if self._conn and self._conn.open:
            self._conn.close()

    def execute(self, sql: str, params: tuple = None) -> int:
        """执行写操作，返回影响行数"""
        self.connect()
        with self._conn.cursor() as cursor:
            cursor.execute(sql, params or ())
            self._conn.commit()
            return cursor.rowcount

    def fetchone(self, sql: str, params: tuple = None) -> Optional[Dict]:
        self.connect()
        with self._conn.cursor() as cursor:
            cursor.execute(sql, params or ())
            return cursor.fetchone()

    def fetchall(self, sql: str, params: tuple = None) -> List[Dict]:
        self.connect()
        with self._conn.cursor() as cursor:
            cursor.execute(sql, params or ())
            return cursor.fetchall()

    def fetchcol(self, sql: str, params: tuple = None, col: str = None) -> List:
        """只取单列，返回列表"""
        rows = self.fetchall(sql, params)
        if col:
            return [row[col] for row in rows]
        return [list(row.values())[0] for row in rows]

    def insert(self, sql: str, params: tuple = None) -> int:
        """插入并返回新 ID"""
        self.connect()
        with self._conn.cursor() as cursor:
            cursor.execute(sql, params or ())
            self._conn.commit()
            return cursor.lastrowid

    def insertmany(self, sql: str, data: List[tuple]):
        """批量插入"""
        self.connect()
        with self._conn.cursor() as cursor:
            cursor.executemany(sql, data)
            self._conn.commit()

    def transaction(self, operations: list) -> bool:
        """事务：全部成功才提交
        operations: [(sql, params), ...]
        """
        self.connect()
        try:
            with self._conn.cursor() as cursor:
                for sql, params in operations:
                    cursor.execute(sql, params or ())
            self._conn.commit()
            return True
        except Exception as e:
            self._conn.rollback()
            print(f"事务回滚: {e}")
            return False
```

### 这个封装的四个设计点

| 设计 | 好处 |
|------|------|
| `connect()` 懒加载 | 用的时候才连，避免空跑也建连接 |
| `DictCursor` | 返回字典，取值靠字段名不靠位置 |
| `fetchcol()` | 只取一列的场景很常见（查 ID 列表） |
| `transaction(operations)` | **把一组操作当成原子单元**，适合"造数据"这种多步操作 |

---

## 五、★ 在测试用例里怎么用

### 用途 1：用例前置 —— 重置数据

```python
def test_claim_reward(db):
    """测试领奖：确保玩家处于"未领过"的状态"""
    # 前置：清掉历史领取记录
    db.execute("DELETE FROM reward_records WHERE user_id = %s AND reward_id = %s",
               (1001, 1))

    # 执行：调用接口领奖
    r = requests.post(CLAIM_URL, json={"token": TOKEN, "rewardId": 1})
    assert r.json()["code"] == 0

    # 校验：数据库里真的写入了
    row = db.fetchone(
        "SELECT * FROM reward_records WHERE user_id = %s AND reward_id = %s",
        (1001, 1)
    )
    assert row is not None, "接口返回成功，但数据库没有记录！"
```

> **最后那句断言是关键**：`assert row is not None, "接口返回成功，但数据库没有记录！"`
>
> **这是接口测试最容易被跳过的一层校验。**
> 接口返回 `code=0` 只代表业务逻辑认为成功了，**不代表数据真的落库了**。

### 用途 2：批量造测试数据

```python
def gen_players(db, count=1000):
    """批量造玩家数据（用 executemany 性能比循环插入高几十倍）"""
    data = [
        (f"test_{i:05d}", random.randint(1, 80), random.randint(0, 50000))
        for i in range(count)
    ]
    db.insertmany(
        "INSERT INTO players (username, level, gold) VALUES (%s, %s, %s)",
        data
    )
```

> **⚠️ `executemany` 和循环 `execute` 的性能差距是几十倍。**
> 1000 条数据，`executemany` 可能 0.1 秒，循环插入要 5 秒以上。
> **造大批量测试数据时，务必用 `executemany`。**

### 用途 3：数据一致性校验

```python
def test_gold_consistency(db):
    """金币一致性：玩家表余额 vs 流水表加总"""
    rows = db.fetchall("""
        SELECT p.id, p.gold,
               COALESCE(SUM(t.amount), 0) AS calc_gold
        FROM players p
        LEFT JOIN gold_transactions t ON p.id = t.player_id
        GROUP BY p.id, p.gold
        HAVING p.gold != COALESCE(SUM(t.amount), 0)
    """)
    assert not rows, f"发现 {len(rows)} 个玩家金币对不上账: {rows[:3]}"
```

**这类"跨表核对"的用例，是接口测试做不到的** —— 只有查数据库才能发现账目问题。

---

## 六、一个实用的测试数据生成套路

```python
import random
from faker import Faker   # pip install faker

fake = Faker('zh_CN')

def gen_player():
    return (
        fake.user_name()[:20],           # 昵称（截断到字段长度内）
        random.randint(1, 100),          # 等级
        random.randint(0, 999999),       # 金币
        random.choice([0, 1, 2]),        # VIP 等级
    )
```

**注意 `fake.user_name()[:20]` 的截断** —— 字段定义是 `VARCHAR(20)`，生成超长字符串会**插入失败**。

> 💡 **造数据时一定要注意字段长度限制**。
> 批量插入时如果有一条超长，`executemany` 会整个失败（或者部分成功，取决于配置）。
> **安全的做法**：生成时就按字段长度截断。

---

## 七、小结

| 要点 | 内容 |
|------|------|
| **pymysql** | `DictCursor` 几乎必选 |
| **参数化查询** | 用 `%s`，**绝不能拼接字符串** |
| **`with cursor`** | ⚠️ **只关游标，不自动提交** |
| **连接池** | 生产环境必备，避免频繁建连 |
| **封装类** | 懒加载 / DictCursor / fetchcol / transaction |
| **用例前置** | 每条用例自己重置数据 |
| **必做校验** | **接口返回成功 ≠ 数据落库成功** |
| **批量插入** | 用 `executemany`，比循环快几十倍 |

> **本课要点**：参数化查询防注入也防脚本崩｜with 不自动提交｜接口成功 ≠ 落库成功｜executemany 快几十倍
