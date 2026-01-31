(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object
open Mlisp_error

module Operator = struct
  (* Generate a variadic arithmetic operator with support for multiple arguments and floats *)
  let generate name (operator : float -> float -> float) ~identity ~is_negation =
    ( name
    , function
      | [] -> (
        match identity with
        | Some id ->
          Object.Float id
        | None ->
          raise
            (Errors.Parse_error_exn
               (Errors.Type_error [%string "(%{name} requires at least 1 argument)"])))
      | [ Object.Fixnum a ] ->
        if is_negation then
          Object.Fixnum (-a)
        else
          Object.Fixnum a
      | [ Object.Float a ] ->
        if is_negation then
          Object.Float (-.a)
        else
          Object.Float a
      | args -> (
        let
        (* Multiple arguments: extract all numbers (int or float) and fold *)
        open
          Core in
        let rec extract_all = function
          | [] ->
            Some ([], false)
          | Object.Fixnum n :: rest -> (
            match extract_all rest with
            | Some (nums, has_float) ->
              Some (float_of_int n :: nums, has_float)
            | None ->
              None)
          | Object.Float n :: rest -> (
            match extract_all rest with
            | Some (nums, _) ->
              Some (n :: nums, true)
            | None ->
              None)
          | _ :: _ ->
            None
        in
          match extract_all args with
          | Some (first :: rest, has_float) ->
            let result = List.fold rest ~init:first ~f:operator in
              if has_float then
                Object.Float result
              else
                Object.Fixnum (int_of_float result)
          | _ ->
            raise
              (Errors.Parse_error_exn (Errors.Type_error [%string "(%{name} number ...)"]))
        ) )
  ;;
end

module Compare = struct
  let generate name operator =
    ( name
    , function
      | [ Object.Fixnum a; Object.Fixnum b ] ->
        Object.Boolean (operator (float_of_int a) (float_of_int b))
      | [ Object.Float a; Object.Float b ] ->
        Object.Boolean (operator a b)
      | [ Object.Fixnum a; Object.Float b ] ->
        Object.Boolean (operator (float_of_int a) b)
      | [ Object.Float a; Object.Fixnum b ] ->
        Object.Boolean (operator a (float_of_int b))
      | [ Object.Nil; Object.Nil ] ->
        (* Special case for = with nil - only equality makes sense *)
        if name = "=" then
          Object.Boolean true
        else
          raise
            (Errors.Parse_error_exn
               (Errors.Type_error [%string "(%{name} number number)"]))
      | _ ->
        raise
          (Errors.Parse_error_exn (Errors.Type_error [%string "(%{name} number number)"]))
    )
  ;;
end

let basis =
  let open Core in
  [ (* Arithmetic operators with variadic support *)
    Operator.generate "+" ( +. ) ~identity:(Some 0.0) ~is_negation:false
  ; Operator.generate "-" ( -. ) ~identity:None ~is_negation:true
  ; Operator.generate "*" ( *. ) ~identity:(Some 1.0) ~is_negation:false
  ; Operator.generate "/" ( /. ) ~identity:None ~is_negation:false
  ; ( "mod"
    , function
      | [ Object.Fixnum a; Object.Fixnum b ] ->
        Object.Fixnum (a mod b)
      | _ ->
        raise (Errors.Parse_error_exn (Errors.Type_error "(mod int int)")) )
  ; ( "%"
    , function
      | [ Object.Fixnum a; Object.Fixnum b ] ->
        Object.Fixnum (a mod b)
      | _ ->
        raise (Errors.Parse_error_exn (Errors.Type_error "(% int int)")) )
    (* Bitwise operators - only work on integers *)
  ; ( "&&&"
    , function
      | [ Object.Fixnum a; Object.Fixnum b ] ->
        Object.Fixnum (a land b)
      | _ ->
        raise (Errors.Parse_error_exn (Errors.Type_error "(&&& int int)")) )
  ; ( "|||"
    , function
      | [ Object.Fixnum a; Object.Fixnum b ] ->
        Object.Fixnum (a lor b)
      | _ ->
        raise (Errors.Parse_error_exn (Errors.Type_error "(||| int int)")) )
  ; ( "^^^"
    , function
      | [ Object.Fixnum a; Object.Fixnum b ] ->
        Object.Fixnum (a lxor b)
      | _ ->
        raise (Errors.Parse_error_exn (Errors.Type_error "(^^^ int int)")) )
  ; ( ">>>"
    , function
      | [ Object.Fixnum a; Object.Fixnum b ] ->
        Object.Fixnum (a lsl b)
      | _ ->
        raise (Errors.Parse_error_exn (Errors.Type_error "(>>> int int)")) )
  ; ( "<<<"
    , function
      | [ Object.Fixnum a; Object.Fixnum b ] ->
        Object.Fixnum (a lsr b)
      | _ ->
        raise (Errors.Parse_error_exn (Errors.Type_error "(<<< int int)")) )
    (* Comparison operators (still binary) *)
  ; Compare.generate "=" (fun (a : float) (b : float) -> Float.equal a b)
  ; Compare.generate "==" (fun (a : float) (b : float) -> Float.equal a b)
  ; ( "!="
    , function
      | [ Object.Fixnum a; Object.Fixnum b ] ->
        Object.Boolean (not (a = b))
      | [ Object.Float a; Object.Float b ] ->
        Object.Boolean (not (Float.equal a b))
      | [ Object.Fixnum a; Object.Float b ] ->
        Object.Boolean (not (Float.equal (float_of_int a) b))
      | [ Object.Float a; Object.Fixnum b ] ->
        Object.Boolean (not (Float.equal a (float_of_int b)))
      | _ ->
        raise (Errors.Parse_error_exn (Errors.Type_error "(!= number number)")) )
  ; Compare.generate "<" (fun (a : float) (b : float) -> Float.( < ) a b)
  ; Compare.generate ">" (fun (a : float) (b : float) -> Float.( > ) a b)
  ; Compare.generate ">=" (fun (a : float) (b : float) -> Float.( >= ) a b)
  ; Compare.generate "<=" (fun (a : float) (b : float) -> Float.( <= ) a b)
  ]
;;
