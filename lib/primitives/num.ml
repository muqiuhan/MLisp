(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error

module Operator = struct
  (* Generate a variadic arithmetic operator with support for multiple arguments *)
  let generate name operator ~identity ~is_negation =
    ( name
    , function
      | [] ->
        (* No arguments: return identity if available, error otherwise *)
        (match identity with
        | Some id -> Object.Fixnum id
        | None ->
          raise (Errors.Parse_error_exn
            (Errors.Type_error [%string "(%{name} requires at least 1 argument)"])))
      | [ Object.Fixnum a ] ->
        (* Single argument: apply negation if specified, otherwise return as-is *)
        if is_negation then
          Object.Fixnum (- a)
        else
          Object.Fixnum a
      | args ->
        (* Multiple arguments: extract all fixnums and fold *)
        let open Core in
        let rec extract_all = function
          | [] -> Some []
          | Object.Fixnum n :: rest ->
            (match extract_all rest with
            | Some nums -> Some (n :: nums)
            | None -> None)
          | _ :: _ -> None
        in
        (match extract_all args with
        | Some (first :: rest) ->
          let result = List.fold rest ~init:first ~f:operator in
          Object.Fixnum result
        | _ ->
          raise (Errors.Parse_error_exn
            (Errors.Type_error [%string "(%{name} int ...)"]))) )
  ;;
end

module Compare = struct
  let generate name operator =
    ( name
    , function
      | [ Object.Fixnum a; Object.Fixnum b ] ->
        Object.Boolean (operator a b)
      | _ ->
        raise (Errors.Parse_error_exn (Errors.Type_error [%string "(%{name} int int)"])) )
  ;;
end

let basis =
  let open Core in
  [ (* Arithmetic operators with variadic support *)
    Operator.generate "+" ( + ) ~identity:(Some 0) ~is_negation:false
  ; Operator.generate "-" ( - ) ~identity:None ~is_negation:true
  ; Operator.generate "*" ( * ) ~identity:(Some 1) ~is_negation:false
  ; Operator.generate "/" ( / ) ~identity:None ~is_negation:false
  (* Bitwise operators *)
  ; Operator.generate "&&&" ( land ) ~identity:(Some (-1)) ~is_negation:false
  ; Operator.generate "|||" ( lor ) ~identity:(Some 0) ~is_negation:false
  ; Operator.generate "^^^" ( lxor ) ~identity:(Some 0) ~is_negation:false
  ; Operator.generate ">>>" ( lsl ) ~identity:None ~is_negation:false
  ; Operator.generate "<<<" ( lsr ) ~identity:None ~is_negation:false
  ; Operator.generate "%%%" ( mod ) ~identity:None ~is_negation:false
  (* Comparison operators (still binary) *)
  ; Compare.generate "=" ( = )
  ; Compare.generate "<" ( < )
  ; Compare.generate ">" ( > )
  ; Compare.generate ">=" ( >= )
  ; Compare.generate "<=" ( <= )
  ]
;;
