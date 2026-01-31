(****************************************************************************)
(* This Source Code Form is subject to the terms of the                     *)
(* Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed *)
(* with this file, You can obtain one at http://mozilla.org/MPL/2.0/.       *)
(****************************************************************************)

open Core
open Diagnose.Diagnose

type error_info =
  { file_name : string
  ; line_number : int
  ; column_number : int
  ; message : string
  ; help : string
  ; error_code : string option
  }

type t = error_info

(* Configure diagnose modules *)
module AnsiStyle = ConsoleAnsiStyle
module Doc = MakeAnnotatedDoc (AnsiStyle)
module Themes = MakeThemes (AnsiStyle)

module Report =
  MakeReport (AnsiStyle) (Doc)
    (struct
      let style = Themes.default_style
    end)

let rec repl_error ?(source_lines = []) : error_info -> unit =
  fun { file_name; line_number; column_number; message; help; error_code } ->
  let readonly_file_map =
    if List.is_empty source_lines then
      FilenameMap.empty
    else
      FilenameMap.singleton (Some file_name) (Array.of_list source_lines)
  in
  (* Calculate end column: if column_number is 0, use a default width of 1 *)
  let begin_col = max 1 column_number in
  let end_col = begin_col + 1 in
  (* Split help text into title, explanation, and solutions
     Format: "Title\n\nExplanation\n\nSolutions"
     We want: main_message = "Title\n\nSolutions"
              marker_message = "Explanation" *)
  let main_message, marker_message =
    let parts = String.split help ~on:'\n' in
      match parts with
      | title :: "" :: rest ->
        (* Find where "Possible solutions:" or similar starts *)
        let rec split_at_solutions acc = function
          | [] ->
            String.concat ~sep:"\n" (title :: "" :: List.rev acc), message
          | line :: rest
            when String.is_prefix line ~prefix:"Possible solutions:"
                 || String.is_prefix line ~prefix:"Example:"
                 || String.is_prefix line ~prefix:"Correct syntax:" ->
            let explanation = String.concat ~sep:" " (List.rev acc) in
            let solutions = String.concat ~sep:"\n" (line :: rest) in
            let main = [%string "%{title}\n\n%{solutions}"] in
              ( main
              , if String.is_empty explanation then
                  message
                else
                  explanation )
          | line :: rest ->
            split_at_solutions (line :: acc) rest
        in
          split_at_solutions [] rest
      | _ ->
        help, message
  in
  let report : string Report.t =
    { code = error_code
    ; message = main_message
    ; markers =
        [ ( { file = Some file_name
            ; begin_line = line_number
            ; end_line = line_number
            ; begin_col
            ; end_col
            }
          , This marker_message )
        ]
    ; blurbs = [ (* Hint help *) ]
    ; is_error = true
    }
  in
    Out_channel.output_string
      Out_channel.stderr
      (Report.pretty_report ~readonly_file_map ~with_unicode:true ~tab_size:4 report);
    Out_channel.newline Out_channel.stderr;
    Out_channel.flush Out_channel.stderr

and file_error : error_info -> unit =
  fun ({ file_name; line_number; column_number; message; help; error_code } as err_info) ->
  try
    let source_lines = In_channel.read_lines file_name in
    (* For "Not found: symbol" errors, try to find the symbol in source code *)
    let actual_line, actual_col =
      if String.is_prefix message ~prefix:"Not found: " then (
        let symbol_name = String.drop_prefix message (String.length "Not found: ") in
        (* Check if a position is in a comment (look backwards for ;; before this position on the line) *)
        let is_in_comment line pos =
          let rec check_comment i =
            if i < 0 then
              false
            else if
              i > 0
              && Char.(String.get line (i - 1) = ';')
              && Char.(String.get line i = ';')
            then
              true
            else if i >= 0 && Char.is_whitespace (String.get line i) then
              check_comment (i - 1)
            else
              false
          in
            check_comment (pos - 1)
        in
        (* Check if a line is a comment line (starts with ;; after whitespace) *)
        let is_comment_line line =
          let trimmed = String.strip line in
            String.is_prefix trimmed ~prefix:";;"
        in
        (* Search for the symbol in a specific line, returning optional position *)
        let find_symbol_in_line line_idx =
          if line_idx < 0 || line_idx >= List.length source_lines then
            None
          else (
            let line = List.nth_exn source_lines line_idx in
              (* Skip comment lines entirely *)
              if is_comment_line line then
                None
              else (
                let line_len = String.length line in
                let symbol_len = String.length symbol_name in
                let rec search_from pos =
                  if pos + symbol_len > line_len then
                    None
                  else (
                    (* Check if symbol matches at this position *)
                    let matches = ref true in
                      for i = 0 to symbol_len - 1 do
                        if
                          pos + i >= line_len
                          || Char.(String.get line (pos + i) <> String.get symbol_name i)
                        then
                          matches := false
                      done;
                      if !matches then (
                        (* Found potential match - check word boundaries and that it's not in a comment *)
                        let before =
                          if pos > 0 then
                            String.get line (pos - 1)
                          else
                            ' '
                        in
                        let after_pos = pos + symbol_len in
                        let after =
                          if after_pos < line_len then
                            String.get line after_pos
                          else
                            ' '
                        in
                        let is_word_char c = Char.is_alphanum c || Char.equal c '_' in
                          if
                            (not (is_in_comment line pos))
                            && (not (is_word_char before))
                            && not (is_word_char after)
                          then
                            (* Valid word boundary match, not in comment *)
                            Some (line_idx + 1, pos + 1)
                          else
                            (* Not a valid match, continue searching *)
                            search_from (pos + 1)
                      ) else
                        search_from (pos + 1)
                  )
                in
                  search_from 0
              )
          )
        in
        (* First, try to find lines containing "import" keyword, as Not_found errors
           often occur in import statements *)
        let find_import_lines () =
          let import_lines = ref [] in
            List.iteri source_lines ~f:(fun idx line ->
              if
                (not (is_comment_line line))
                && String.is_substring line ~substring:"import"
              then
                import_lines := idx :: !import_lines);
            List.rev !import_lines
        in
        (* Search in import lines first *)
        let import_lines = find_import_lines () in
        let rec search_import_lines = function
          | [] ->
            None
          | line_idx :: rest -> (
            match find_symbol_in_line line_idx with
            | Some pos ->
              Some pos
            | None ->
              search_import_lines rest)
        in
          match search_import_lines import_lines with
          | Some (found_line, found_col) ->
            found_line, found_col
          | None ->
            (* If not found in import lines, use general search strategy *)
            let rec search_around center_line offset =
              if offset > 10 then
                (* Give up and use reported position *)
                line_number, column_number
              else (
                (* Try line at offset before and after center *)
                let try_line = center_line + offset in
                  match find_symbol_in_line try_line with
                  | Some (found_line, found_col) ->
                    found_line, found_col
                  | None -> (
                    (* Also try line at negative offset *)
                    let try_line_neg = center_line - offset in
                      match find_symbol_in_line try_line_neg with
                      | Some (found_line, found_col) ->
                        found_line, found_col
                      | None ->
                        (* Continue searching with larger offset *)
                        search_around center_line (offset + 1))
              )
            in
              (* Start searching from the reported line *)
              search_around (line_number - 1) 0
      ) else
        line_number, column_number
    in
    let line_value = List.nth_exn source_lines (actual_line - 1) in
    let get_end_col line start_col =
      let len = String.length line in
      let start_idx = start_col - 1 in
        if start_idx < 0 || start_idx >= len then
          start_col + 1
        else (
          let rec find_end i =
            if i >= len then
              len
            else (
              match String.get line i with
              | ' '
              | '\t'
              | '\n'
              | '\r'
              | '('
              | ')' ->
                i
              | _ ->
                find_end (i + 1)
            )
          in
          let end_idx = find_end start_idx in
            if end_idx = start_idx then
              start_idx + 2
            else
              end_idx + 1
        )
    in
    let end_col = get_end_col line_value actual_col in
    let readonly_file_map =
      FilenameMap.singleton (Some file_name) (Array.of_list source_lines)
    in
    (* Use actual_col for begin_col, ensuring it's at least 1 *)
    let begin_col = max 1 actual_col in
    (* Split help text into title, explanation, and solutions
       Same logic as repl_error *)
    let main_message, marker_message =
      let parts = String.split help ~on:'\n' in
        match parts with
        | title :: "" :: rest ->
          let rec split_at_solutions acc = function
            | [] ->
              String.concat ~sep:"\n" (title :: "" :: List.rev acc), message
            | line :: rest
              when String.is_prefix line ~prefix:"Possible solutions:"
                   || String.is_prefix line ~prefix:"Example:"
                   || String.is_prefix line ~prefix:"Correct syntax:" ->
              let explanation = String.concat ~sep:" " (List.rev acc) in
              let solutions = String.concat ~sep:"\n" (line :: rest) in
              let main = [%string "%{title}\n\n%{solutions}"] in
                ( main
                , if String.is_empty explanation then
                    message
                  else
                    explanation )
            | line :: rest ->
              split_at_solutions (line :: acc) rest
          in
            split_at_solutions [] rest
        | _ ->
          help, message
    in
    let report : string Report.t =
      { code = error_code
      ; message = main_message
      ; markers =
          [ ( { file = Some file_name
              ; begin_line = actual_line
              ; end_line = actual_line
              ; begin_col
              ; end_col
              }
            , This marker_message )
          ]
      ; blurbs = [ (* Hint help *) ]
      ; is_error = true
      }
    in
      Out_channel.output_string
        Out_channel.stderr
        (Report.pretty_report ~readonly_file_map ~with_unicode:true ~tab_size:4 report);
      Out_channel.newline Out_channel.stderr;
      Out_channel.flush Out_channel.stderr
  with
  | _ ->
    repl_error ~source_lines:[] err_info
;;
