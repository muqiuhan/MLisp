# MLisp VSCode Extension - Testing Guide

This document describes how to manually test the MLisp VSCode extension features.

## Extension Features

### 1. Language Support

#### Syntax Highlighting
The extension provides syntax highlighting for `.mlisp` files with the following scopes:

| Element | Scope | Examples |
|---------|-------|----------|
| Comments | `comment.line.semicolon.mlisp` | `;; This is a comment` |
| Booleans | `constant.language.boolean.mlisp` | `#t`, `#f` |
| Numbers | `constant.numeric.mlisp` | `42`, `3.14`, `-10` |
| Strings | `string.quoted.double.mlisp` | `"Hello, World!"` |
| Control Keywords | `keyword.control.mlisp` | `if`, `cond`, `else`, `begin`, `quote`, `quasiquote`, `unquote`, `unquote-splicing` |
| Definition Keywords | `keyword.control.special.mlisp` | `let`, `let*`, `letrec`, `define`, `defun`, `defmacro`, `set!`, `setq` |
| Operator Keywords | `keyword.operator.mlisp` | `lambda`, `module`, `import`, `export`, `ocall` |
| Rest Parameter | `keyword.operator.rest-parameter.mlisp` | `&rest` |
| Nil | `constant.language.nil.mlisp` | `nil` |
| Functions | `entity.name.function.mlisp` | `factorial`, `square`, `car`, `cdr` |
| Punctuation | `punctuation.definition.*.mlisp` | `(`, `)`, `'`, `` ` ``, `,`, `,@` |

#### Bracket Matching
Auto-closing pairs and bracket matching for:
- Parentheses: `(` `)`
- Square brackets: `[` `]`
- Curly braces: `{` `}`
- Strings: `"`

#### Comment Toggle
- Line comment: `;;`

### 2. Editor Behavior

#### Auto-indentation
- Indent increases after open parenthesis `(` when line doesn't end with `)` or `;`
- Indent decreases after closing parenthesis `)`

#### Word Boundaries
Word pattern: `(?!\\b)[a-zA-Z0-9-*/<>!=?+]+`

This allows symbols like `*`, `+`, `-`, `/`, `?`, `!` to be part of identifiers.

### 3. Commands

| Command ID | Title | Keybinding | Description |
|------------|-------|------------|-------------|
| `mlisp.startREPL` | MLisp: Start REPL | None | Opens the MLisp REPL output channel |
| `mlisp.evaluateSelection` | MLisp: Evaluate Selection | `Ctrl+Enter` | Evaluates selected code (coming soon) |

## Manual Testing Procedure

### Prerequisites

1. Build the extension:
   ```bash
   cd /home/somhairle/Workspace/mlisp/packages/vscode-ext
   npm run build
   ```

2. Install the extension:
   ```bash
   npm run package
   npm run install:ext
   ```

Or for development:
- Press `F5` in VSCode to launch Extension Development Host

### Test Cases

#### Test 1: Syntax Highlighting

Open `syntax_test.mlisp` and verify:

1. **Comments** - `;; comment text` should be highlighted as comments (usually green)
2. **Numbers** - `42`, `3.14`, `-10` should have numeric highlighting
3. **Strings** - `"text"` should have string highlighting (usually orange)
4. **Booleans** - `#t`, `#f` should have constant highlighting
5. **Keywords** - Control flow words (`if`, `cond`, `else`, `define`, `lambda`) should have keyword coloring
6. **Functions** - Function names should have function coloring

#### Test 2: Bracket Matching

1. Type `(` and verify `)` is auto-inserted
2. Place cursor after `(` and verify matching `)` is highlighted
3. Type `[` and verify `]` is auto-inserted
4. Type `{` and verify `}` is auto-inserted
5. Type `"` and verify closing `"` is auto-inserted

#### Test 3: Comment Toggle

1. Select a line of code
2. Press `Ctrl+/` (or your comment toggle keybinding)
3. Verify `;;` is added at the start
4. Press `Ctrl+/` again
5. Verify comment is removed

#### Test 4: Auto-indentation

1. Type:
   ```lisp
   (define (test x)
   ```
2. Press Enter - cursor should indent
3. Type `(+ x 1))`
4. Verify indentation is correct

#### Test 5: Commands

1. Open Command Palette (`Ctrl+Shift+P`)
2. Type "MLisp"
3. Verify both commands appear:
   - "MLisp: Start REPL"
   - "MLisp: Evaluate Selection"
4. Run "MLisp: Start REPL"
5. Verify output channel opens with message "MLisp REPL Started"
6. Verify information message appears: "MLisp extension activated!"

#### Test 6: File Association

1. Create a new file `test.mlisp`
2. Verify language mode is automatically set to "MLisp"
3. Check status bar shows "MLisp"

#### Test 7: Keybinding

1. Open a `.mlisp` file
2. Select some code
3. Press `Ctrl+Enter`
4. Verify information message appears: "Evaluation coming soon!"

## Test Files

### syntax_test.mlisp
Contains all language constructs for syntax highlighting verification.

### example.mlisp
Basic MLisp code examples for general testing.

### modules_test.mlisp
Module system features (imports, exports).

### macros_test.mlisp
Macro definition and quasiquote examples.

## Expected Results Summary

| Feature | Expected Behavior | Status |
|---------|------------------|--------|
| Syntax highlighting | All tokens colored correctly | Manual Verify |
| Bracket matching | Auto-close and highlight matching pairs | Manual Verify |
| Comments | `;;` toggles comments | Manual Verify |
| Auto-indent | Indents after open paren | Manual Verify |
| Start REPL command | Opens output channel | Manual Verify |
| Evaluate command | Shows "coming soon" message | Manual Verify |
| File association | .mlisp files open as MLisp | Manual Verify |

## Known Limitations

1. **REPL Implementation** - The REPL command only shows an output channel. Full REPL evaluation is not yet implemented.
2. **Evaluate Selection** - Shows placeholder message. Actual evaluation is coming soon.

## Next Steps

To add full REPL functionality:
1. Implement MLisp interpreter in JavaScript/WebAssembly
2. Add process communication to run `mlisp` binary
3. Display evaluation results in output channel
4. Add error handling and reporting
