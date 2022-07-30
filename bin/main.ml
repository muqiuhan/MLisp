(****************************************************************************)
(* OCamLisp                                                                 *)
(* Copyright (C) 2022 Muqiu Han                                             *)
(*                                                                          *)
(* This program is free software: you can redistribute it and/or modify     *)
(* it under the terms of the GNU Affero General Public License as published *)
(* by the Free Software Foundation, either version 3 of the License, or     *)
(* (at your option) any later version.                                      *)
(*                                                                          *)
(* This program is distributed in the hope that it will be useful,          *)
(* but WITHOUT ANY WARRANTY; without even the implied warranty of           *)
(* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            *)
(* GNU Affero General Public License for more details.                      *)
(*                                                                          *)
(* You should have received a copy of the GNU Affero General Public License *)
(* along with this program.  If not, see <https://www.gnu.org/licenses/>.   *)
(****************************************************************************)

open Mlisp.Reader
open Mlisp.Eval
open Mlisp.Environment
open Mlisp.Ast
open Mlisp.Types.Reader
open Mlisp.Types.Object

let get_input_channel () =
  try open_in Sys.argv.(1) with
  | Invalid_argument _ -> stdin
;;

let stdlib =
  let eval env e =
    match e with
    | Defexpr d -> eval_def d env
    | _ -> raise (Type_error_exn "Can only have definitions in stdlib")
  in
  let rec slurp stm env =
    try stm |> read_sexpr |> build_ast |> eval env |> snd |> slurp stm with
    | Stream.Failure -> env
  in
  let stm =
    make_stringstream
      "\n\
      \  (defun o (f g) (lambda (x) (f (g x))))\n\
      \  (setq caar (o car car))\n\
      \  (setq cadr (o car cdr))\n\
      \  (setq caddr (o cadr cdr))\n\
      \  (setq cadar (o car (o cdr car)))\n\
      \  (setq caddar (o car (o cdr (o cdr car))))\n\n\
      \  (setq cons pair)\n\n\
      \  (setq newline (int->char 10))\n\
      \  (setq space (int->char 32))\n\n\
      \  ; This is pretty awkward looking because we have no other way to sequence\n\
      \  ; operations. We have no begin, nothing.\n\
      \  (defun println (s)\n\
      \    (let ((ok (print s)))\n\
      \      (print newline)))\n\n\
      \  ; This is less awkward because we actually use ic and c.\n\
      \  (defun getline ()\n\
      \    (let* ((ic (getchar))\n\
      \           (c (int->char ic)))\n\
      \      (if (or (eq c newline) (eq ic ~1))\n\
      \        empty-symbol\n\
      \        (cat c (getline)))))\n\n\
      \  (defun null? (xs)\n\
      \    (eq xs '()))\n\n\
      \  (defun length (ls)\n\
      \    (if (null? ls)\n\
      \      0\n\
      \      (+ 1 (length (cdr ls)))))\n\n\
      \  (defun take (n ls)\n\
      \    (if (or (< n 1) (null? ls))\n\
      \      '()\n\
      \      (cons (car ls) (take (- n 1) (cdr ls)))))\n\n\
      \  (defun drop (n ls)\n\
      \    (if (or (< n 1) (null? ls))\n\
      \      ls\n\
      \      (drop (- n 1) (cdr ls))))\n\n\
      \  (defun merge (xs ys)\n\
      \    (if (null? xs)\n\
      \      ys\n\
      \      (if (null? ys)\n\
      \        xs\n\
      \        (if (< (car xs) (car ys))\n\
      \          (cons (car xs) (merge (cdr xs) ys))\n\
      \          (cons (car ys) (merge xs (cdr ys)))))))\n\n\
      \  (defun mergesort (ls)\n\
      \    (if (null? ls)\n\
      \      ls\n\
      \      (if (null? (cdr ls))\n\
      \        ls\n\
      \        (let* ((size (length ls))\n\
      \               (half (/ size 2))\n\
      \               (first (take half ls))\n\
      \               (second (drop half ls)))\n\
      \          (merge (mergesort first) (mergesort second))))))\n\
      \  "
  in
  slurp stm basis
;;

let rec repl a_stream env =
  if a_stream.stdin
  then (
    print_string "> ";
    flush stdout);
  let ast = build_ast (read_sexpr a_stream) in
  let result, env' = eval ast env in
  if a_stream.stdin then print_endline (string_object result);
  repl a_stream env'
;;

let () =
  let input_channel = get_input_channel () in
  try repl (make_filestream input_channel) stdlib with
  | Stream.Failure -> if input_channel <> stdin then close_in input_channel
;;
