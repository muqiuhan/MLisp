(* packages/interpreter/lib/error/result.ml *)

type ('a, 'e) result = ('a, 'e) Stdlib.result = Ok of 'a | Error of 'e

let (>>=) (x : ('a, 'e) result) (f : 'a -> ('b, 'e) result) : ('b, 'e) result = Stdlib.Result.bind x f
let (>>|) (x : ('a, 'e) result) (f : 'a -> 'b) : ('b, 'e) result = Stdlib.Result.map f x
let return (x : 'a) : ('a, 'e) result = Ok x
let fail (e : 'e) : ('a, 'e) result = Error e
let map_error (t : ('a, 'e) result) ~(f : 'e -> 'f) : ('a, 'f) result = Stdlib.Result.map_error f t