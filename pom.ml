#!/usr/bin/env ocaml

let build () =
  [ "git submodule sync && git submodule update --init"
  ; "dune build --profile release"
  ; "cd extern/rlwrap && autoreconf --install && ./configure && make && sudo make \
     install && cd ../.."
  ]
  |> List.iter (fun command -> Sys.command command |> ignore)
;;

let install () =
  build ();
  [ "sudo rm -rf /usr/bin/origin_mlisp"
  ; "sudo mkdir /usr/include/mlisp"
  ; "sudo cp ./stdlib.mlisp /usr/include/mlisp"
  ; "sudo cp ./_build/default/bin/main.exe /usr/bin/origin_mlisp"
  ; "sudo chmod +x mlisp"
  ; "sudo cp mlisp /usr/bin/mlisp"
  ]
  |> List.iter (fun command -> Sys.command command |> ignore)
;;

let uninstall () =
  [ "sudo rm -rf /usr/bin/origin_mlisp /usr/bin/mlisp"
  ; "sudo rm -rf /usr/include/mlisp"
  ; "cd extern/rlwrap && sudo make uninstall && cd ../.."
  ]
  |> List.iter (fun command -> Sys.command command |> ignore)
;;

let clean () =
  [ "dune clean" ] |> List.iter (fun command -> Sys.command command |> ignore)
;;

let test () =
  clean ();
  build ();
  [ "dune test" ] |> List.iter (fun command -> Sys.command command |> ignore)
;;

let repl () =
  [ "./_build/default/bin/main.exe" ]
  |> List.iter (fun command -> Sys.command command |> ignore)
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
