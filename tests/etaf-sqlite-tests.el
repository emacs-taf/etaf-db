;;; etaf-sqlite-tests.el --- Public API acceptance -*- lexical-binding: t; -*-

;;; Commentary:
;; Test supported package inputs, outputs, errors and lifecycle.
;; Internal implementation details are outside this contract.

;;; Code:
(require 'cl-lib)
(require 'ert)
(require 'etaf-db)

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
      (should-not (plist-member source :mutate-v2))
      (should (functionp
               (plist-get (etaf-sqlite-source database :mutate-v2 t)
                          :mutate-v2)))
      (should-not (plist-member source :dispose)))))

(ert-deftest etaf-sqlite-v2-mutation-outcome-reports-commit ()
  "The optional v2 capability reports a committed transaction and token."
  (etaf-sqlite-test--with-database (database)
    (let* ((source (etaf-sqlite-source database :mutate-v2 t))
           (mutate-v2 (plist-get source :mutate-v2))
           (outcome (funcall mutate-v2 'insert
                             '(:id 3 :name "Alan" :score 30))))
      (should (eq (plist-get outcome :certainty) 'committed))
      (should (plist-get outcome :reconciliation-token))
      (should (equal (plist-get (plist-get outcome :result) :operation)
                     'insert))
      (should (= (plist-get (plist-get outcome :result) :id) 3)))))

(ert-deftest etaf-sqlite-v2-mutation-outcome-reports-rollback ()
  "A failed v2 mutation reports rollback and preserves the original error."
  (etaf-sqlite-test--with-database (database)
    (let* ((source (etaf-sqlite-source database :mutate-v2 t))
           (mutate-v2 (plist-get source :mutate-v2))
           (outcome (funcall mutate-v2 'insert
                             '(:id 1 :name "Duplicate" :score 99)))
           (loaded (funcall (plist-get source :load) nil 1 20)))
      (should (eq (plist-get outcome :certainty) 'rolled-back))
      (should (consp (plist-get outcome :error)))
      (should (plist-get outcome :reconciliation-token))
      (should (= (plist-get loaded :total) 2)))))

(ert-deftest etaf-sqlite-v2-post-commit-signal-reports-unknown ()
  "A signal after sqlite-commit must not claim the committed write rolled back."
  (etaf-sqlite-test--with-database (database)
    (let* ((source (etaf-sqlite-source database :mutate-v2 t))
           (mutate-v2 (plist-get source :mutate-v2))
           (original-commit (symbol-function 'sqlite-commit))
           (outcome
            (cl-letf (((symbol-function 'sqlite-commit)
                       (lambda (connection)
                         (funcall original-commit connection)
                         (error "post-commit fault"))))
              (funcall mutate-v2 'insert
                       '(:id 3 :name "Committed" :score 30))))
           (loaded (funcall (plist-get source :load) nil 1 20)))
      (should (eq (plist-get outcome :certainty) 'external-unknown))
      (should (= (plist-get loaded :total) 3)))))

(ert-deftest etaf-sqlite-v2-close-after-commit-reports-unknown ()
  "A close signal after commit is also external uncertainty."
  (etaf-sqlite-test--with-database (database)
    (let* ((source (etaf-sqlite-source database :mutate-v2 t))
           (mutate-v2 (plist-get source :mutate-v2))
           (original-close (symbol-function 'sqlite-close))
           (outcome
            (cl-letf (((symbol-function 'sqlite-close)
                       (lambda (connection)
                         (funcall original-close connection)
                         (error "post-commit close fault"))))
              (funcall mutate-v2 'insert
                       '(:id 3 :name "Committed" :score 30)))))
      (should (eq (plist-get outcome :certainty) 'external-unknown)))))

(provide 'etaf-sqlite-tests)
;;; etaf-sqlite-tests.el ends here
