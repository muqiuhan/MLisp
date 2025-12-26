(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Errors
open Mlisp_utils

(** Generate help message for errors with examples and suggestions.

    Provides detailed help information including:
    - Explanation of the error
    - Common causes
    - Example code showing correct usage
    - Suggestions for fixing the error *)
let help = function
  | Syntax_error_exn e -> (
    match e with
    | Unexcepted_character c ->
      [%string
        "Unexpected character '%{c}' encountered. Common causes:\n  - Extra or missing parentheses\n  - Invalid symbol characters\n  - Unclosed strings or comments\n\nExample: Ensure all parentheses are balanced: (define x (+ 1 2))"]
    | Invalid_define_expression e ->
      [%string
        "Invalid define expression: '%{e}'\n\nCorrect syntax:\n  (:= name value)           ; Variable definition\n  (|= name (args) body)     ; Function definition\n\nExample: (:= x 42) or (|= add (x y) (+ x y))"]
    | Invalid_boolean_literal b ->
      [%string
        "Invalid boolean literal: '%{b}'\n\nBoolean literals must be:\n  #t  ; true\n  #f  ; false\n\nExample: (if #t 1 0)"]
    | Record_field_name_must_be_a_symbol record_name ->
      [%string
        "Record field name must be a symbol: %{record_name}\n\nCorrect syntax:\n  (:: 'record-name (@ ('field-name field-value) ...))\n\nExample: (:: 'point (@ ('x 10) ('y 20)))"]
    | Illegal_if_expression expr ->
      [%string
        "Illegal if expression: %{expr}\n\nThe condition must evaluate to a boolean (#t or #f).\n\nExample: (? (> 5 3) 10 20)  ; condition must be boolean"])
  | Parse_error_exn e -> (
    match e with
    | Unique_error p ->
      [%string
        "Unique error: %{p}\n\nDuplicate parameter names in function definition. Each parameter must be unique.\n\nExample: (=> (x y z) (+ x y z))  ; all parameters must be different"]
    | Type_error x ->
      [%string
        "Type error: %{x}\n\nFunction called with arguments of incorrect type.\nCheck the function signature and argument types.\n\nExample: (+ 1 2) works, but (+ \"a\" \"b\") does not"]
    | Poorly_formed_expression ->
      "Poorly formed expression.\n\nCommon causes:\n  - Missing or extra parentheses\n  - Incomplete expression\n  - Invalid syntax\n\nExample: Ensure proper nesting: ((f x) y) instead of (f x y))"
    | Apply_error v ->
      [%string
        "Apply error: '%{v}' may not be a function.\n\nUse apply syntax:\n  (>> function '(args))     ; apply function to list\n  (function arg1 arg2)     ; direct call\n\nExample: (>> + '(1 2 3)) or (+ 1 2 3)"])
  | Runtime_error_exn e -> (
    match e with
    | Not_found e ->
      [%string
        "Not found: %{e}\n\nThe identifier '%{e}' has not been defined in the current context.\n\nPossible solutions:\n  - Define it first: (:= %{e} value)\n  - Check spelling\n  - Import from module: (import module-name)"]
    | Unspecified_value e ->
      [%string
        "Unspecified value: %{e}\n\nThe identifier '%{e}' is referenced before being initialized.\nThis can happen in letrec bindings.\n\nExample: Ensure all bindings are properly initialized in letrec"]
    | Missing_argument args ->
      [%string
        "Missing arguments: %{String.spacesep args}\n\nFunction called with fewer arguments than required.\n\nExample: If function expects 2 args: (f x y), not (f x)"]
    | Non_definition_in_stdlib expr ->
      [%string
        "Non-definition in stdlib: %{expr}\n\nStandard library files can only contain definitions (:=, |=, module, import).\n\nExample: Use (:= name value) or (|= name (args) body)"]
    | Not_a_module name ->
      [%string
        "Not a module: %{name}\n\nThe symbol '%{name}' is not bound to a module object.\n\nTo define a module:\n  (module %{name} (export ...) body ...)\n\nTo import:\n  (import %{name})"]
    | Export_not_found (mod_name, export_name) ->
      [%string
        "Export not found: '%{export_name}' in module '%{mod_name}'\n\nThe symbol '%{export_name}' is not in the module's export list.\n\nCheck the module definition:\n  (module %{mod_name} (export %{export_name} ...) ...)"]
    | Module_load_error (mod_name, reason) ->
      [%string
        "Module load error: '%{mod_name}' - %{reason}\n\nFailed to load module from file.\n\nPossible causes:\n  - File not found: %{mod_name}.mlisp\n  - Syntax error in module file\n  - Module not defined in file\n\nCheck file path and module syntax."])
  | _ ->
    "Unknown error occurred. Please report this issue."
;;
