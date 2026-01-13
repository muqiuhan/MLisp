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
        "Unexpected character '%{c}' encountered. Common causes:\n\
        \  - Extra or missing parentheses\n\
        \  - Invalid symbol characters\n\
        \  - Unclosed strings or comments\n\n\
         Example: Ensure all parentheses are balanced: (define x (+ 1 2))"]
    | Invalid_define_expression e ->
      [%string
        "Invalid define expression: '%{e}'\n\n\
         Correct syntax:\n\
        \  (:= name value)           ; Variable definition\n\
        \  (|= name (args) body)     ; Function definition\n\n\
         Example: (:= x 42) or (|= add (x y) (+ x y))"]
    | Invalid_boolean_literal b ->
      [%string
        "Invalid boolean literal: '%{b}'\n\n\
         Boolean literals must be:\n\
        \  #t  ; true\n\
        \  #f  ; false\n\n\
         Example: (if #t 1 0)"]
    | Record_field_name_must_be_a_symbol record_name ->
      [%string
        "Record field name must be a symbol: %{record_name}\n\n\
         Correct syntax:\n\
        \  (:: 'record-name (@ ('field-name field-value) ...))\n\n\
         Example: (:: 'point (@ ('x 10) ('y 20)))"]
    | Illegal_if_expression expr ->
      [%string
        "Illegal if expression: %{expr}\n\n\
         The condition must evaluate to a boolean (#t or #f).\n\n\
         Example: (? (> 5 3) 10 20)  ; condition must be boolean"])
  | Parse_error_exn e -> (
    match e with
    | Unique_error p ->
      [%string
        "Unique error: %{p}\n\n\
         Duplicate parameter names in function definition. Each parameter must be \
         unique.\n\n\
         Example: (=> (x y z) (+ x y z))  ; all parameters must be different"]
    | Type_error x ->
      [%string
        "Type error: %{x}\n\n\
         Function called with arguments of incorrect type.\n\
         Check the function signature and argument types.\n\n\
         Example: (+ 1 2) works, but (+ \"a\" \"b\") does not"]
    | Poorly_formed_expression ->
      "Poorly formed expression.\n\n\
       Common causes:\n\
      \  - Missing or extra parentheses\n\
      \  - Incomplete expression\n\
      \  - Invalid syntax\n\n\
       Example: Ensure proper nesting: ((f x) y) instead of (f x y))"
    | Apply_error v ->
      [%string
        "Apply error: '%{v}' may not be a function.\n\n\
         Use apply syntax:\n\
        \  (>> function '(args))     ; apply function to list\n\
        \  (function arg1 arg2)     ; direct call\n\n\
         Example: (>> + '(1 2 3)) or (+ 1 2 3)"])
  | Runtime_error_exn e -> (
    match e with
    | Not_found e ->
      [%string
        "Not found: %{e}\n\n\
         The identifier '%{e}' has not been defined in the current context.\n\n\
         Possible solutions:\n\
        \  - Define it first: (:= %{e} value)\n\
        \  - Check spelling\n\
        \  - Import from module: (import module-name)"]
    | Unspecified_value e ->
      [%string
        "Unspecified value: %{e}\n\n\
         The identifier '%{e}' is referenced before being initialized.\n\
         This can happen in letrec bindings.\n\n\
         Example: Ensure all bindings are properly initialized in letrec"]
    | Missing_argument args ->
      [%string
        "Missing arguments: %{String.spacesep args}\n\n\
         Function called with fewer arguments than required.\n\n\
         Example: If function expects 2 args: (f x y), not (f x)"]
    | Non_definition_in_stdlib expr ->
      [%string
        "Non-definition in stdlib: %{expr}\n\n\
         Standard library files can only contain definitions (:=, |=, module, import).\n\n\
         Example: Use (:= name value) or (|= name (args) body)"]
    | Not_a_module name ->
      [%string
        "Not a module: %{name}\n\n\
         The symbol '%{name}' is not bound to a module object.\n\n\
         To define a module:\n\
        \  (module %{name} (export ...) body ...)\n\n\
         To import:\n\
        \  (import %{name})"]
    | Export_not_found (mod_name, export_name) ->
      [%string
        "Export not found: '%{export_name}' in module '%{mod_name}'\n\n\
         The symbol '%{export_name}' is not in the module's export list.\n\n\
         Check the module definition:\n\
        \  (module %{mod_name} (export %{export_name} ...) ...)"]
    | Module_load_error (mod_name, reason) ->
      [%string
        "Module load error: '%{mod_name}'\n\n\
         %{reason}\n\n\
         Failed to load module from file.\n\n\
         Possible causes:\n\
        \  - File not found: %{mod_name}.mlisp\n\
        \  - Syntax error in module file\n\
        \  - Module not defined in file\n\
        \  - Circular dependency in module imports\n\n\
         Check file path and module syntax.\n\
         For circular dependencies, check if imported modules also load this module."])
  | _ ->
    "Unknown error occurred. Please report this issue."
;;
