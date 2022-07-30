let exec_path = "../bin/main.exe"
let test_path = "../../../test/"

let is_mlisp_file file_name =
  match String.split_on_char '.' file_name with
  | _ :: ["mlisp"] -> true
  | _ -> false

let test_mlisp_file file_name =
  Sys.command (exec_path ^ " " ^ test_path ^ file_name) |> ignore

let test_files =
  test_path
  |> Sys.readdir
  |> Array.iter (
    fun file_name ->
      if is_mlisp_file file_name then (
        Printf.printf "Test %s ..." file_name;
        test_mlisp_file file_name;
        print_endline "done!"
      )
      else
        ()
  )
;;
