# tlaplus-ts-mode

> [!warning]
> This is just a vibe-coded project for personal use. It won't get a proper
> maintenance.

An Emacs major mode for [TLA+](https://lamport.azurewebsites.net/tla/tla.html)
and PlusCal, built on Emacs's native tree-sitter integration.

The mode uses the
[tree-sitter-tlaplus](https://github.com/tlaplus-community/tree-sitter-tlaplus)
grammar and provides:

- Tree-sitter syntax highlighting for TLA+ and PlusCal
- Indentation for definitions, conjunction/disjunction lists, proofs, and
  PlusCal blocks
- Imenu entries for modules, operators, functions, theorems, and PlusCal
  constructs
- Defun navigation with `beginning-of-defun` and `end-of-defun`
- Comment support for both `\* line comments` and `(* nested block comments *)`

## Requirements

- Emacs 29.1 or later with tree-sitter support
- The `tlaplus` tree-sitter grammar

## Installation

Put `tlaplus-ts-mode.el` on your load path and load it:

```emacs-lisp
(require 'tlaplus-ts-mode)
```

The mode associates itself with `.tla` files.

The package registers the upstream grammar repository in
`treesit-language-source-alist`.  If the grammar is not installed yet, run:

```emacs-lisp
M-x treesit-install-language-grammar RET tlaplus RET
```

Upstream grammar:
https://github.com/tlaplus-community/tree-sitter-tlaplus

## Customization

`tlaplus-ts-mode-indent-offset` controls the number of spaces used for each
indentation step (default: 2).

## Tests

The ERT tests live in `test/tlaplus-ts-mode-test.el`.  Tests that require the
grammar are skipped when it is unavailable.  With the grammar installed, run:

```sh
emacs -Q --batch \
  -L . -L test \
  -l tlaplus-ts-mode-test \
  -f ert-run-tests-batch-and-exit
```

## License

GPL-3.0-or-later.  See `LICENSE`.
