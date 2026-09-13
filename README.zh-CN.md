# etaf-sqlite

`etaf-sqlite` 是 ETAF 的具体 SQLite 存储包，把 Emacs 内置 SQLite 能力适配到核心 `etaf-data-source` 契约。Data Controller 仍属于 `etaf`；本包只负责 schema 校验、短连接、分页查询和同步 mutation。

```elisp
(require 'etaf-sqlite)

(let* ((table (etaf-sqlite-table
               'items
               (list (etaf-sqlite-column :id "id" :type 'integer :primary t)
                     (etaf-sqlite-column :name "name" :type 'text))
               :id))
       (database (etaf-sqlite-database "~/items.sqlite" table))
       (source (etaf-sqlite-source database)))
  (etaf-sqlite-initialize database)
  (etaf-data-controller source :auto-load t))
```

默认 source 仍只暴露兼容的 `:mutate` callback。需要明确的提交/回滚确定性
和只读 reconciliation 时，显式使用 `(etaf-sqlite-source database
:mutate-v2 t)` 开启增量 wrapper。

其他数据库、REST、文件和 ORM 应在各自的具体数据源包中实现同一个 source capability；它们不进入 ETAF core，也不创建笼统的 `etaf-adapters` 层。

在该目录运行 `make check EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs`。

## 开发

克隆后运行 `make setup-hooks`。提交变更前运行 `make check`；`make structure-check` 用于快速检查目录、命名和引用。

[集成契约](docs/manual.zh-CN.md)。

`make check` 运行规范检查、编译及 [tests/acceptance.json](tests/acceptance.json) 中的公共验收场景。`make test` 运行同一套公共 API 测试。清单涵盖全部维护的 Lisp 测试。GUI 与性能验收使用独立入口。
