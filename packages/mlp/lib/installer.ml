(* Package Installer *)

open Core

(** Get package installation directory *)
let package_dir pkg_name =
  let home = Option.value (Sys.getenv "HOME") ~default:"." in
  Filename.concat home (sprintf ".mlisp/packages/%s" pkg_name)

(** Install a local package by copying to ~/.mlisp/packages/ *)
let install_local src_path =
  let pkg_name = Filename.basename src_path in
  let dest = package_dir pkg_name in
  printf "Installing %s from %s...\n" pkg_name src_path;
  match Core_unix.system (sprintf "mkdir -p %s && cp -r %s/* %s/" dest src_path dest) with
  | Ok () -> 
    printf "Installed to %s\n" dest;
    Ok dest
  | Error _ -> 
    Or_error.errorf "Failed to install package"
