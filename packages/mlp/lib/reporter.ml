(* Pretty Test Reporter *)

open Core

(** ANSI color codes *)
let green s = sprintf "\027[32m%s\027[0m" s
let red s = sprintf "\027[31m%s\027[0m" s
let bold s = sprintf "\027[1m%s\027[0m" s
let dim s = sprintf "\027[2m%s\027[0m" s

(** Format a single test result *)
let format_result (result : Test_runner.test_result) =
  let check = if result.passed then green "✓" else red "✗" in
  let name = if result.passed then result.test_name else red result.test_name in
  let module_prefix = if String.is_empty result.module_name then "" else result.module_name ^ " / " in
  sprintf "  %s %s%s\n" check module_prefix name

(** Format test summary *)
let format_summary total passed failed =
  let total_str = sprintf "%d test%s" total (if total = 1 then "" else "s") in
  let passed_str = green (sprintf "%d passed" passed) in
  let failed_str =
    if failed = 0 then "" else sprintf ", %s" (red (sprintf "%d failed" failed))
  in
  sprintf "\n%s: %s%s\n" total_str passed_str failed_str

(** Print test results with summary *)
let report results =
  if List.is_empty results then
    printf "  %s\n" (dim "(no tests ran)")
  else
    (* Print each test result *)
    List.iter results ~f:(fun r -> printf "%s" (format_result r));
    (* Calculate summary *)
    let total = List.length results in
    let passed = List.count results ~f:(fun r -> r.passed) in
    let failed = total - passed in
    printf "%s" (format_summary total passed failed);
    (* Exit with error code if any tests failed *)
    if failed > 0 then exit 1

(** Print header with test count *)
let report_header test_count =
  printf "\n%s\n" (bold (sprintf "running %d test%s" test_count (if test_count = 1 then "" else "s")))

(** Full report with header *)
let full_report results =
  let total = List.length results in
  if total > 0 then report_header total;
  report results
