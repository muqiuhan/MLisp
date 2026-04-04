(* packages/interpreter/lib/error/error_context.ml *)
type location = {
  line : int;
  column : int;
  offset : int;
  file : string;
}

type error_context = {
  location : location;
  message : string;
  hints : string list;
}

let make_location ~line ~column ~file ?(offset=0) () = { line; column; offset; file }
let make ~location ~message ?(hints=[]) () = { location; message; hints }