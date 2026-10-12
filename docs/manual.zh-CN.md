# ETAF DB 使用手册

## 集成契约

从仓库根入口加载 `(require 'etaf-db)`。本包为 ETAF 提供数据库后端，
目前只实现 SQLite；`etaf-sqlite-*` 后端 API 由[包入口](../etaf-db.el)维护。

调用方创建 `etaf-data-source`
交给 ETAF Data Controller；响应式状态和生命周期由 Controller 管理。
SQLite 后端负责 schema 校验、SQL、事务及短连接。调用方使用公共构造函数和 capability，
不调用私有 SQL 辅助函数。

不再使用 Controller 时调用 `etaf-data-stop`。描述符和数据源不会在操作之间
保留数据库连接。数据库后端复用既有数据源能力，不增加专用 Controller 协议或 ORM。

1. 用 `etaf-sqlite-column` 和 `etaf-sqlite-table` 声明列与表。
2. 用 `etaf-sqlite-database` 创建描述符，并调用 `etaf-sqlite-initialize` 初始化表。
3. 将 `(etaf-sqlite-source database)` 交给 `etaf-data-controller`。

数据源支持 plist/alist 等值查询与分页加载，以及 `insert`、`replace`、`update`、
`delete`。变更结果包含操作、影响行数和适用时的插入标识。每次操作使用短连接，
构造函数的精确参数见 docstring。

数据源还暴露 `:mutate-batch`：ETAF 的 `etaf-data-mutate-many` 把整个
`(OPERATION PAYLOAD)` 列表交给一个 SQLite 事务，每个操作各得一个结果，
Controller 只对账一次，所以批量导入不再为每一行付出一次重载。某个操作报错时
整批回滚；提交结果不确定时抛出 `etaf-sqlite-commit-unknown`。

`etaf-sqlite-initialize` 会把已有表与描述符对齐：缺失的可空列就地补齐；缺失的
主键列或声明为不可空的列则抛出 `etaf-sqlite-schema-error`，让 schema 演进必须
显式处理，而不是让应用跑在半匹配的表上。

默认暴露 `:mutate`；显式传入 `:mutate-v2 t` 可增加提交确定性结果及不透明的
reconciliation token。已确认回滚与结果未知不同：commit、rollback 或关闭连接阶段
存在不确定性时，不得当成“已确认写入失败”直接重试。调用方使用 Controller 的
对账契约。schema 错误及不支持的操作向调用方抛出，不切换其他存储后端。

## 可运行示例与验证

完整示例见 [README](../README.zh-CN.md)。运行 `make test`，由
`tests/etaf-sqlite-tests.el` 验证 schema、查询、变更、回滚、不确定性与 Controller 集成。
数据源 capability 契约由 [ETAF 参考手册](https://gitea.gklazycat.heiyu.space/emacs-taf/etaf-manual/src/branch/main/book/zh-CN/data-sources.md) 维护。
