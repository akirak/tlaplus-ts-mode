;;; tlaplus-ts-mode-test.el --- Tests for tlaplus-ts-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Akira Komamura

;; This file is not part of GNU Emacs.

;;; License:

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; Commentary:

;; Tests for `tlaplus-ts-mode'.  Tests that need the tree-sitter grammar
;; are skipped when it is unavailable.

;;; Code:

(require 'ert)
(require 'imenu)
(require 'treesit)
(require 'tlaplus-ts-mode)

(defconst tlaplus-ts-mode-test--spec
  "---- MODULE Counter ----
EXTENDS Naturals

CONSTANT Max
VARIABLE count

Init ==
  /\\ count = 0
  /\\ Max \\in Nat

Next ==
  \\/ count' = (count + 1) % Max
  \\/ UNCHANGED count

Spec == Init /\\ [][Next]_count

\\* A line comment.
THEOREM Safety == Spec => [] (count \\in 0..Max)
====
")

(defmacro tlaplus-ts-mode-test--with-buffer (contents &rest body)
  "Create a temporary TLA+ buffer with CONTENTS and evaluate BODY."
  (declare (indent 1) (debug t))
  `(progn
     (unless (treesit-ready-p 'tlaplus t)
       (ert-skip "The tlaplus tree-sitter grammar is unavailable"))
     (with-temp-buffer
       (insert ,contents)
       (tlaplus-ts-mode)
       ,@body)))

(defun tlaplus-ts-mode-test--face-at (text)
  "Return the font-lock face at the first occurrence of TEXT."
  (let ((case-fold-search nil))
    (goto-char (point-min))
    (search-forward text)
    (get-text-property (match-beginning 0) 'face)))

(defun tlaplus-ts-mode-test--has-face-p (actual expected)
  "Return non-nil when ACTUAL is or includes face EXPECTED."
  (if (listp actual)
      (memq expected actual)
    (eq actual expected)))

(ert-deftest tlaplus-ts-mode-test-auto-mode ()
  (should (eq (assoc-default "example.tla" auto-mode-alist #'string-match-p)
              'tlaplus-ts-mode)))

(ert-deftest tlaplus-ts-mode-test-registers-grammar-source ()
  (should (assoc 'tlaplus treesit-language-source-alist)))

(ert-deftest tlaplus-ts-mode-test-requires-grammar ()
  (skip-unless (not (treesit-ready-p 'tlaplus t)))
  (with-temp-buffer
    (should-error (tlaplus-ts-mode) :type 'user-error)))

(ert-deftest tlaplus-ts-mode-test-setup ()
  (tlaplus-ts-mode-test--with-buffer "---- MODULE Test ----\n====\n"
    (should (eq major-mode 'tlaplus-ts-mode))
    (should (equal comment-start "\\* "))
    (should (equal comment-end ""))
    (should-not indent-tabs-mode)
    (should treesit-primary-parser)
    (should (equal (treesit-node-type (treesit-buffer-root-node 'tlaplus))
                   "source_file"))))

(ert-deftest tlaplus-ts-mode-test-font-lock ()
  (tlaplus-ts-mode-test--with-buffer tlaplus-ts-mode-test--spec
    (font-lock-ensure)
    (should (tlaplus-ts-mode-test--has-face-p
             (tlaplus-ts-mode-test--face-at "Counter")
             'font-lock-type-face))
    (should (tlaplus-ts-mode-test--has-face-p
             (tlaplus-ts-mode-test--face-at "EXTENDS")
             'font-lock-keyword-face))
    (should (tlaplus-ts-mode-test--has-face-p
             (tlaplus-ts-mode-test--face-at "Max")
             'font-lock-constant-face))
    (should (tlaplus-ts-mode-test--has-face-p
             (tlaplus-ts-mode-test--face-at "count")
             'font-lock-variable-name-face))
    (should (tlaplus-ts-mode-test--has-face-p
             (tlaplus-ts-mode-test--face-at "Init")
             'font-lock-function-name-face))
    (should (tlaplus-ts-mode-test--has-face-p
             (tlaplus-ts-mode-test--face-at "Nat")
             'font-lock-type-face))
    (should (tlaplus-ts-mode-test--has-face-p
             (tlaplus-ts-mode-test--face-at "0")
             'font-lock-number-face))
    (should (tlaplus-ts-mode-test--has-face-p
             (tlaplus-ts-mode-test--face-at "UNCHANGED")
             'font-lock-operator-face))
    (should (tlaplus-ts-mode-test--has-face-p
             (tlaplus-ts-mode-test--face-at "A line comment")
             'font-lock-comment-face))))

(ert-deftest tlaplus-ts-mode-test-indentation ()
  (tlaplus-ts-mode-test--with-buffer
      "---- MODULE Test ----\nInit ==\n/\\ x = 0\n/\\ y = 1\n====\n"
    (indent-region (point-min) (point-max))
    (should (equal (buffer-string)
                   "---- MODULE Test ----\nInit ==\n  /\\ x = 0\n  /\\ y = 1\n====\n"))))

(ert-deftest tlaplus-ts-mode-test-proof-indentation ()
  (tlaplus-ts-mode-test--with-buffer
      (concat "---- MODULE Test ----\n"
              "THEOREM T == TRUE\n"
              "PROOF\n"
              "<1>a. TRUE\n"
              "<2>a. TRUE\n"
              "<2>b. QED\n"
              "<1>b. QED\n"
              "====\n")
    (indent-region (point-min) (point-max))
    (should (equal (buffer-string)
                   (concat "---- MODULE Test ----\n"
                           "THEOREM T == TRUE\n"
                           "PROOF\n"
                           "<1>a. TRUE\n"
                           "  <2>a. TRUE\n"
                           "  <2>b. QED\n"
                           "<1>b. QED\n"
                           "====\n")))))

(ert-deftest tlaplus-ts-mode-test-comment-syntax ()
  (tlaplus-ts-mode-test--with-buffer
      (concat "x == 1 \\* line comment\n"
              "(* outer (* inner *) outer *)\n"
              "y == 2\n")
    (goto-char (point-min))
    (search-forward "y == 2")
    (should-not (nth 4 (syntax-ppss (match-beginning 0))))
    (goto-char (point-min))
    (search-forward "outer *)")
    (should (nth 4 (syntax-ppss (match-beginning 0))))))

(ert-deftest tlaplus-ts-mode-test-defun-navigation-and-imenu ()
  (tlaplus-ts-mode-test--with-buffer tlaplus-ts-mode-test--spec
    (goto-char (point-max))
    (beginning-of-defun)
    (should (looking-at-p "THEOREM"))
    (let ((index (imenu--make-index-alist t)))
      (should (assoc "Module" index))
      (should (assoc "Operator" index))
      (should (assoc "Theorem" index))
      (should (assoc "Init" (cdr (assoc "Operator" index))))
      (should (assoc "Next" (cdr (assoc "Operator" index))))
      (should (assoc "Safety" (cdr (assoc "Theorem" index)))))))

(provide 'tlaplus-ts-mode-test)

;;; tlaplus-ts-mode-test.el ends here
