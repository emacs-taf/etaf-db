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

其他数据库、REST、文件和 ORM 应在各自的具体数据源包中实现同一个 source capability；它们不进入 ETAF core，也不创建笼统的 `etaf-adapters` 层。

在该目录运行 `make check EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs`。
