#!/usr/bin/env ocaml

let install () =
  [ "sudo rm -rf /usr/include/mlisp"
  ; "sudo mkdir /usr/include/mlisp"
  ; "sudo cp ./stdlib.mlisp /usr/include/mlisp"
  ; "dune build --profile release"
  ; "dune install"
  ]
  |> List.iter (fun command -> Sys.command command |> ignore)
;;

let uninstall () =
  [ "sudo rm -rf /usr/include/mlisp"; "dune uninstall" ]
  |> List.iter (fun command -> Sys.command command |> ignore)
;;

let build () =
  [ "dune build --profile release" ]
  |> List.iter (fun command -> Sys.command command |> ignore)
;;

let clean () =
  [ "dune clean" ] |> List.iter (fun command -> Sys.command command |> ignore)
;;

let test () =
  clean ();
  build ();
  [ "dune test" ] |> List.iter (fun command -> Sys.command command |> ignore)

let repl () =
  [ "dune exec mlisp" ] |> List.iter (fun command -> Sys.command command |> ignore)
;;

let _ =
  match Sys.argv |> Array.to_list with
  | _ :: "install" :: _ -> install ()
  | _ :: "uninstall" :: _ -> uninstall ()
  | _ :: "build" :: _ -> build ()
  | _ :: "test" :: _ -> test ()
  | _ :: "clean" :: _ -> clean ()
  | _ :: "repl" :: _ -> repl ()
  | _ -> print_endline "Unknow option"
;;
