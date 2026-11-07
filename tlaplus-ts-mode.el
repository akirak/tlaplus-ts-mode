;;; tlaplus-ts-mode.el --- Tree-sitter major mode for TLA+ -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Akira Komamura

;; Author: Akira Komamura <akira.komamura@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, tlaplus, tree-sitter
;; URL: https://github.com/akirak/tlaplus-ts-mode

;; This file is not part of GNU Emacs.

;;; License:

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; `tlaplus-ts-mode' is a major mode for TLA+ and PlusCal specifications
;; built on Emacs's native tree-sitter support.  It provides syntax
;; highlighting, indentation, Imenu, defun navigation, and comment handling.
;;
;; The mode uses the `tlaplus' grammar from
;; https://github.com/tlaplus-community/tree-sitter-tlaplus.  If the grammar
;; is not installed, this package registers its upstream source in
;; `treesit-language-source-alist' when that variable is available; run
;; `M-x treesit-install-language-grammar RET tlaplus RET' to install it.

;;; Code:

(require 'treesit)
(require 'rx)

(defgroup tlaplus-ts nil
  "Tree-sitter support for TLA+ and PlusCal."
  :group 'languages
  :prefix "tlaplus-ts-")

(defcustom tlaplus-ts-mode-indent-offset 2
  "Number of spaces used for each indentation step in `tlaplus-ts-mode'."
  :type 'integer
  :safe #'integerp
  :group 'tlaplus-ts)

(defvar tlaplus-ts-mode--syntax-table
  (let ((table (make-syntax-table)))
    ;; Identifiers may contain underscores.
    (modify-syntax-entry ?_ "w" table)

    ;; TLA+ has two comment syntaxes: (* ... *) and \* ... .
    ;; The first character of (* is an opening delimiter and the first
    ;; character of \* is a line-comment starter.  The `n' flag allows
    ;; nested block comments, which the grammar also supports.
    (modify-syntax-entry ?\( "()1n" table)
    (modify-syntax-entry ?\) ")(4n" table)
    (modify-syntax-entry ?* ". 23" table)
    (modify-syntax-entry ?\\ ". 1b" table)
    (modify-syntax-entry ?\n ">b" table)
    (modify-syntax-entry ?\r ">b" table)

    (modify-syntax-entry ?\" "\"" table)
    (modify-syntax-entry ?\[ "(]" table)
    (modify-syntax-entry ?\] ")[" table)
    (modify-syntax-entry ?\{ "(}" table)
    (modify-syntax-entry ?\} "){" table)
    table)
  "Syntax table used by `tlaplus-ts-mode'.")

(defconst tlaplus-ts-mode--keywords
  '("ACTION" "ASSUME" "ASSUMPTION" "AXIOM" "BY" "CASE" "CHOOSE"
    "CONSTANT" "CONSTANTS" "COROLLARY" "DEF" "DEFINE" "DEFS"
    "ELSE" "EXCEPT" "EXTENDS" "HAVE" "HIDE"
    "IF" "IN" "INSTANCE" "LAMBDA" "LEMMA" "LET" "LOCAL" "MODULE"
    "NEW" "OBVIOUS" "OMITTED" "ONLY" "OTHER" "PICK" "PROOF"
    "PROPOSITION" "PROVE" "QED" "RECURSIVE" "SF_" "STATE"
    "SUFFICES" "TAKE" "TEMPORAL" "THEN" "THEOREM"
    "USE" "VARIABLE" "VARIABLES" "WF_" "WITH"
    "WITNESS")
  "TLA+ keywords highlighted by `tlaplus-ts-mode'.")

(defconst tlaplus-ts-mode--pluscal-keywords
  '("algorithm" "assert" "await" "begin" "call" "define" "do"
    "either" "else" "elsif" "end" "fair" "goto" "if" "macro" "or"
    "print" "procedure" "process" "then" "variable"
    "variables" "when" "while" "with")
  "PlusCal keywords highlighted by `tlaplus-ts-mode'.")

(defconst tlaplus-ts-mode--font-lock-feature-list
  '((comment)
    (keyword string number constant type)
    (module variable parameter definition function property label
     operator bracket delimiter escape error))
  "Tree-sitter font-lock feature list for `tlaplus-ts-mode'.")

(defvar tlaplus-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :language 'tlaplus
   :feature 'comment
   :override t
   '((comment) @font-lock-comment-face
     (block_comment) @font-lock-comment-face
     (block_comment_text) @font-lock-comment-face
     (single_line) @font-lock-comment-face
     (header_line) @font-lock-preprocessor-face
     (double_line) @font-lock-preprocessor-face
     (extramodular_text) @font-lock-comment-face)

   :language 'tlaplus
   :feature 'keyword
   :override t
   `([,@tlaplus-ts-mode--keywords
      ,@tlaplus-ts-mode--pluscal-keywords
      (address) (all_map_to) (assign) (case_arrow) (case_box)
      (def_eq) (domain) (enabled) (exists) (forall) (gets)
      (label_as) (maps_to) (powerset) (set_in) (temporal_exists)
      (temporal_forall) (unchanged) (union)
      (pcal_algorithm_start) (pcal_end_either) (pcal_end_if)
      (pcal_end_while) (pcal_end_with) (pcal_return) (pcal_skip)]
     @font-lock-keyword-face)

   :language 'tlaplus
   :feature 'string
   :override t
   '((string) @font-lock-string-face)

   :language 'tlaplus
   :feature 'escape
   :override t
   '((escape_char) @font-lock-escape-face)

   :language 'tlaplus
   :feature 'number
   :override t
   '((nat_number) @font-lock-number-face
     (real_number) @font-lock-number-face
     (binary_number (format) @font-lock-keyword-face)
     (binary_number (value) @font-lock-number-face)
     (octal_number (format) @font-lock-keyword-face)
     (octal_number (value) @font-lock-number-face)
     (hex_number (format) @font-lock-keyword-face)
     (hex_number (value) @font-lock-number-face))

   :language 'tlaplus
   :feature 'constant
   :override t
   '((boolean) @font-lock-constant-face)

   :language 'tlaplus
   :feature 'type
   :override t
   '((boolean_set) @font-lock-type-face
     (string_set) @font-lock-type-face
     (nat_number_set) @font-lock-type-face
     (int_number_set) @font-lock-type-face
     (real_number_set) @font-lock-type-face)

   :language 'tlaplus
   :feature 'variable
   :override t
   '((identifier_ref) @font-lock-variable-use-face
     (variable_declaration (identifier) @font-lock-variable-name-face)
     (pcal_var_decl (identifier) @font-lock-variable-name-face)
     (pcal_proc_var_decl (identifier) @font-lock-variable-name-face))

   :language 'tlaplus
   :feature 'module
   :override t
   '((module name: (identifier) @font-lock-type-face)
     (extends (identifier_ref) @font-lock-type-face)
     (instance (identifier_ref) @font-lock-type-face)
     (module_ref (identifier_ref) @font-lock-type-face)
     (module_definition name: (_) @font-lock-type-face)
     (pcal_algorithm name: (identifier) @font-lock-type-face))

   :language 'tlaplus
   :feature 'parameter
   :override t
   '((choose (identifier) @font-lock-variable-name-face)
     (choose (tuple_of_identifiers (identifier)
              @font-lock-variable-name-face))
     (lambda (identifier) @font-lock-variable-name-face)
     (operator_definition parameter: (identifier)
      @font-lock-variable-name-face)
     (function_definition (quantifier_bound (identifier)
                            @font-lock-variable-name-face))
     (module_definition parameter: (identifier)
      @font-lock-variable-name-face)
     (quantifier_bound (identifier) @font-lock-variable-name-face)
     (quantifier_bound (tuple_of_identifiers (identifier)
                        @font-lock-variable-name-face))
     (unbounded_quantification (identifier)
      @font-lock-variable-name-face)
     (assume_prove (new (identifier) @font-lock-variable-name-face))
     (pick_proof_step (identifier) @font-lock-variable-name-face)
     (take_proof_step (identifier) @font-lock-variable-name-face)
     (pcal_macro_decl parameter: (identifier)
      @font-lock-variable-name-face)
     (pcal_with (identifier) @font-lock-variable-name-face))

   :language 'tlaplus
   :feature 'definition
   :override t
   '((operator_definition name: (_) @font-lock-function-name-face)
     (function_definition name: (identifier)
      @font-lock-function-name-face)
     (recursive_declaration (identifier) @font-lock-function-name-face)
     (recursive_declaration
      (operator_declaration name: (_) @font-lock-function-name-face))
     (pcal_macro_decl name: (identifier) @font-lock-function-name-face)
     (pcal_proc_decl name: (identifier) @font-lock-function-name-face)
     (pcal_process name: (identifier) @font-lock-function-name-face)
     (constant_declaration (identifier) @font-lock-constant-face)
     (constant_declaration
      (operator_declaration name: (_) @font-lock-constant-face))
     (assumption name: (identifier) @font-lock-constant-face)
     (theorem name: (identifier) @font-lock-constant-face))

   :language 'tlaplus
   :feature 'function
   :override t
   '((pcal_macro_call name: (identifier)
      @font-lock-function-call-face)
     (pcal_proc_call name: (identifier) @font-lock-function-call-face))

   :language 'tlaplus
   :feature 'property
   :override t
   '((record_literal (identifier) @font-lock-property-name-face)
     (set_of_records (identifier) @font-lock-property-name-face)
     (record_value (identifier_ref) @font-lock-property-use-face)
     (except_update_record_field (identifier_ref)
      @font-lock-property-use-face)
     (pcal_lhs (identifier) @font-lock-property-use-face))

   :language 'tlaplus
   :feature 'label
   :override t
   '((label name: (_) @font-lock-constant-face)
     (proof_step_id (level) @font-lock-preprocessor-face)
     (proof_step_id (name) @font-lock-preprocessor-face)
     (proof_step_ref (level) @font-lock-preprocessor-face)
     (proof_step_ref (name) @font-lock-preprocessor-face)
     (pcal_goto statement: (identifier) @font-lock-constant-face))

   :language 'tlaplus
   :feature 'operator
   :override t
   '((bound_infix_op symbol: (_) @font-lock-operator-face)
     (bound_prefix_op symbol: (_) @font-lock-operator-face)
     (bound_postfix_op symbol: (_) @font-lock-operator-face)
     (bound_nonfix_op symbol: (_) @font-lock-operator-face)
     (prefix_op_symbol) @font-lock-operator-face
     (infix_op_symbol) @font-lock-operator-face
     (postfix_op_symbol) @font-lock-operator-face)

   :language 'tlaplus
   :feature 'bracket
   :override t
   '([(langle_bracket) (rangle_bracket) (rangle_bracket_sub)
      "{" "}" "[" "]" "]_" "(" ")"]
     @font-lock-bracket-face)

   :language 'tlaplus
   :feature 'delimiter
   :override t
   '(["," ":" "." "!" ";" (bullet_conj) (bullet_disj)
      (prev_func_val) (placeholder)]
     @font-lock-delimiter-face)

   :language 'tlaplus
   :feature 'error
   :override t
   '((ERROR) @font-lock-warning-face))
  "Tree-sitter font-lock settings for `tlaplus-ts-mode'.")

(defun tlaplus-ts-mode--named-child (node type)
  "Return the first named child of NODE whose type is TYPE."
  (let ((index 0)
        child)
    (while (and (< index (treesit-node-child-count node t))
                (not (and (setq child (treesit-node-child node index t))
                          (equal (treesit-node-type child) type))))
      (setq index (1+ index)))
    (and child (equal (treesit-node-type child) type) child)))

(defun tlaplus-ts-mode--defun-name (node)
  "Return a name for the definition represented by NODE."
  (let ((type (treesit-node-type node)))
    (pcase type
      ((or "module" "operator_definition" "function_definition"
           "module_definition" "theorem" "assumption" "pcal_algorithm"
           "pcal_process")
       (when-let* ((name (treesit-node-child-by-field-name node "name")))
         (treesit-node-text name t)))
      ((or "pcal_procedure" "pcal_macro")
       (when-let* ((decl (tlaplus-ts-mode--named-child
                          node (if (equal type "pcal_procedure")
                                   "pcal_proc_decl"
                                 "pcal_macro_decl")))
                   (name (treesit-node-child-by-field-name decl "name")))
         (treesit-node-text name t)))
      ("local_definition"
       (when-let* ((definition
                    (seq-find (lambda (child)
                                (member (treesit-node-type child)
                                        '("operator_definition"
                                          "function_definition"
                                          "module_definition"
                                          "instance")))
                              (treesit-node-children node t))))
         (tlaplus-ts-mode--defun-name definition)))
      ("instance"
       (when-let* ((module (tlaplus-ts-mode--named-child
                            node "identifier_ref")))
         (treesit-node-text module t)))
      ((or "constant_declaration" "variable_declaration")
       (when-let* ((identifier
                    (seq-find (lambda (child)
                                (equal (treesit-node-type child) "identifier"))
                              (treesit-node-children node t))))
         (treesit-node-text identifier t))))))

(defconst tlaplus-ts-mode--defun-type-regexp
  (rx bos
      (or "operator_definition" "function_definition"
          "module_definition" "instance" "theorem" "assumption"
          "local_definition" "pcal_process"
          "pcal_procedure" "pcal_macro")
      eos)
  "Regexp matching defun-like node types in `tlaplus-ts-mode'.")

(defvar tlaplus-ts-mode--imenu-settings
  `(("Module" "\\`module\\'" nil tlaplus-ts-mode--defun-name)
    ("Operator" "\\`operator_definition\\'" nil tlaplus-ts-mode--defun-name)
    ("Function" "\\`function_definition\\'" nil tlaplus-ts-mode--defun-name)
    ("Module Definition" "\\`module_definition\\'" nil
     tlaplus-ts-mode--defun-name)
    ("Instance" "\\`instance\\'" nil tlaplus-ts-mode--defun-name)
    ("Theorem" "\\`theorem\\'" nil tlaplus-ts-mode--defun-name)
    ("Assumption" "\\`assumption\\'" nil tlaplus-ts-mode--defun-name)
    ("PlusCal Algorithm" "\\`pcal_algorithm\\'" nil
     tlaplus-ts-mode--defun-name)
    ("PlusCal Process" "\\`pcal_process\\'" nil tlaplus-ts-mode--defun-name)
    ("PlusCal Procedure" "\\`pcal_procedure\\'" nil
     tlaplus-ts-mode--defun-name)
    ("PlusCal Macro" "\\`pcal_macro\\'" nil tlaplus-ts-mode--defun-name)
    ("Constant" "\\`constant_declaration\\'" nil tlaplus-ts-mode--defun-name)
    ("Variable" "\\`variable_declaration\\'" nil tlaplus-ts-mode--defun-name))
  "Simple Imenu settings for `tlaplus-ts-mode'.")

(defun tlaplus-ts-mode--first-list-item (node parent)
  "Return non-nil if NODE is the first item in list PARENT."
  (and node
       (member (treesit-node-type parent) '("conj_list" "disj_list"))
       (treesit-node-eq node (treesit-node-child parent 0 t))))

(defun tlaplus-ts-mode--indent-list-item (node parent _bol)
  "Return indentation for a conjunction or disjunction list item.
NODE is the item, PARENT is its `conj_list' or `disj_list' parent."
  (when (member (treesit-node-type parent) '("conj_list" "disj_list"))
    (if (tlaplus-ts-mode--first-list-item node parent)
        ;; The first item is indented relative to the construct that
        ;; contains the list (usually an operator definition).
        (let ((grandparent (treesit-node-parent parent)))
          (when grandparent
            (cons (treesit-node-start grandparent)
                  tlaplus-ts-mode-indent-offset)))
      ;; Subsequent items align with the first item.
      (cons (treesit-node-start (treesit-node-child parent 0 t)) 0))))

(defun tlaplus-ts-mode--ancestor-of-type (node types)
  "Return the nearest ancestor of NODE whose type is in TYPES."
  (let ((parent (treesit-node-parent node)))
    (while (and parent
                (not (member (treesit-node-type parent) types)))
      (setq parent (treesit-node-parent parent)))
    parent))

(defun tlaplus-ts-mode--indent-proof-step (node _parent _bol)
  "Return indentation for proof steps NODE."
  (let ((type (and node (treesit-node-type node))))
    (when (and node
               (or (member type '("proof_step" "qed_step"))
                   (and (equal type "non_terminal_proof")
                        (not (string-prefix-p
                              "PROOF" (treesit-node-text node t))))))
      (when-let* ((id (if (member type '("proof_step" "qed_step"))
                         (tlaplus-ts-mode--named-child node "proof_step_id")
                       (treesit-search-subtree
                        node "\\`proof_step_id\\'" nil nil 1)))
                  (level (tlaplus-ts-mode--named-child id "level"))
                  (text (treesit-node-text level t))
                  ((string-match-p "\\`[0-9]+\\'" text))
                  (number (string-to-number text))
                  (theorem (tlaplus-ts-mode--ancestor-of-type
                            node '("theorem" "module" "source_file"))))
        (let ((anchor (save-excursion
                        (goto-char (treesit-node-start theorem))
                        (back-to-indentation)
                        (point))))
          (cons anchor (* (1- number) tlaplus-ts-mode-indent-offset)))))))

(defun tlaplus-ts-mode--indent-proof-wrapper (node parent _bol)
  "Align proof wrapper NODE with the construct PARENT that contains it."
  (when node
    (pcase (treesit-node-type node)
      ("terminal_proof"
       (cons (tlaplus-ts-mode--parent-line-start parent) 0))
      ("non_terminal_proof"
       (when (string-prefix-p "PROOF" (treesit-node-text node t))
         (cons (tlaplus-ts-mode--parent-line-start parent) 0))))))

(defun tlaplus-ts-mode--parent-line-start (node)
  "Return the beginning of the first non-space text on NODE's line."
  (save-excursion
    (goto-char (treesit-node-start node))
    (back-to-indentation)
    (point)))

(defvar tlaplus-ts-mode--indent-rules
  `((tlaplus
     ;; Module structure.
     ((parent-is "source_file") column-0 0)
     ((node-is "extramodular_text") column-0 0)
     ((parent-is "extramodular_text") column-0 0)
     ((parent-is "module") column-0 0)
     ((node-is "header_line") column-0 0)
     ((node-is "single_line") column-0 0)
     ((node-is "double_line") column-0 0)

     ;; Closing delimiters align with their opening delimiter.
     ((node-is "}") parent 0)
     ((node-is ")") parent 0)
     ((node-is "]") parent 0)
     ((node-is "rangle_bracket") parent 0)
     ((node-is "rangle_bracket_sub") parent 0)

     ;; PlusCal block terminators align with the block opener.
     ((node-is "pcal_end_if\\|pcal_end_while\\|pcal_end_either\\|pcal_end_with")
      parent-bol 0)
     ((node-is "\\`end\\'") parent-bol 0)

     ;; Conjunction and disjunction lists.
     tlaplus-ts-mode--indent-list-item

     ;; Proofs.
     tlaplus-ts-mode--indent-proof-step
     tlaplus-ts-mode--indent-proof-wrapper

     ;; Continuation lines of definitions.
     ((parent-is "operator_definition\\|function_definition\\|module_definition")
      parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "instance\\|substitution")
      parent-bol tlaplus-ts-mode-indent-offset)

     ;; Block-like expressions.
     ((parent-is "let_in") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "if_then_else") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "case") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "case_arm") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "except") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "parentheses") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "finite_set_literal") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "set_filter") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "set_map") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "function_literal") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "record_literal") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "set_of_records") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "tuple_literal") parent-bol tlaplus-ts-mode-indent-offset)

     ;; Proof contents.
     ((field-is "assumption") parent-bol tlaplus-ts-mode-indent-offset)
     ((node-is "new") parent-bol tlaplus-ts-mode-indent-offset)
     ((and (node-is "assume_prove") (parent-is "theorem"))
      parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "assume_prove") parent-bol 0)
     ((parent-is "suffices_proof_step")
      parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "proof_step\\|qed_step")
      parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "non_terminal_proof")
      parent-bol tlaplus-ts-mode-indent-offset)

     ;; PlusCal bodies.
     ((parent-is "pcal_var_decls") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "pcal_proc_var_decls")
      parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "pcal_definitions") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "pcal_algorithm_body")
      parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "pcal_if") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "pcal_while") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "pcal_either") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "pcal_with") parent-bol tlaplus-ts-mode-indent-offset)

     (catch-all parent-bol 0)))
  "Tree-sitter indentation rules for `tlaplus-ts-mode'.")

(defun tlaplus-ts-mode--register-grammar ()
  "Register the upstream TLA+ grammar source."
  (when (boundp 'treesit-language-source-alist)
    (let ((source '(tlaplus
                    "https://github.com/tlaplus-community/tree-sitter-tlaplus")))
      (unless (assoc 'tlaplus treesit-language-source-alist)
        (add-to-list 'treesit-language-source-alist source)))))

(tlaplus-ts-mode--register-grammar)

;;;###autoload
(define-derived-mode tlaplus-ts-mode prog-mode "TLA⁺[TS]"
  "Major mode for editing TLA+ and PlusCal specifications using tree-sitter.

\\{tlaplus-ts-mode-map}"
  :group 'tlaplus-ts
  :syntax-table tlaplus-ts-mode--syntax-table
  (tlaplus-ts-mode--register-grammar)
  (unless (treesit-ready-p 'tlaplus t)
    (user-error
     "TLA+ tree-sitter grammar is unavailable; install the `tlaplus' grammar"))

  (setq-local treesit-primary-parser (treesit-parser-create 'tlaplus))
  (setq-local comment-start "\\* ")
  (setq-local comment-end "")
  (setq-local comment-start-skip
              (rx (or (seq "\\" (+ "*")) (seq "(" (+ "*")))
                  (* (syntax whitespace))))
  (setq-local comment-end-skip
              (rx (* (syntax whitespace))
                  (group (or (syntax comment-end)
                             (seq (+ "*") ")")))))
  (setq-local comment-use-syntax t)
  (setq-local comment-multi-line t)
  (setq-local indent-tabs-mode nil)
  (setq-local electric-indent-chars
              (append '(?{ ?} ?\( ?\) ?\[ ?\])
                      electric-indent-chars))

  (setq-local treesit-font-lock-settings tlaplus-ts-mode--font-lock-settings)
  (setq-local treesit-font-lock-feature-list
              tlaplus-ts-mode--font-lock-feature-list)
  (setq-local treesit-simple-indent-rules tlaplus-ts-mode--indent-rules)
  (setq-local treesit-defun-type-regexp
              tlaplus-ts-mode--defun-type-regexp)
  (setq-local treesit-defun-name-function #'tlaplus-ts-mode--defun-name)
  (setq-local treesit-simple-imenu-settings tlaplus-ts-mode--imenu-settings)

  (treesit-major-mode-setup))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.tla\\'" . tlaplus-ts-mode))

(provide 'tlaplus-ts-mode)

;;; tlaplus-ts-mode.el ends here
