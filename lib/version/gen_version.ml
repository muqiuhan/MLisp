#!/usr/bin/env ocaml

(* Script to generate version information at build time *)

let get_git_branch () =
  try
    let ic = Unix.open_process_in "git rev-parse --abbrev-ref HEAD" in
    let branch = String.trim (input_line ic) in
      close_in ic;
      branch
  with
  | _ ->
    "unknown"
;;

let get_git_commit () =
  try
    let ic = Unix.open_process_in "git rev-parse --short HEAD" in
    let commit = String.trim (input_line ic) in
      close_in ic;
      commit
  with
  | _ ->
    "unknown"
;;

let get_build_time () =
  let time = Unix.time () in
  let tm = Unix.localtime time in
    Printf.sprintf
      "%04d-%02d-%02d %02d:%02d %s"
      (tm.Unix.tm_year + 1900)
      (tm.Unix.tm_mon + 1)
      tm.Unix.tm_mday
      tm.Unix.tm_hour
      tm.Unix.tm_min
      (if tm.Unix.tm_hour < 12 then
         "AM"
       else
         "PM")
;;

let get_ocaml_version () =
  (* Try to get OCaml version from the running OCaml interpreter *)
  try Sys.ocaml_version with
  | _ -> (
    (* Fallback: try to parse from ocaml -version output *)
    try
      let ic = Unix.open_process_in "ocaml -version 2>&1" in
      let version_line = input_line ic in
        close_in ic;
        (* Extract version number from "The OCaml toplevel, version 5.2.1" *)
        let re = Str.regexp "version \\([0-9]+\\.[0-9]+\\.[0-9]+\\)" in
          if Str.string_match re version_line 0 then
            Str.matched_group 1 version_line
          else
            "unknown"
    with
    | _ ->
      "unknown")
;;

let get_version_from_dune_project () =
  "0.3.4" (* Default version, can be extracted from dune-project if needed *)
;;

let () =
  let version = get_version_from_dune_project () in
  let branch = get_git_branch () in
  let commit = get_git_commit () in
  let build_time = get_build_time () in
  let ocaml_version = get_ocaml_version () in
    Printf.printf
      "(****************************************************************************)\n";
    Printf.printf
      "(* This file is auto-generated at build time. Do not edit manually.          *)\n";
    Printf.printf
      "(****************************************************************************)\n";
    Printf.printf "\n";
    Printf.printf "(** Version information for MLisp.\n";
    Printf.printf "\n";
    Printf.printf
      "    This module contains version and build information that is generated\n";
    Printf.printf "    at build time from git repository state and system information.\n";
    Printf.printf "*)\n";
    Printf.printf "\n";
    Printf.printf "(** MLisp version number. *)\n";
    Printf.printf "let version = %S\n" version;
    Printf.printf "\n";
    Printf.printf "(** Git branch name at build time. *)\n";
    Printf.printf "let branch = %S\n" branch;
    Printf.printf "\n";
    Printf.printf "(** Git commit hash (short) at build time. *)\n";
    Printf.printf "let commit = %S\n" commit;
    Printf.printf "\n";
    Printf.printf "(** Build timestamp. *)\n";
    Printf.printf "let build_time = %S\n" build_time;
    Printf.printf "\n";
    Printf.printf "(** OCaml version used to build. *)\n";
    Printf.printf "let ocaml_version = %S\n" ocaml_version;
    Printf.printf "\n";
    Printf.printf "(** Format version string for display.\n";
    Printf.printf "\n";
    Printf.printf "    Returns a string in the format:\n";
    Printf.printf
      "    \"MLisp v<version> (<branch>, <build_time>) [OCaml <ocaml_version>]\"\n";
    Printf.printf "*)\n";
    Printf.printf "let version_string () =\n";
    Printf.printf "  Printf.sprintf \"MLisp v%%s (%%s, %%s) [OCaml %%s]\"\n";
    Printf.printf "    version branch build_time ocaml_version\n";
    Printf.printf "\n"
;;
