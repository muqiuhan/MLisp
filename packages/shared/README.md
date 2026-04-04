# MLisp Shared Resources

Language definition files shared across editor extensions.

## Purpose

The `syntax/` directory contains TextMate grammar and language configuration files that can be used by:

- **VSCode extension** (`../vscode-ext/`) - Currently maintains a copy in `syntaxes/`
- **Other editors** - Can use these files for syntax highlighting support

## Contents

| File | Description |
|------|-------------|
| `syntax/mlisp.tmLanguage.json` | TextMate grammar for syntax highlighting |
| `syntax/language-configuration.json` | Language configuration (brackets, auto-closing, folding, etc.) |

## Grammar Features

The TextMate grammar highlights:

- **Comments**: `;;` for line comments
- **Booleans**: `#t`, `#f`
- **Numbers**: Integers (`42`, `-17`) and floats (`3.14`)
- **Strings**: Double-quoted with escape sequences
- **Keywords**:
  - Control: `if`, `cond`, `else`, `begin`, `quote`, `quasiquote`, `unquote`, `unquote-splicing`
  - Definition: `let`, `let*`, `letrec`, `define`, `defun`, `defmacro`, `set!`, `setq`
  - Operators: `and`, `or`, `not`, `lambda`, `module`, `import`, `export`, `ocall`
  - Type predicates: `eq?`, `null?`, `atom?`, `symbol?`, `list?`, `number?`, `string?`
- **Built-in functions**: `apply`, `list`, `cons`, `car`, `cdr`, `print`, `gensym`, etc.
- **Rest parameter**: `&rest`

## Language Configuration

- **Line comments**: `;;`
- **Brackets**: `()`, `[]`, `{}`
- **Folding markers**: `;(` ... `;)`
- **Auto-closing pairs**: All brackets and quotes

## Synchronization

The VSCode extension at `packages/vscode-ext/syntaxes/` currently maintains its own copy.
When updating grammar rules, **update both files** to keep them in sync.

## License

Mozilla Public License, Version 2.0. See [../../LICENSE](../../LICENSE).
