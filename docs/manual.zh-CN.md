# SQLite 适配器使用手册

## 集成契约

提供方是 `etaf-db` 仓库中的 `etaf-sqlite` 包。调用方创建 `etaf-data-source`
交给 ETAF Data Controller；响应式状态和生命周期由 Controller 管理。
适配器负责 schema 校验、SQL、事务及短连接。调用方使用公共构造函数和 capability，
不调用私有 SQL 辅助函数。

1. 用 `etaf-sqlite-column` 和 `etaf-sqlite-table` 声明列与表。
2. 用 `etaf-sqlite-database` 创建描述符，并调用 `etaf-sqlite-initialize` 初始化表。
3. 将 `(etaf-sqlite-source database)` 交给 `etaf-data-controller`。

数据源支持 plist/alist 等值查询与分页加载，以及 `insert`、`replace`、`update`、
`delete`。变更结果包含操作、影响行数和适用时的插入标识。每次操作使用短连接，
构造函数的精确参数见 docstring。

默认暴露 `:mutate`；显式传入 `:mutate-v2 t` 可增加提交确定性结果及不透明的
reconciliation token。已确认回滚与结果未知不同：commit、rollback 或关闭连接阶段
存在不确定性时，不得当成“已确认写入失败”直接重试。调用方使用 Controller 的
对账契约。schema 错误及不支持的操作向调用方抛出，不切换其他存储后端。

## 可运行示例与验证

完整示例见 [README](../README.zh-CN.md)。运行 `make test`，由
`tests/etaf-sqlite-tests.el` 验证 schema、查询、变更、回滚、不确定性与 Controller 集成。
数据源 capability 契约由 [ETAF 手册](https://gitea.gklazycat.heiyu.space/geekinney/etaf/src/branch/main/docs/manual.zh-CN.md) 维护。
