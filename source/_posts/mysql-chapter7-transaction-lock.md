---
title: MySQL 实战 · 第4章：事务、锁与并发问题
date: 2026-07-02 09:00:00
categories: 数据库
tags: [MySQL, 事务, 锁, 并发, ACID, 隔离级别]
---

游戏里的很多诡异问题，根因在数据库并发：

- "打赢了却没获得领地"（两个队同时结算，后者覆盖前者）
- "明明不够钱却买成功了"（并发扣款，超卖）
- "重复领了两次奖励"（并发领奖，幂等失效）

**这些全是并发问题。** 理解事务和锁，才能在测试时准确描述和定位这类问题。

<!-- more -->

## 一、ACID 四大特性

| 特性 | 含义 | 类比 |
|------|------|------|
| **A** 原子性 | 要么全做，要么全不做 | 转账：扣 A 的钱和加 B 的钱必须同时成功 |
| **C** 一致性 | 事务前后数据符合所有约束 | 转账后总金额不变，不能凭空多出钱 |
| **I** 隔离性 | 并发事务之间互不干扰 | 两人同时买最后一件，不能都成功 |
| **D** 持久性 | 提交后永久保存，断电不丢 | 提交后即使崩溃，重启数据还在 |

> **记忆**：A 全有或全无 → C 数据不错乱 → I 互不干扰 → D 提交就永存

---

## 二、事务控制语法

```sql
-- 显式开启事务
START TRANSACTION;
    UPDATE accounts SET balance = balance - 100 WHERE id = 1;
    UPDATE accounts SET balance = balance + 100 WHERE id = 2;
COMMIT;       -- 提交
-- ROLLBACK;  -- 或回滚，撤销所有修改

-- 保存点（部分回滚）
BEGIN;
    INSERT INTO logs (msg) VALUES ('步骤1完成');
    SAVEPOINT sp1;
    INSERT INTO logs (msg) VALUES ('步骤2完成');
    SAVEPOINT sp2;
    INSERT INTO logs (msg) VALUES ('步骤3完成');
    ROLLBACK TO SAVEPOINT sp2;    -- 只撤销步骤3，保留步骤1、2
COMMIT;

-- 自动提交状态
SELECT @@autocommit;    -- 1=自动提交（默认）, 0=手动
SET autocommit = 0;
```

> ⚠️ **MySQL 默认 `autocommit = 1`**，也就是**每条 SQL 都是一个独立事务，自动提交**。
>
> 这就是为什么直接 `UPDATE` 不用 commit 也能生效——它自己提交了。
> 但**一旦 `START TRANSACTION`，就必须手动 COMMIT 或 ROLLBACK**。

---

## 三、★ 四种隔离级别与三个并发问题

### 三个并发问题

**① 脏读（Dirty Read）**

```
事务A修改数据但未提交  →  事务B读到了这个未提交的数据  →  事务A回滚了
结果：事务B读到了一个"不存在"的值
```

```
时间线：
  A: UPDATE balance = 500 WHERE id=1   (原值 1000)
  B: SELECT balance ...                 → 读到 500  ← 脏读！
  A: ROLLBACK                           → 滚回 1000
  B 已经基于 500 做了后续操作 → 逻辑错误
```

**② 不可重复读（Non-Repeatable Read）**

```
事务B两次读同一行  →  中间事务A修改了这行并提交
结果：两次读到不同值
```

```
时间线：
  B: SELECT balance → 1000
  A: UPDATE balance = 2000 → COMMIT
  B: SELECT balance → 2000   ← 两次读到不同值
```

**③ 幻读（Phantom Read）**

```
事务B两次查询满足条件的数据  →  中间事务A插入了新行并提交
结果：第二次查询"多出几行"
```

```
时间线：
  B: SELECT * FROM orders WHERE amount > 100 → 3 行
  A: INSERT INTO orders VALUES (4, 200) → COMMIT
  B: SELECT * FROM orders WHERE amount > 100 → 4 行  ← 多了"幻影行"
```

### 对照表

| 隔离级别 | 脏读 | 不可重复读 | 幻读 | 性能 |
|---------|------|-----------|------|------|
| `READ UNCOMMITTED` | ✗ | ✗ | ✗ | 最高（几乎不用） |
| `READ COMMITTED` | ✓ | ✗ | ✗ | 较高（Oracle 默认） |
| **`REPEATABLE READ`** | ✓ | ✓ | ✗* | 中等（**MySQL 默认**） |
| `SERIALIZABLE` | ✓ | ✓ | ✓ | 最低（串行执行） |

> `✗` = 有问题，`✓` = 已解决
> `*` MySQL 的 REPEATABLE READ 通过 **Next-Key Lock** 部分解决了幻读

```sql
-- 查看隔离级别
SELECT @@transaction_isolation;          -- MySQL 8.0+
-- SELECT @@tx_isolation;                -- MySQL 5.7

-- 设置隔离级别
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET GLOBAL  TRANSACTION ISOLATION LEVEL REPEATABLE READ;
```

### ⚠️ 不可重复读 vs 幻读的区别

**这是最常见的混淆点：**

| | 不可重复读 | 幻读 |
|---|-----------|------|
| **变化对象** | **同一行**被改了 | **多出/少了行** |
| 关注点 | 行内的**值**变了 | 结果集的**行数**变了 |

> **一句话**：**不可重复读是"同一行值变了"，幻读是"行数变了"。**

---

## 四、锁机制

```sql
-- 排他锁（写锁）：锁定行，其他事务不能读/写
SELECT * FROM accounts WHERE id = 1 FOR UPDATE;

-- 共享锁（读锁）：锁定行，其他事务可读但不能写
SELECT * FROM accounts WHERE id = 1 LOCK IN SHARE MODE;

-- 查看锁等待
SHOW ENGINE INNODB STATUS\G
```

| 锁类型 | 别名 | 冲突 |
|--------|------|------|
| **共享锁（S）** | 读锁 | 可以多个共享锁共存；与排他锁冲突 |
| **排他锁（X）** | 写锁 | 独占，与其他任何锁都冲突 |

| 锁粒度 | 特点 |
|--------|------|
| **行锁** | 并发度高，但开销大、可能死锁 |
| **表锁** | 开销小、并发低 |

> **InnoDB 默认用行锁**（基于索引实现）。⚠️ **注意：如果查询条件没走索引，行锁会升级成表锁！**
>
> 这是个很隐蔽的坑：`UPDATE ... WHERE 无索引字段 = x` 会锁住整张表，**直接导致其他所有事务排队**。

---

## 五、★ 并发问题在游戏里的样子

这是**测试人员最该掌握的部分**——把理论对上实际现象。

### 场景 1：领地争夺 - 数据覆盖

```
问题现象：A 队打赢了，但领地归了 B 队

根因：两队同时攻打同一块领地
      A 队先打完，结算写入"归属=A"
      B 队后打完，结算写入"归属=B"（覆盖了 A）
```

**测试方法**：

```sql
-- 模拟并发结算
BEGIN;
    UPDATE territory SET owner_id = 'A', version = version + 1
    WHERE territory_id = 100 AND version = 5;
COMMIT;
```

**关键验证点**：

- 结算语句**有没有加版本号条件**（乐观锁）？
- 有没有 `SELECT ... FOR UPDATE` 加悲观锁？
- 并发写入同一个领地时，最终结果是否唯一确定？

> **如果没有加任何锁或版本控制，这个 bug 必然存在**，只需要构造并发就能复现。
> 提单时可以直接说："结算 UPDATE 缺少版本号条件或行锁，两个队伍并发结算时存在覆盖风险。"

### 场景 2：商城购买 - 超卖

```
问题现象：钻石只有 100，却买成功了 200 的东西
      或：同一件限购商品被同一玩家买了两次
```

**测试方法**：用 JMeter / 脚本**同时发两个相同请求**。

```python
# 伪代码：并发发两次购买请求
import threading
results = []
def buy():
    results.append(requests.post(BUY_URL, json={...}))

t1 = threading.Thread(target=buy)
t2 = threading.Thread(target=buy)
t1.start(); t2.start()
t1.join();  t2.join()
# 检查：是否两次都成功？余额是否变成负数？
```

**验证点**：

- 扣款和发货是否在**同一个事务**里？
- 有没有**行锁或乐观锁**保护余额？
- 有没有**唯一约束**防止重复购买？

### 场景 3：每日任务 - 重复领奖

```
问题现象：玩家连点两下"领取"，拿到了两份奖励
```

**根因**：查"是否已领取"和"写入领取记录"是两步，中间有间隙。

```
时间线：
  请求1: 查 → 未领取
  请求2: 查 → 未领取          ← 两个请求都通过了检查
  请求1: 写入领取记录 + 发奖
  请求2: 写入领取记录 + 发奖   ← 又发了一份
```

**正确做法**：**唯一约束 + 事务**。

```sql
-- 给 (user_id, task_date, task_id) 加唯一索引
-- 第二次插入会因唯一约束失败，从而被拦截
ALTER TABLE task_records
ADD UNIQUE KEY uk_user_task (user_id, task_date, task_id);
```

**测试方法**：并发发两次领奖请求，检查是否只有一次成功、奖励是否只发一份。

---

## 六、怎么设计并发测试

**并发问题的特点：手动测试几乎测不出来。**

因为手动操作有先后顺序（你不可能同时点两下），**只有真正的并发请求才会触发**。

### 并发测试的基本步骤

| 步骤 | 做法 |
|------|------|
| **1. 确定并发点** | 哪些操作有"读-改-写"？领奖、扣款、抢购、结算 |
| **2. 准备隔离数据** | 每次测试前重置数据到同一初始状态 |
| **3. 同时发起请求** | 用线程 / JMeter / `xargs -P` 并发 |
| **4. 校验结果** | 资金是否守恒？奖励是否多发？数据是否覆盖？ |
| **5. 重复多次** | 并发问题有概率性，跑 1 次不复现不代表没问题 |

### 用命令行做简单并发

```bash
# 同时发 10 个请求
seq 1 10 | xargs -P 10 -I {} curl -s -X POST http://test/api/claim \
    -H "token: xxx" -d '{"rewardId": 1}'
```

> **`xargs -P 10` 就是"同时跑 10 个"**。这是最快构造并发的方法，不需要装任何工具。

---

## 七、小结

| 要点 | 内容 |
|------|------|
| **ACID** | 原子 / 一致 / 隔离 / 持久 |
| **三个并发问题** | 脏读（读到未提交）、不可重复读（同一行值变了）、幻读（行数变了） |
| **MySQL 默认** | `REPEATABLE READ` |
| **不可重复读 vs 幻读** | 前者是"值变"，后者是"行数变" |
| **锁** | 共享锁（读）/ 排他锁（写）；**无索引会退化成表锁** |
| **游戏并发场景** | 领地结算覆盖 / 商城超卖 / 重复领奖 |
| **测试手段** | 多线程请求、`xargs -P`、JMeter；**必须重复多次** |

> **本课要点**：手动测不出并发问题｜不可重复读 vs 幻读｜无索引会让行锁升级为表锁｜并发测试要重复多次
