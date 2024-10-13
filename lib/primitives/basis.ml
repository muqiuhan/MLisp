(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Mlisp_object

let basis =
  let newprim acc (name, func) = Object.bind (name, Object.Primitive (name, func), acc) in
      List.fold_left
        newprim
        [ "empty-symbol", ref (Some (Object.Symbol "")) ]
        [ Num.generate "+" ( + );
          Num.generate "-" ( - );
          Num.generate "*" ( * );
          Num.generate "/" ( / );
          Num.generate "mod" ( mod );
          Cmp.generate "=" ( = );
          Cmp.generate "<" ( < );
          Cmp.generate ">" ( > );
          Cmp.generate ">=" ( >= );
          Cmp.generate "<=" ( <= );
          "list", Core.list;
          "pair", Core.pair;
          "car", Core.car;
          "cdr", Core.cdr;
          "eq", Core.eq;
          "atom?", Core.atomp;
          "sym?", Core.symp;
          "getchar", Core.getchar;
          "print", Core.print;
          "int->char", Core.int_to_char;
          "cat", Core.cat
        ]
;;
