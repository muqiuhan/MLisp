(* MLisp Package Manager Library *)

(** Package manager core types and utilities *)

(* Re-export Test_runner module *)
module Test_runner = Test_runner

(* Re-export Reporter module *)
module Reporter = Reporter

(* Re-export Installer module *)
module Installer = Installer

(** Error from test file execution *)
type test_error = {
  file_path : string;
  error_message : string;
}

(** Version constraint types *)
type version_constraint =
  | Eq of string           (* Exactly equal: =1.0.0 *)
  | Gt of string           (* Greater than: >1.0.0 *)
  | Gte of string          (* Greater than or equal: >=1.0.0 *)
  | Lt of string           (* Less than: <2.0.0 *)
  | Lte of string          (* Less than or equal: <=2.0.0 *)
  | Range of string * string  (* Range: >=1.0.0 & <2.0.0 *)
  | Any                       (* Any version: * *)

(** A dependency specification *)
type dependency = {
  pkg_name : string;
  constraint_ : version_constraint;
}

(** Build configuration - stores build script as s-expression *)
type build_config = {
  before : string option;
  after : string option;
}

(** Test configuration *)
type test_config = {
  files : string list;
  reporter : string;
}

(** Package metadata parsed from meta.mlisp *)
type package_meta = {
  name : string;
  version : string;
  description : string;
  dependencies : dependency list;
  build : build_config;
  test : test_config;
}

(** Package source types *)
type package_source =
  | Local of string
  | Remote of {
      url : string;
      ref_ : string;
    }

(** Resolved package *)
type package = {
  meta : package_meta;
  source : package_source;
  path : string;
}

(** Package database *)
type package_db = {
  installed : package list;
  local : package list;
  search_paths : string list;
}

(** Pretty print a version constraint *)
let string_of_constraint = function
  | Eq v -> "=" ^ v
  | Gt v -> ">" ^ v
  | Gte v -> ">=" ^ v
  | Lt v -> "<" ^ v
  | Lte v -> "<=" ^ v
  | Range (min, max) -> ">=" ^ min ^ " & <" ^ max
  | Any -> "*"

(** Pretty print a dependency *)
let string_of_dependency dep =
  Printf.sprintf "%s %s" dep.pkg_name (string_of_constraint dep.constraint_)

(** Pretty print a package *)
let string_of_package pkg =
  Printf.sprintf "%s v%s" pkg.meta.name pkg.meta.version

(** Create an empty package database *)
let empty_db () = {
  installed = [];
  local = [];
  search_paths = [
    "packages";
    Filename.concat (Option.value (Sys.getenv_opt "HOME") ~default:"/home/somhairle") (".mlisp" ^ Filename.dir_sep ^ "packages");
  ];
}

(** Log with formatting *)
let log_info msg = Core.Printf.printf "[INFO] %s\n" msg
let log_error msg = Core.Printf.printf "[ERROR] %s\n" msg
let log_success msg = Core.Printf.printf "[OK] %s\n" msg
