(* Package search path tests *)

open Core

module ML = Mlisp_module_loader.Module_loader

let test_default_search_includes_home_packages () =
  let paths = ML.default_search_paths () in
  Alcotest.(check bool)
    "home packages path exists"
    true
    (List.exists paths ~f:(fun p -> String.is_substring p ~substring:".mlisp"))

let test_package_search_paths_count () =
  (* Test that default search paths include expected entries *)
  let paths = ML.default_search_paths () in
  Alcotest.(check int)
    "should have at least 4 paths"
    4
    (List.length paths)

let test_suite = [
  ("package_search", [
      Alcotest.test_case "default_search_includes_home_packages" `Quick test_default_search_includes_home_packages;
      Alcotest.test_case "package_search_paths_count" `Quick test_package_search_paths_count;
    ])
]

let run () = Alcotest.run "test_package_search" test_suite

let () = run ()
