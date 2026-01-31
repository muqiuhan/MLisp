# Monorepo Migration Guide

## What Changed

The MLisp repository has been restructured as a monorepo:

- **Before**: Root contained `bin/`, `lib/`, `stdlib/`, etc.
- **After**: Code organized under `packages/` directory

## New Structure

| Package | Purpose | Language |
|---------|---------|----------|
| `interpreter/` | MLisp interpreter | OCaml |
| `vscode-ext/` | VSCode extension (js_of_ocaml) | OCaml |
| `shared/` | Language grammar | JSON |

## Migration Impact

### Building

```bash
# Old
dune build

# New
npm run build
# or
cd packages/interpreter && dune build
cd packages/vscode-ext && dune build
```

### Running

```bash
# Old
dune exec mlisp

# New
cd packages/interpreter && dune exec mlisp
```

### VSCode Extension

The VSCode extension is now written in OCaml and compiled via js_of_ocaml:

```bash
cd packages/vscode-ext
dune build        # OCaml -> JavaScript bytecode
npm run bundle    # esbuild packaging
npm run package   # Create .vsix
```
