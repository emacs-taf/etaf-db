;;; etaf-sqlite-tests.el --- ETAF SQLite source tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'etaf-sqlite)

(defun etaf-sqlite-test--database (file)
  "Return a small typed test DATABASE at FILE."
  (etaf-sqlite-database
   file
   (etaf-sqlite-table
    'items
    (list
     (etaf-sqlite-column :id "id" :type 'integer :primary t)
     (etaf-sqlite-column :name "name" :type 'text)
     (etaf-sqlite-column :score "score" :type 'integer))
    :id)))

(cl-defmacro etaf-sqlite-test--with-database ((database) &rest body)
  "Create a temporary DATABASE while evaluating BODY."
  (declare (indent 1))
  `(let* ((directory (make-temp-file "etaf-sqlite-" t))
          (file (expand-file-name "data.sqlite" directory))
          (,database (etaf-sqlite-test--database file)))
     (unwind-protect
         (progn
           (etaf-sqlite-initialize ,database)
           (let ((mutate (plist-get (etaf-sqlite-source ,database) :mutate)))
             (funcall mutate 'insert '(:id 1 :name "Ada" :score 10))
             (funcall mutate 'insert '(:id 2 :name "Grace" :score 20)))
           ,@body)
       (when (file-exists-p directory)
         (delete-directory directory t)))))

(ert-deftest etaf-sqlite-schema-rejects-unsafe-identifiers ()
  "Identifiers are validated before they can reach SQL text."
  (should-error (etaf-sqlite-column :id "id; DROP TABLE items")
                :type 'etaf-sqlite-schema-error)
  (should-error
   (etaf-sqlite-table
    'items (list (etaf-sqlite-column :id "id")) :missing)
   :type 'etaf-sqlite-schema-error))

(ert-deftest etaf-sqlite-source-loads-and-filters-pages ()
  "The source should implement ETAF Data's load capability."
  (etaf-sqlite-test--with-database (database)
    (let* ((source (etaf-sqlite-source database))
           (result (funcall (plist-get source :load) nil 1 1))
           (filtered (funcall (plist-get source :load)
                              '(:name "Grace") 1 10)))
      (should (= (plist-get result :total) 2))
      (should (= (length (plist-get result :items)) 1))
      (should (equal (plist-get (car (plist-get result :items)) :name)
                     "Ada"))
      (should (= (plist-get filtered :total) 1)))))

(ert-deftest etaf-sqlite-source-mutations-are-visible-to-data-controller ()
  "Insert, update, and delete should share the Data source contract."
  (etaf-sqlite-test--with-database (database)
    (let ((controller (etaf-data-controller (etaf-sqlite-source database)
                                            :page-size 20 :auto-load t)))
      (unwind-protect
          (progn
            (let ((result (etaf-data-mutate
                           controller 'insert
                           '(:id 3 :name "Alan" :score 30))))
              (should (equal 'insert (plist-get result :operation)))
              (should (= 3 (plist-get result :id)))
              (should (= 1 (plist-get result :changes))))
            (should (= (etaf-value (etaf-data-total controller)) 3))
            (etaf-data-mutate controller 'update
                               '(:id 3 :name "Alan Turing" :score 31))
            (should (string= (plist-get
                              (car (cl-remove-if-not
                                    (lambda (row)
                                      (= (plist-get row :id) 3))
                                    (etaf-value
                                     (etaf-data-items controller))))
                              :name)
                             "Alan Turing"))
            (etaf-data-mutate controller 'delete 3)
            (should (= (etaf-value (etaf-data-total controller)) 2)))
        (etaf-data-stop controller)))))

(ert-deftest etaf-sqlite-source-declares-provider-identity ()
  "Expose SQLite identity without depending on ETAF observer internals."
  (etaf-sqlite-test--with-database (database)
    (let ((source (etaf-sqlite-source database)))
      (should (eq 'sqlite (plist-get source :provider)))
      (should (functionp (plist-get source :load)))
      (should (functionp (plist-get source :mutate)))
      (should-not (plist-member source :dispose)))))

(provide 'etaf-sqlite-tests)

;;; etaf-sqlite-tests.el ends here
