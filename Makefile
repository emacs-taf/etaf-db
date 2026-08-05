EMACS ?= emacs
LOAD_PATH = -L . -L ../etaf -L ../ebox

.PHONY: all compile test check checkdoc load clean

all: check

compile:
	rm -f *.elc tests/*.elc
	$(EMACS) -Q --batch $(LOAD_PATH) --eval '(setq load-prefer-newer t)' \
		--eval '(load-file "etaf-sqlite.el")' \
		--eval '(byte-compile-file "etaf-sqlite.el")'

test: compile
	$(EMACS) -Q --batch $(LOAD_PATH) --eval '(setq load-prefer-newer t)' \
		-l tests/etaf-sqlite-tests.el -f ert-run-tests-batch-and-exit

load: compile
	$(EMACS) -Q --batch $(LOAD_PATH) --eval '(require (quote etaf-sqlite))' \
		--eval '(princ "etaf-sqlite load OK\n")'

checkdoc:
	$(EMACS) -Q --batch --eval '(progn (require (quote checkdoc)) (dolist (file (directory-files "." t)) (when (string-suffix-p ".el" file) (checkdoc-file file))))'

check: checkdoc compile test

clean:
	rm -f *.elc tests/*.elc
