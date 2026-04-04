(* Pretty reporter tests - Alcotest suite *)

open Core
open Mlp_lib

let test_package_dir_creates_correct_path () =
  let dir = Installer.package_dir "my-pkg" in
  if not (String.is_suffix dir ~suffix:".mlisp/packages/my-pkg") then
    Alcotest.failf "Expected path to end with .mlisp/packages/my-pkg, got: %s" dir

let tests =
  [
    "package_dir creates correct path", `Quick, test_package_dir_creates_correct_path;
  ]
