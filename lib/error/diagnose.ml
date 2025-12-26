(*  This work is licensed under the BSD-3 clause license.

    Copyright (c) 2021-2022 Mesabloo, all rights reserved. *)

(* DEVELOPER NOTE: This module was greatly assisted by AI translations of Haskell into OCaml!
   This is the first time I've done an AI translation ... please check carefully! *)

(** A module for pretty-printing error messages with source code in a
    user-friendly way, space preserving way.

    This pretty-printing is an OCaml implementation of the
    {{:https://github.com/Mesabloo/diagnose}Haskell diagnose package} by
    Mesabloo.

    {image:https://gitlab.com/dkml/build-tools/MlFront/-/raw/V2_4/images/MlFront_Thunk.Diagnose1.png?ref_type=heads}

    {3 Comparison to Fmlib_parse.Error_reporter}

    This module is similar to {!Fmlib_parse.Error_reporter} in that source code
    and error messages and locations are displayed. This module is not tied to
    parsing and can display colors. However, {!Fmlib_parse.Error_reporter} is
    preferred for CI as it displays more lines of context and has layout and
    wrapping. *)

open struct
  module Data = struct
    module List = struct
      module Safe = struct
        (** returns [None] on an empty list, instead of throwing an error.*)
        let safe_last lst =
          match List.rev lst with
          | [] ->
            None
          | x :: _ ->
            Some x
        ;;

        (** returns [None] in case of an empty list. *)
        let safe_head lst =
          match lst with
          | [] ->
            None
          | x :: _ ->
            Some x
        ;;

        (** does not throw an error on missing index. *)
        let safe_index n lst = List.nth_opt lst n [@@warning "-unused-value-declaration"]

        (** Safely deconstructs a list from the end. *)
        let safe_unsnoc lst =
          match List.rev lst with
          | [] ->
            None
          | x :: xs ->
            Some (List.rev xs, x)
        [@@warning "-unused-value-declaration"]
        ;;

        (** Safely deconstructs a list from the beginning, returning [None] if
              the list is empty. *)
        let safe_uncons lst =
          match lst with
          | [] ->
            None
          | x :: xs ->
            Some (x, xs)
        ;;
      end
    end
  end
end

(** This module exports all the needed data types to use this library. It should
      be sufficient to only [open Diagnose.Diagnose].

      {2 How to use this module}

      This library is intended to provide a very simple way of creating beautiful
      errors, by exposing a small yet simple API to the user.

      The basic idea is that a diagnostic is a collection of reports (which embody
      errors or warnings) along with the files which can be referenced in those
      reports.

      {2 Generating a report}

      A report contains:

      - A message, to be shown at the top

      - A list of located markers, used to underline parts of the source code and
        to emphasize it with a message

      - A list of hints, shown at the very bottom

      __Note__: The message type contained in a report is abstracted by a type
      variable. In order to render the report, the message must also be able to be
      rendered in some way (that we'll see later).

      This library allows defining two kinds of reports:

      - Errors, using 'Err'

      - Warnings, using 'Warn'

      Both take an optional error code, a message, a list of located markers and a
      list of hints.

      A minimal example is:

      {[
        module AnsiStyle = MlFront_Thunk.Diagnose.Diagnose.ConsoleAnsiStyle
        (** Configure your style renderer. Another option is ConsolePlainStyle. *)

        module Doc = MlFront_Thunk.Diagnose.Diagnose.MakeAnnotatedDoc (AnsiStyle)
        (** Configure your document monad. *)

        module Themes = MlFront_Thunk.Diagnose.Diagnose.MakeThemes (AnsiStyle)
        (** Configure your color theme. *)

        (** Make a report printer. *)
        module Report =
          MlFront_Thunk.Diagnose.Diagnose.MakeReport (AnsiStyle) (Doc)
            (struct
              let style = Themes.default_style
            end)

        (** Define a report. *)
        let example_report : string Report.t =
          {
            (* Optional error code. *)
            code = None;
            message = "This is my first error report";
            markers =
              [
                ( {
                    file = Some "some_test.txt";
                    begin_line = 1;
                    end_line = 1;
                    begin_col = 6;
                    end_col = 13;
                  },
                  This "Some text under the marker" );
              ];
            (* Hints and notes. *)
            blurbs = [];
            is_error = true;
          }

        (** Read the source code (ex. "some_test.txt"). *)
        let source =
          String.trim
            {|
        Twas brillig, and the slithy toves
        Did gyre and gimble in the wabe:
          All mimsy were the borogoves,
          And the mome raths outgrabe.|}

        (** Map the source code into lines. *)
        let readonly_file_map =
          let line_array = String.split_on_char '\n' source |> Array.of_list in
          MlFront_Thunk.Diagnose.Diagnose.FilenameMap.add (Some "some_test.txt")
            line_array MlFront_Thunk.Diagnose.Diagnose.FilenameMap.empty

        (* Print the report. *)
        let () =
          print_endline
            (Report.pretty_report ~readonly_file_map ~with_unicode:true
               ~tab_size:4 example_report)
      ]}

      That produces:

      {v
        [error]: This is my first error report

            ╭──▶ some_test.txt
            │
          1 │Twas brillig, and the slithy toves
            •     ┬──────
            •     ╰╸ Some text under the marker
        ────╯
      v}

      In general, 'Position's are returned by either a lexer or a parser, so that
      you never have to construct them directly in the code.

      __Note__: If using any parser library, you will have to convert from the
      internal positioning system to a 'Position' to be able to use this library.

      Markers put in the report can be one of (the colors specified are used only
      when pretty-printing):

      - A 'Error.Diagnose.Report.This' marker, which is the primary marker of the
        report. While it is allowed to have multiple of these inside one report,
        it is encouraged not to, because the position at the top of the report
        will only be the one of the /first/ 'Error.Diagnose.Report.This' marker,
        and because the resulting report may be harder to understand. This marker
        is output in red in an error report, and yellow in a warning report.

      - A 'Error.Diagnose.Report.Where' marker contains additional
        information\/provides context to the error\/warning report. For example,
        it may underline where a given variable [@x@] is bound to emphasize it.
        This marker is output in blue.

      - A 'Error.Diagnose.Report.Maybe' marker may contain possible fixes (if the
        text is short, else hints are recommended for this use). This marker is
        output in magenta.

      - A 'Error.Diagnose.Report.Blank' marker is useful only to output additional
        lines of code in the report. This marker is not output and has no color.

      {2 Creating diagnostics from reports}

      To create a new diagnostic, you need to use its 'Data.Default.Default'
      instance (which exposes a 'def' function, returning a new empty
      'Diagnostic'). Once the 'Diagnostic' is created, you can use either
      'addReport' (which takes a 'Diagnostic' and a 'Report', abstract by the same
      message type, and returns a 'Diagnostic') to insert a new report inside the
      diagnostic, or 'addFile' (which takes a 'Diagnostic', a 'FilePath' and a
      [String], and returns a 'Diagnostic') to insert a new file reference in the
      diagnostic.

      You can then either pretty-print the diagnostic obtained (which requires all
      messages to be instances of the 'Prettyprinter.Pretty') -- directly onto a
      file handle or as a plain 'Prettyprinter.Doc'ument -- or export it to a lazy
      JSON 'Data.Bytestring.Lazy.ByteString' (e.g. in a LSP context).

      {3 Pretty-printing a diagnostic}

      'Diagnostic's can be output using the 'printDiagnostic' function. This
      function takes several parameters:

      - The 'AnsiSyle' onto which to output the 'Diagnostic'.

      - A 'Bool' used to indicate whether you want to output the 'Diagnostic' with
        unicode characters, or simple ASCII characters.

      {v
           Here are two examples of the same diagnostic, the first output with unicode characters, and the second output with ASCII characters:

           > [error]: Error with one marker in bounds
           >      ╭──▶ test.zc@1:25-1:30
           >      │
           >    1 │ let id<a>(x : a) : a := x + 1
           >      •                         ┬────
           >      •                         ╰╸ Required here
           > ─────╯

           > [error]: Error with one marker in bounds
           >      +--> test.zc@1:25-1:30
           >      |
           >    1 | let id<a>(x : a) : a := x + 1
           >      :                         ^----
           >      :                         `- Required here
           > -----+
      v}

      - A 'Bool' set to 'False' if you don't want colors in the end result.

      - A 'Int' describing the number of spaces with which to output a TAB
        character.

      - The [Style] describing colors of the report. See the module
        "Error.Diagnose.Style" for how to define new styles.

      - And finally the 'Diagnostic' to output.

      {3 Pretty-printing a diagnostic as a document}

      'Diagnostic's can be “output” (at least ready to be rendered) to a
      'Prettyprinter.Doc' using 'prettyDiagnostic', which allows it to be easily
      added to other 'Prettyprinter.Doc' outputs. This makes it easy to customize
      the error messages further (though not the internal parts, only adding to
      it). As a 'Prettyprinter.Doc', there is also the possibility of altering
      internal annotations (styles) much easier (although this is already possible
      when printing the diagnostic).

      The arguments of the function mostly follow the ones from 'printDiagnostic'.
      The style is not one, as it can be applied by simply applying the styling
      function to the resulting function (if wanted).

      {3 Exporting a diagnostic to JSON}

      'Diagnostic's can be exported to a JSON record of the following type, using
      the 'diagnosticToJson' function:

      {v
       { files:
           { name: string
           , content: string[]
           }[]
       , reports:
           { kind: 'error' | 'warning'
           , code: string?
           , message: string
           , markers:
               { kind: 'this' | 'where' | 'maybe'
               , position:
                   { beginning: { line: int, column: int }
                   , end: { line: int, column: int }
                   , file: string
                   }
               , message: string
               }[]
           , hints: ({ note: string } | { hint: string })[]
           }[]
       }
      v}

      This is particularly useful in the context of a LSP server, where outputting
      or parsing a raw error yields strange results or is unnecessarily
      complicated.

      Please note that this requires the flag [diagnose:json] to be enabled. *)
module Diagnose = struct
  type ansi_color =
    | Red
    | Yellow
    | Green
    | Blue
    | Magenta
    | Cyan
    | Black
    | White

  (** A builder of a stream of ANSI escape sequences, or HTML
        ["<span class=\"red\">...</span>"] tags, or whatever control elements are
        required for the medium (console, HTML, etc.) you are writing to. *)
  module type ANSI_STYLE = sig
    type 'a t

    val mempty : 'a t
    val text : string -> 'a t

    (** A new line. The color should always be reset on a hardline. *)
    val hardline : 'a t

    (** Returns [true] if the given piece is a hardline. *)
    val is_hardline : 'a t -> bool

    val concat : 'a t -> 'a t -> 'a t
    val color : ansi_color -> 'a t
    val color_dull : ansi_color -> 'a t

    (** Changes the {!color} or {!color_dull} that immediately follows the
          [bold] to a bold color.

          A {!color} or {!color_dull} that does not have a immediately preceding
          {!bold} is styled as a regular color.*)
    val bold : 'a t

    (** Converts the [AnsiStyle.t] into a buffer, for outputting. *)
    val output : Buffer.t -> 'a t list -> unit

    (** The newline token used when outputting. *)
    val newline : string
  end

  open struct
    let trim_right s =
      let l = String.length s in
      let rec aux_len i =
        if i < 0 then
          0
        else (
          match s.[i] with
          | ' '
          | '\t'
          | '\r'
          | '\n' ->
            aux_len (i - 1)
          | _ ->
            i + 1
        )
      in
      let new_l = aux_len (l - 1) in
        String.sub s 0 new_l
    ;;
  end

  (** A style for the console without any colors. *)
  module ConsolePlainStyle : ANSI_STYLE = struct
    type 'a t = 'a piece list

    and 'a piece =
      | Content of { value : string }
      | Hardline

    let newline = "\n"
    let mempty = []
    let text v = [ Content { value = v } ]
    let hardline = [ Hardline ]

    let is_hardline = function
      | [ Hardline ] ->
        true
      | _ ->
        false
    ;;

    let concat = List.append
    let color _color = []
    let color_dull _color = []
    let bold = []

    let output buf pieces =
      let rec aux = function
        | [] ->
          ()
        | Content { value } :: Hardline :: rest ->
          (* Trim the right whitespace before the end of the line. *)
          Buffer.add_string buf (trim_right value);
          Buffer.add_string buf newline;
          aux rest
        | Content { value } :: rest ->
          Buffer.add_string buf value;
          aux rest
        | Hardline :: rest ->
          Buffer.add_string buf newline;
          aux rest
      in
        aux (List.concat pieces)
    ;;
  end

  (** A style for the console with colors as ANSI escape codes. *)
  module ConsoleAnsiStyle : ANSI_STYLE = struct
    type 'a t = 'a piece list

    and 'a piece =
      | Content of { value : string }
      | Hardline
      | Color of ansi_color
      | ColorDull of ansi_color
      | Bold

    let mempty = []
    let text v = [ Content { value = v } ]
    let hardline = [ Hardline ]

    let is_hardline = function
      | [ Hardline ] ->
        true
      | _ ->
        false
    ;;

    let concat = List.append
    let color color = [ Color color ]
    let color_dull color = [ ColorDull color ]
    let bold = [ Bold ]

    let onecode code buf =
      Buffer.add_string buf "\x1b[";
      Buffer.add_string buf code;
      Buffer.add_string buf "m"
    ;;

    let styledcode style code buf =
      Buffer.add_string buf "\x1b[";
      Buffer.add_string buf style;
      Buffer.add_string buf ";";
      Buffer.add_string buf code;
      Buffer.add_string buf "m"
    ;;

    let resetstyle = onecode "0"

    let colorcode ~is_bold_preceding ~is_faint buf =
      (* A bold faint is treated as regular. *)
      match is_bold_preceding, is_faint with
      | false, false
      | true, true -> begin
        function
        | Black ->
          styledcode "0" "30" buf
        | Red ->
          styledcode "0" "31" buf
        | Yellow ->
          styledcode "0" "33" buf
        | Green ->
          styledcode "0" "32" buf
        | Blue ->
          styledcode "0" "34" buf
        | Magenta ->
          styledcode "0" "35" buf
        | Cyan ->
          styledcode "0" "36" buf
        | White ->
          styledcode "0" "37" buf
      end
      | true, false -> begin
        function
        | Black ->
          styledcode "1" "30" buf
        | Red ->
          styledcode "1" "31" buf
        | Green ->
          styledcode "1" "32" buf
        | Yellow ->
          styledcode "1" "33" buf
        | Blue ->
          styledcode "1" "34" buf
        | Magenta ->
          styledcode "1" "35" buf
        | Cyan ->
          styledcode "1" "36" buf
        | White ->
          styledcode "1" "37" buf
      end
      | false, true -> begin
        function
        | Black ->
          styledcode "2" "30" buf
        | Red ->
          styledcode "2" "31" buf
        | Green ->
          styledcode "2" "32" buf
        | Yellow ->
          styledcode "2" "33" buf
        | Blue ->
          styledcode "2" "34" buf
        | Magenta ->
          styledcode "2" "35" buf
        | Cyan ->
          styledcode "2" "36" buf
        | White ->
          styledcode "2" "37" buf
      end
    ;;

    let newline = "\n"

    let output buf pieces =
      let rec aux is_bold_preceding = function
        | [] ->
          ()
        | Content { value } :: Hardline :: rest ->
          (* Trim the right whitespace before the end of the line. *)
          Buffer.add_string buf (trim_right value);
          Buffer.add_string buf newline;
          aux false rest
        | Content { value } :: rest ->
          Buffer.add_string buf value;
          aux false rest
        | Hardline :: rest ->
          Buffer.add_string buf newline;
          resetstyle buf;
          aux false rest
        | Color color :: rest ->
          colorcode ~is_bold_preceding ~is_faint:false buf color;
          aux false rest
        | ColorDull color :: rest ->
          colorcode ~is_bold_preceding ~is_faint:true buf color;
          aux false rest
        | Bold :: rest ->
          aux true rest
      in
        resetstyle buf;
        aux false (List.concat pieces)
    ;;
  end

  (** [Annotation]s are used when creating a [Doc]ument and are simply
        placeholders to specify custom colors. [AnsiStyle] is the concrete
        annotation to specify custom colors when rendering a [Doc]ument. *)
  module Annotation = struct
    (** Some annotations as placeholders for colors in a [Doc]. *)
    type 'a t =
      | ThisColor of bool
      (** The color of 'Error.Diagnose.Report.This' markers, depending on
                whether the report is an error report or a warning report. *)
      | MaybeColor (** The color of 'Error.Diagnose.Report.Maybe' markers. *)
      | WhereColor (** The color of 'Error.Diagnose.Report.Where' markers. *)
      | HintColor (** The color for hints. *)
      | FileColor (** The color for file names. *)
      | RuleColor
      (** The color of the rule separating the code/markers from the line
                numbers. *)
      | KindColor of bool
      (** The color of the @[error]@/@[warning]@ at the top, depending on whether this is an error or warning report. *)
      | NoLineColor
      (** The color in which to output the @<no line>@ information when the file was not found. *)
      | MarkerStyle of 'a t
      (** Additional style to apply to marker rules (e.g. bold) on top of
                some already processed color annotation. *)
      | CodeStyle (** The color of the code when no marker is present. *)
      | OtherStyle of 'a (** Something else, could be provided by the user. *)
  end

  (** A maker of types for annotated (ie. styled) documents. *)
  module MakeAnnotatedDoc (AnsiStyle : ANSI_STYLE) = struct
    type ('a, 'u) annotated_block = 'a AnsiStyle.t * 'u Annotation.t
    type ('a, 'u) annotated_doc = ('a, 'u) annotated_block list
  end

  (** Custom style definitions.

        {1 Defining new style}

        Defining new color styles (one may call them "themes") is actually rather
        easy.

        A [Style] is a function from an annotated [Doc]ument to another annotated
        [Doc]ument. Note that only the annotation type changes, hence the need of
        only providing a unidirectional mapping between those.

        [Annotation]s are used when creating a [Doc]ument and are simply
        placeholders to specify custom colors. [AnsiStyle] is the concrete
        annotation to specify custom colors when rendering a [Doc]ument.

        One may define additional styles as follows:

        {v
          myNewCustomStyle :: Style
          myNewCustomStyle = reAnnotate \case
            -- all cases for all annotations
        v}

        For simplicity's sake, a default style is given as {!default_style}. *)
  module MakeThemes (AnsiStyle : ANSI_STYLE) = struct
    include MakeAnnotatedDoc (AnsiStyle)

    (** A style is a function which can be applied using {!reannotate}. *)
    type ('a, 'b, 'u) t = ('a, 'u) annotated_block -> 'b AnsiStyle.t

    let reannotate : ('a, 'b, 'u) t -> ('a, 'u) annotated_doc -> ('b, 'u) annotated_doc =
      fun style doc ->
      List.map
        (fun ((_, ann) as block : ('a, 'u) annotated_block) ->
           let x : ('b, 'u) annotated_block = style block, ann in
             x)
        doc
    ;;

    (** A style which disregards all annotations. *)
    let unadorned_style : ('a, 'b, 'c) t =
      fun (a, ann) ->
      ignore ann;
      a
    ;;

    (** The default style for diagnostics, where:

          - 'Error.Diagnose.Report.This' markers are colored in red for errors and yellow for warnings
          - 'Error.Diagnose.Report.Where' markers are colored in dull blue
          - 'Error.Diagnose.Report.Maybe' markers are colored in magenta
          - Marker rules are of the same color of the marker, but also in bold
          - Hints are output in cyan
          - The left rules are colored in bold black
          - File names are output in dull green
          - The @[error]@/@[warning]@ at the top is colored in red for errors and yellow for warnings
          - The code is output in normal white *)
    let rec default_style : ('a, 'b, 'b) t =
      let open AnsiStyle in
      let ( <> ) = concat in
        fun (a, ann) ->
          match ann with
          | ThisColor isError ->
            color
              (if isError then
                 Red
               else
                 Yellow)
            <> a
          | MaybeColor ->
            color Magenta <> a
          | WhereColor ->
            color_dull Blue <> a
          | HintColor ->
            color Cyan <> a
          | FileColor ->
            bold <> color_dull Green <> a
          | RuleColor ->
            bold <> color Black <> a
          | KindColor isError ->
            bold <> default_style (a, ThisColor isError)
          | NoLineColor ->
            bold <> color_dull Magenta <> a
          | MarkerStyle st ->
            let ann = default_style (a, st) in
              if ann = default_style (a, CodeStyle) then
                ann
              else
                bold <> ann
          | CodeStyle ->
            color White <> a
          | OtherStyle _ ->
            a
    ;;
  end

  (** An optional file name. *)
  module MaybeFilename = struct
    (** A type for an optional file name. It is used to specify the file name
          associated with a diagnostic report. *)
    type t = string option

    let to_string = function
      | None ->
        "<no file>"
      | Some s ->
        s
    ;;

    let compare p1 p2 =
      match p1, p2 with
      | None, None ->
        0
      | None, Some _ ->
        -1
      | Some _, None ->
        1
      | Some f1, Some f2 ->
        String.compare f1 f2
    ;;
  end

  (** A map from file names to their contents. *)
  module FilenameMap = Map.Make (MaybeFilename)
  (** A map from file names to their contents. This is used to store the files
        referenced in a diagnostic. *)

  (** Report definition and pretty printing. *)
  module MakeReport
      (AnsiStyle : ANSI_STYLE)
      (Doc : module type of MakeAnnotatedDoc (AnsiStyle))
         (Theme : sig
            val style : (string, string) Doc.annotated_block -> string AnsiStyle.t
          end) : sig
      type 'msg t =
        { markers : (position * 'msg marker) list
          (** A map associating positions with marker to show under the source
                code. *)
        ; is_error : bool (** Is the report a warning or an error? *)
        ; code : string option (** An optional error code to print at the top. *)
        ; message : string (** The message associated with the error. *)
        ; blurbs : blurb list
          (** A list of notes, hints, and expectations to add at the end of the
                report. *)
        }

      and blurb =
        | Note of string
        | Hint of string
        | Expectation of (string * string)

      (** The type of positions in source code. All lines and columns are 1-based.
          It is used to specify where a marker should be placed. *)
      and position =
        { file : string option (** The file name, if available. *)
        ; begin_line : int (** Beginning line number. 1-based. *)
        ; end_line : int (** Ending line number. 1-based. *)
        ; begin_col : int (** Beginning column number. 1-based. *)
        ; end_col : int (** Ending column number. 1-based. *)
        }

      (** The type of markers used in reports. It is abstracted by a type variable
          ['msg] to allow for different message types. *)
      and 'msg marker =
        | This of 'msg
        (** A red or yellow marker under source code, marking important parts
                of the code. *)
        | Where of 'msg (** A blue marker symbolizing additional information. *)
        | Maybe of 'msg (** A magenta marker to report potential fixes. *)
        | Blank
        (** An empty marker, whose sole purpose is to include a line of code
                in the report without markers under. *)

      val pretty_report
        :  readonly_file_map:string array FilenameMap.t
        -> with_unicode:bool
        -> tab_size:int
        -> string t
        -> string
    end =
    struct
    include MakeAnnotatedDoc (AnsiStyle)

    let annotate ann s = AnsiStyle.text s, ann

    let annotate_doc ann (d : (string, 'a) annotated_doc) : (string, 'a) annotated_doc =
      List.map (fun (s, _existing_ann) -> s, ann) d
    ;;

    (** Concatenation operator. *)
    let ( <^> )
      :  (string, 'a) annotated_doc
      -> (string, 'a) annotated_doc
      -> (string, 'a) annotated_doc
      =
      fun doc1 doc2 -> doc1 @ doc2
    ;;

    (** Align operator. We don't support it yet (it requires a layout engine
          that operates on annotated doc untroubled by zero-width ANSI escape
          codes), so we just concatenate a left, space and the right. *)
    let ( <+> )
      :  (string, 'a) annotated_doc
      -> (string, 'a) annotated_doc
      -> (string, 'a) annotated_doc
      =
      fun doc1 doc2 -> doc1 @ [ annotate Annotation.CodeStyle " " ] @ doc2
    ;;

    let mempty = [ AnsiStyle.mempty, Annotation.CodeStyle ]

    let debugstyle (s : string) : (string, 'a) annotated_doc =
      ignore s;
      mempty
    ;;

    (* [ annotate Annotation.CodeStyle s ] *)

    let codestyle (s : string) : (string, 'a) annotated_doc =
      [ annotate Annotation.CodeStyle s ]
    ;;

    let rulecolor (s : string) : (string, 'a) annotated_doc =
      [ annotate Annotation.RuleColor s ]
    ;;

    let hintcolor (s : string) : (string, 'a) annotated_doc =
      [ annotate Annotation.HintColor s ]
    ;;

    let filecolor (s : string) : (string, 'a) annotated_doc =
      [ annotate Annotation.FileColor s ]
    ;;

    let kindcolor kind (s : string) : (string, 'a) annotated_doc =
      [ AnsiStyle.text s, Annotation.KindColor kind ]
    ;;

    let hardline = [ AnsiStyle.hardline, Annotation.CodeStyle ]
    let space = codestyle " "

    (** The type of diagnostic reports with abstract message type ['msg]. *)
    type 'msg t =
      { markers : (position * 'msg marker) list
        (** A map associating positions with marker to show under the source
                code. *)
      ; is_error : bool (** Is the report a warning or an error? *)
      ; code : string option (** An optional error code to print at the top. *)
      ; message : string (** The message associated with the error. *)
      ; blurbs : blurb list
      }

    and position =
      { file : string option
      ; begin_line : int
      ; end_line : int
      ; begin_col : int
      ; end_col : int
      }

    (** The type of markers used in reports. It is abstracted by a type variable
          ['msg] to allow for different message types. *)
    and 'msg marker =
      | This of 'msg
      (** A red or yellow marker under source code, marking important parts
                of the code. *)
      | Where of 'msg (** A blue marker symbolizing additional information. *)
      | Maybe of 'msg (** A magenta marker to report potential fixes. *)
      | Blank
      (** An empty marker, whose sole purpose is to include a line of code
                in the report without markers under. *)

    and blurb =
      | Note of string
      | Hint of string
      | Expectation of (string * string)
      (** The type of blurbs used in reports. It can be a note, a hint, or a
                labelled expectation [(label,expectation)]. *)

    let string_repeat n s =
      let b = Buffer.create (String.length s * n) in
      let rec aux n =
        if n <= 0 then
          Buffer.contents b
        else (
          Buffer.add_string b s;
          aux (n - 1)
        )
      in
        aux n
    ;;

    let markerstyle = function
      | This _ ->
        Annotation.ThisColor true
      | Where _ ->
        Annotation.WhereColor
      | Maybe _ ->
        Annotation.MaybeColor
      | Blank ->
        Annotation.CodeStyle
    ;;

    let rec pretty_report ~readonly_file_map ~with_unicode ~tab_size report =
      let sorted_markers =
        List.sort
          (fun (p1, _) (p2, _) ->
             let cmp_file = MaybeFilename.compare p1.file p2.file in
               if cmp_file <> 0 then
                 cmp_file
               else
                 compare p1.begin_line p2.begin_line)
          report.markers
      in
      let grouped_markers = group_markers_per_file sorted_markers in
      let max_line_number_length =
        match List.rev report.markers with
        | [] ->
          3
        | (p, _) :: _ ->
          max 3 (String.length (string_of_int p.end_line))
      in
      (*
         A report is of the form:
            (1)    [error|warning]: <message>
            (2)           +--> <file>
            (3)           :
            (4)    <line> | <line of code>
                          : <marker lines>
                          : <marker messages>
            (5)           :
                          : <hints>
            (6)    -------+
      *)
      let header =
        let kc = kindcolor report.is_error in
        let kind =
          if report.is_error then
            "error"
          else
            "warning"
        in
        let code =
          match report.code with
          | None ->
            mempty
          | Some c ->
            space <^> kc c
        in
          kc "[" <^> kc kind <^> code <^> kc "]"
      in
      let reportdoc =
        (* 1 *)
        header
        <^> codestyle ":"
        <^> space
        <^> codestyle report.message
        <^> hardline
        <^> debugstyle "?1"
        <^>
        (* (2), (3), (4) *)
        List.fold_right
          (fun (is_first, markers) report_acc ->
             pretty_sub_report
               ~readonly_file_map
               ~with_unicode
               ~is_error:report.is_error
               ~tab_size
               ~max_line_number_length
               ~is_first
               markers
             <^> report_acc)
          grouped_markers
          mempty
        <^> debugstyle "?9"
        <^>
        (* (5) *)
        (if report.blurbs = [] && report.markers = [] then
           mempty
         else if report.blurbs = [] then
           mempty
         else
           hardline <^> dot_prefix max_line_number_length with_unicode)
        <^> pretty_all_hints report.blurbs max_line_number_length with_unicode
        <^> hardline
        <^>
        (* (6) *)
        if report.markers = [] && report.blurbs = [] then
          mempty
        else
          rulecolor
            (pad_with_width1_string
               (* The -1 is to account for the lack of <+> align in the line number padding *)
               (max_line_number_length + 2 - 1)
               (if with_unicode then
                  "─"
                else
                  "-")
               "")
          <^> rulecolor
                (if with_unicode then
                   "╯"
                 else
                   "+")
          <^> hardline
      in
      let buf = Buffer.create 256 in
      let styled_blocks = List.map Theme.style reportdoc in
        AnsiStyle.output buf styled_blocks;
        Buffer.contents buf

    and pretty_all_hints hints left_len with_unicode =
      if hints = [] then
        mempty
      else (
        let expectation_label_width =
          List.fold_left
            (fun acc blurb ->
               match blurb with
               | Expectation (label, _expectation) ->
                 max acc (String.length label)
               | _ ->
                 acc)
            0
            hints
        in
          List.fold_left
            (fun acc blurb ->
               let prefix = pipe_prefix left_len with_unicode in
               let noteprefix =
                 match blurb with
                 | Note _ ->
                   "Note:"
                 | Hint _ ->
                   "Hint:"
                 | Expectation _ ->
                   ""
               in
               let msg =
                 match blurb with
                 | Expectation (label, expectation) ->
                   codestyle (pad (expectation_label_width - String.length label) ' ' " ")
                   <^> codestyle label
                   <^> space
                   <^> hintcolor expectation
                 | Note m
                 | Hint m ->
                   hintcolor noteprefix
                   <^> space
                   <^> annotate_doc
                         Annotation.HintColor
                         (replace_lines_with ~repl:prefix 7 (codestyle m))
               in
                 hardline <^> prefix <+> msg <^> acc)
            mempty
            hints
      )

    (* Utility functions *)

    and pad n c s =
      let len = String.length s in
        if len >= n then
          s
        else
          s ^ String.make (n - len) c

    and pad_with_width1_string n stringy_char s =
      let len = String.length s in
        if len >= n then
          s
        else
          s ^ string_repeat (n - len) stringy_char

    and dot_prefix left_len with_unicode =
      codestyle (pad left_len ' ' "")
      <+> rulecolor
            (if with_unicode then
               "•"
             else
               ":")

    and pipe_prefix left_len with_unicode : (string, 'a) annotated_doc =
      codestyle (pad left_len ' ' "")
      <+> rulecolor
            (if with_unicode then
               "│"
             else
               "|")

    and line_prefix left_len line_no with_unicode =
      let line_no_str = string_of_int line_no in
      let line_no_len = String.length line_no_str in
        rulecolor (pad (left_len - line_no_len) ' ' "")
        <^> rulecolor line_no_str
        <+> rulecolor
              (if with_unicode then
                 "│"
               else
                 "|")

    and ellipsis_prefix left_len with_unicode =
      rulecolor (pad left_len ' ' "")
      <+> rulecolor
            (if with_unicode then
               "⋮"
             else
               "...")
    [@@warning "-unused-value-declaration"]

    and group_markers_per_file markers =
      let tbl = Hashtbl.create 4 in
        List.iter
          (fun (p, m) ->
             let l =
               try Hashtbl.find tbl p.file with
               | Not_found ->
                 []
             in
               Hashtbl.replace tbl p.file ((p, m) :: l))
          markers;
        let files = Hashtbl.fold (fun k v acc -> (k, List.rev v) :: acc) tbl [] in
        let sorted =
          List.sort
            (fun (_, ms1) (_, ms2) ->
               let has_this1 = List.exists (fun (_, m) -> is_this_marker m) ms1 in
               let has_this2 = List.exists (fun (_, m) -> is_this_marker m) ms2 in
                 match has_this1, has_this2 with
                 | true, false ->
                   -1
                 | false, true ->
                   1
                 | _ ->
                   0)
            files
        in
        let rec tag_first acc = function
          | [] ->
            List.rev acc
          | (_file, ms) :: xs ->
            let is_first = acc = [] in
              tag_first ((is_first, ms) :: acc) xs
        in
          tag_first [] sorted

    and is_this_marker = function
      | This _ ->
        true
      | _ ->
        false

    and split_markers_per_line markers =
      let tbl = Hashtbl.create 8 in
      let multiline = ref [] in
        List.iter
          (fun (p, m) ->
             if p.begin_line = p.end_line then (
               let l =
                 try Hashtbl.find tbl p.begin_line with
                 | Not_found ->
                   []
               in
                 Hashtbl.replace tbl p.begin_line ((p, m) :: l)
             ) else
               multiline := (p, m) :: !multiline)
          markers;
        tbl, List.rev !multiline

    (** [pretty_sub_report ~readonly_file_map ~with_unicode ~is_error ~tab_size
           ~max_line_number_length ~is_first markers] pretty-prints a sub-report,
          which is a part of the report spanning across a single file.

          [~readonly_file_map]: The content of files in the diagnostics

          [~with_unicode]: Is the output done with Unicode characters?

          [~is_error]: Is the current report an error report?

          [~tab_size]: The number of spaces each TAB character will span

          [~max_line_number_length]: The size of the biggest line number

          [~is_first]: Is this sub-report the first one in the list?

          [markers]: The list of line-ordered markers appearing in a single file
      *)
    and pretty_sub_report
          ~readonly_file_map
          ~with_unicode
          ~is_error
          ~tab_size
          ~max_line_number_length
          ~is_first
          markers
      : (string, string) annotated_doc
      =
      let markers_per_line, multiline_markers = split_markers_per_line markers in
      let sorted_lines =
        Hashtbl.fold (fun k v acc -> (k, v) :: acc) markers_per_line []
        |> List.sort (fun (a, _) (b, _) -> compare a b)
      in
      (* the reported file is the file of the first 'This' marker (only one must be present) *)
      let report_file =
        let this_markers =
          List.filter_map
            (fun (pos, m) ->
               match m with
               | This s ->
                 Some (pos, s)
               | _ ->
                 None)
            markers
        in
          match
            Data.List.Safe.safe_head
              (List.sort (fun (_, m1) (_, m2) -> String.compare m1 m2) this_markers)
          with
          | Some (p, _) ->
            Some (pretty_position p)
          | None ->
            None
      in
      let file_marker =
        match report_file with
        | None ->
          mempty
        | Some report_file ->
          (if is_first then
             space
             <^> codestyle (pad max_line_number_length ' ' "")
             <^> rulecolor
                   (if with_unicode then
                      "╭──▶"
                    else
                      "+-->")
           else
             space
             <^> dot_prefix max_line_number_length with_unicode
             <^> hardline
             <^> rulecolor
                   (pad_with_width1_string
                      (max_line_number_length + 2)
                      (if with_unicode then
                         "─"
                       else
                         "-")
                      "")
             <^> rulecolor
                   (if with_unicode then
                      "┼──▶"
                    else
                      "+-->"))
          <+> report_file
      in
      let pipe = pipe_prefix max_line_number_length with_unicode in
      let all_line_numbers =
        let lines =
          List.map fst sorted_lines
          @ List.concat_map
              (fun (p, _) ->
                 let rec range a b =
                   if a > b then
                     []
                   else
                     a :: range (a + 1) b
                 in
                   range p.begin_line p.end_line)
              multiline_markers
        in
          List.sort_uniq compare lines
      in
        (* (2) *)
        hardline
        <^> file_marker
        <^> hardline
        <^>
        (* (3) *)
        pipe
        <^>
        (* (4)  *)
        pretty_all_lines
          ~readonly_file_map
          ~with_unicode
          ~is_error
          ~tab_size
          ~left_len:max_line_number_length
          ~inline:sorted_lines
          ~multiline:multiline_markers
          ~line_numbers:all_line_numbers

    and pretty_position (p : position) =
      (* Format: FILE:BL.BC-EL.EC
           That works in vscode terminal as a valid hyperlink. *)
      (match p.file with
       | None ->
         mempty
       | Some file ->
         filecolor file <^> filecolor ":")
      <^> filecolor (string_of_int p.begin_line)
      <^> filecolor "."
      <^> filecolor (string_of_int p.begin_col)
      <^> filecolor "-"
      <^> filecolor (string_of_int p.end_line)
      <^> filecolor "."
      <^> filecolor (string_of_int p.end_col)

    and show_for_line
          ~readonly_file_map
          ~with_unicode
          ~is_error
          ~tab_size
          ~left_len
          ~inline
          ~multiline
          is_last_line
          line
      =
      (* Inline markers for this line *)
      let all_inline_markers_in_line =
        match List.assoc_opt line inline with
        | Some ms ->
          List.filter (fun (_, m) -> m <> Blank) ms
        | None ->
          []
      in
      (* Multiline markers that start or end on this line *)
      let all_multiline_markers_in_line =
        List.filter (fun (p, _) -> p.begin_line = line || p.end_line = line) multiline
      in
      (* Multiline markers that span this line *)
      let all_multiline_markers_spanning_line =
        List.filter (fun (p, _) -> p.begin_line < line && p.end_line > line) multiline
      in
      let in_span_of_multiline =
        List.exists (fun (p, _) -> p.begin_line <= line && p.end_line >= line) multiline
      in
      let color_of_first_multiline_marker s =
        match
          Data.List.Safe.safe_head
            (all_multiline_markers_in_line @ all_multiline_markers_spanning_line)
        with
        | Some (_, marker) ->
          let ann =
            if is_error then
              Annotation.MarkerStyle (markerstyle marker)
            else
              Annotation.ThisColor false
          in
            [ AnsiStyle.text s, ann ]
        | None ->
          [ annotate Annotation.CodeStyle s ]
      in
      let multiline_ending_on_line, other_multilines =
        List.partition (fun (p, _) -> p.end_line = line) multiline
      in
      let should_show_multiline =
        is_last_line
        ||
        match
          ( Data.List.Safe.safe_last multiline_ending_on_line
          , Data.List.Safe.safe_last multiline )
        with
        | Some x, Some y ->
          x = y
        | _ ->
          false
      in
      let additional_prefix =
        match all_multiline_markers_in_line with
        | [] ->
          if multiline <> [] then
            if all_multiline_markers_spanning_line <> [] then
              color_of_first_multiline_marker
                (if with_unicode then
                   "│  "
                 else
                   "|  ")
            else
              codestyle "   "
          else
            mempty
        | (p, marker) :: _ ->
          let has_predecessor =
            p.end_line = line
            ||
            match Data.List.Safe.safe_uncons multiline with
            | Some (hd, _) ->
              fst hd <> p
            | None ->
              false
          in
            color_of_first_multiline_marker
              (if with_unicode then
                 if has_predecessor then
                   "├"
                 else
                   "╭"
               else if has_predecessor then
                 "|"
               else
                 "+")
            <^> [ ( AnsiStyle.text
                      (if with_unicode then
                         "┤"
                       else
                         ">")
                  , Annotation.MarkerStyle (markerstyle marker) )
                ]
            <^> space
      in
      let all_inline_markers_in_line' =
        List.filter (fun (_, m) -> m <> Blank) all_inline_markers_in_line
      in
      let all_multiline_markers_spanning_line' =
        List.filter (fun (_, m) -> m <> Blank) all_multiline_markers_spanning_line
      in
      let widths, rendered_code =
        get_line_
          ~readonly_file_map
          ~markers:
            (all_inline_markers_in_line
             @ all_multiline_markers_in_line
             @ all_multiline_markers_spanning_line')
          ~line
          ~tab_size
          ~is_error
      in
        (* Compose the line: line number, prefix, code, markers, multiline endings *)
        ( other_multilines
        , hardline
          <^> debugstyle "?2"
          <^>
          (* 1 *)
          line_prefix left_len line with_unicode
          <^> additional_prefix
          <^> rendered_code
          <^>
          (* 2 *)
          show_all_markers_in_line
            ~has_multilines:(multiline <> [])
            ~in_span_of_multiline
            ~color_multiline_prefix:color_of_first_multiline_marker
            ~with_unicode
            ~is_error
            ~left_len
            ~widths
            ~ms:all_inline_markers_in_line'
          <^> debugstyle "?8"
          <^> show_multiline
                ~with_unicode
                ~left_len
                ~is_error
                should_show_multiline
                multiline_ending_on_line )

    and pretty_all_lines
          ~readonly_file_map
          ~with_unicode
          ~is_error
          ~tab_size
          ~left_len
          ~inline
          ~multiline
          ~line_numbers
      : (string, string) annotated_doc
      =
      let rec aux ms lines =
        match lines with
        | [] ->
          show_multiline ~with_unicode ~left_len ~is_error true ms
        | [ l ] ->
          let other_multilines, doc =
            show_for_line
              ~readonly_file_map
              ~with_unicode
              ~is_error
              ~tab_size
              ~left_len
              ~inline
              ~multiline:ms
              true
              l
          in
            doc <^> aux other_multilines []
        | l1 :: (l2 :: _ls as rest) ->
          let other_multilines, doc =
            show_for_line
              ~readonly_file_map
              ~with_unicode
              ~is_error
              ~tab_size
              ~left_len
              ~inline
              ~multiline:ms
              false
              l1
          in
          let sep =
            if l2 <> l1 + 1 then
              hardline <^> dot_prefix left_len with_unicode
            else
              mempty
          in
            doc <^> sep <^> aux other_multilines rest
      in
        aux multiline line_numbers

    and show_multiline ~with_unicode ~left_len ~is_error is_last_multiline multiline =
      if multiline = [] || not is_last_multiline then
        []
      else (
        let color_of_first_multiline_marker =
          match Data.List.Safe.safe_head multiline with
          | Some (_, marker) ->
            Some
              (if is_error then
                 Annotation.MarkerStyle (markerstyle marker)
               else
                 Annotation.ThisColor false)
          | None ->
            None
        in
        let prefix =
          space
          <^> codestyle (pad left_len ' ' "")
          <^> codestyle
                (if with_unicode then
                   "•"
                 else
                   ":")
          <^> space
        in
        let prefix_with_bar color =
          prefix
          <^>
          let txt =
            if with_unicode then
              "│ "
            else
              "| "
          in
            match color with
            | Some ann ->
              [ AnsiStyle.text txt, ann ]
            | None ->
              codestyle txt
        in
        let show_multiline_marker_message (_, marker) is_last =
          match marker with
          | Blank ->
            []
          | _ ->
            let ann =
              if is_error then
                Annotation.MarkerStyle (markerstyle marker)
              else
                Annotation.ThisColor false
            in
              annotate_doc
                ann
                (codestyle
                   (if is_last && is_last_multiline then
                      if with_unicode then
                        "╰╸ "
                      else
                        "`- "
                    else if with_unicode then
                      "├╸ "
                    else
                      "|- ")
                 <^> replace_lines_with
                       ~repl:
                         (if is_last then
                            prefix <^> codestyle "   "
                          else
                            prefix_with_bar (Some (marker_color is_error marker))
                            <^> space)
                       0
                       (marker_message ann marker))
        in
        let rec show_multiline_marker_messages = function
          | [] ->
            []
          | [ m ] ->
            [ show_multiline_marker_message m true ]
          | m :: ms ->
            show_multiline_marker_message m false :: show_multiline_marker_messages ms
        in
          hardline
          <^> prefix_with_bar color_of_first_multiline_marker
          <^> hardline
          <^> prefix
          <^> intersperse (hardline <^> prefix) (show_multiline_marker_messages multiline)
      )

    and intersperse
          (v : (string, 'a) annotated_doc)
          (adocs : (string, 'a) annotated_doc list)
      : (string, 'a) annotated_doc
      =
      match adocs with
      | [] ->
        mempty
      | [ single ] ->
        single
      | first :: second :: rest ->
        first <+> List.fold_right (fun acc x -> v <+> x <+> acc) (second :: rest) mempty

    and get_line_ ~readonly_file_map ~markers ~line ~tab_size ~is_error
      : int array * (string, string) annotated_doc
      =
      (* Find the file name from the first marker, if any *)
      let code_opt =
        match Data.List.Safe.safe_head markers with
        | Some (p, _) ->
          FilenameMap.find_opt p.file readonly_file_map
        | None ->
          None
      in
        match code_opt with
        | Some arr when line - 1 >= 0 && line - 1 < Array.length arr ->
          let code = arr.(line - 1) in
          let mk_width_table s =
            Array.init (String.length s) (fun i ->
              if s.[i] = '\t' then
                tab_size
              else
                1)
          in
          let width_table = mk_width_table code in
          (* For each character, determine if it should be colored *)
          let annotated_doc : (string, string) annotated_doc =
            let len = String.length code in
            let buf = Buffer.create (len * tab_size) in
            let pending : (_ AnsiStyle.t * string Annotation.t) Queue.t =
              Queue.create ()
            in
            let last_annotation = ref None in
              for i = 0 to len - 1 do
                let n = i + 1 in
                let c = code.[i] in
                let ctabbed =
                  if c = '\t' then
                    String.make tab_size ' '
                  else
                    String.make 1 c
                in
                let colorizing_markers =
                  List.filter
                    (fun (p, _) ->
                       if p.begin_line = p.end_line then
                         n >= p.begin_col && n < p.end_col
                       else
                         (p.begin_line = line && n >= p.begin_col)
                         || (p.end_line = line && n < p.end_col)
                         || (p.begin_line < line && p.end_line > line))
                    markers
                in
                let annotation : string Annotation.t =
                  match Data.List.Safe.safe_head colorizing_markers with
                  | Some (_, This _) ->
                    if is_error then
                      MarkerStyle (ThisColor true)
                    else
                      ThisColor false
                  | Some (_, Where _) ->
                    if is_error then
                      MarkerStyle WhereColor
                    else
                      WhereColor
                  | Some (_, Maybe _) ->
                    if is_error then
                      MarkerStyle MaybeColor
                    else
                      MaybeColor
                  | Some (_, Blank) ->
                    if is_error then
                      MarkerStyle CodeStyle
                    else
                      CodeStyle
                  | None ->
                    CodeStyle
                in
                  (* Spool the current character, merging it if is the same annotation type *)
                  (match !last_annotation, annotation with
                   | Some a, b when a <> b ->
                     Queue.add (AnsiStyle.text (Buffer.contents buf), a) pending;
                     Buffer.clear buf
                   | _ ->
                     ());
                  Buffer.add_string buf ctabbed;
                  last_annotation := Some annotation
              done;
              (* Finalize the last annotation *)
              (match !last_annotation with
               | Some a ->
                 Queue.add (AnsiStyle.text (Buffer.contents buf), a) pending
               | _ ->
                 ());
              (* Convert to annotated doc *)
              Queue.to_seq pending |> List.of_seq
          in
            width_table, annotated_doc
        | _ ->
          let width_table = Array.make 0 0 in
            width_table, [ AnsiStyle.text "<no line>", Annotation.NoLineColor ]

    and show_all_markers_in_line
          ~has_multilines
          ~in_span_of_multiline
          ~color_multiline_prefix
          ~with_unicode
          ~is_error
          ~left_len
          ~widths
          ~(ms : (position * 'msg marker) list)
      : (string, string) annotated_doc
      =
      let widths_between ~begin_col ~end_col =
        (* begin and end are 1-based *)
        let pos = begin_col - 1 in
        (* The original Haskell has [take (end - start)] which means that when
             end=start no widths are taken. Using [end - begin + 1] is incorrect. *)
        let len = end_col - begin_col in
          (* Invalid argument raised when:
             pos < 0, or len < 0, or pos + len > length a

             This is Diagnose. Do not raise an error even for programmer incorrectness. *)
          if pos < 0 || len < 0 || pos + len > Array.length widths then
            0
          else
            Array.fold_left ( + ) 0 (Array.sub widths pos len)
      in
        if ms = [] then
          []
        else (
          let sorted_ms =
            List.sort (fun (p1, _) (p2, _) -> compare p1.end_col p2.end_col) ms
          in
          let max_marker_column =
            match Data.List.Safe.safe_last sorted_ms with
            | Some (p, _) ->
              p.end_col
            | None ->
              0
          in
          let special_prefix =
            if in_span_of_multiline then
              color_multiline_prefix
                (if with_unicode then
                   "│ "
                 else
                   "| ")
              <^> space
            else if has_multilines then
              color_multiline_prefix "  " <^> space
            else
              mempty
          in
            hardline
            <^> dot_prefix left_len with_unicode
            <^>
            if ms = [] then
              []
            else (
              let marker_doc =
                show_markers
                  ~ms
                  ~n:1
                  ~line_len:max_marker_column
                  ~width_at:(fun i ->
                    if i >= 0 && i < Array.length widths then
                      widths.(i)
                    else
                      0)
                  ~is_error
                  ~with_unicode
                  ~marker_color:(fun is_error marker ->
                    if is_error then
                      Annotation.MarkerStyle (markerstyle marker)
                    else
                      Annotation.ThisColor false)
              in
              let message_doc =
                show_messages
                  ~special_prefix
                  ~messages:ms
                  ~line_len:max_marker_column
                  ~left_len
                  ~with_unicode
                  ~is_error
                  ~width_at:(fun i ->
                    if i >= 0 && i < Array.length widths then
                      widths.(i)
                    else
                      0)
                  ~marker_color:(fun is_error marker ->
                    if is_error then
                      Annotation.MarkerStyle (markerstyle marker)
                    else
                      Annotation.ThisColor false)
                  ~widths_between
              in
                marker_doc
                <^> debugstyle (Printf.sprintf "?5 %d %d" left_len max_marker_column)
                <^> message_doc
            )
        )

    and show_markers
          ~(ms : (position * 'msg marker) list)
          ~(n : int)
          ~(line_len : int)
          ~(width_at : int -> int)
          ~(is_error : bool)
          ~(with_unicode : bool)
          ~(marker_color : bool -> 'msg marker -> string Annotation.t)
      : (string, string) annotated_doc
      =
      if n > line_len then
        []
      else (
        let all_markers =
          List.filter
            (fun (p, mark) ->
               let bc = p.begin_col in
               let ec = p.end_col in
                 (not
                    (match mark with
                     | Blank ->
                       true
                     | _ ->
                       false))
                 && n >= bc
                 && n < ec)
            ms
        in
          match all_markers with
          | [] ->
            let spaces = String.make (width_at n) ' ' in
              [ annotate Annotation.CodeStyle spaces ]
              @ show_markers
                  ~ms
                  ~n:(n + 1)
                  ~line_len
                  ~width_at
                  ~is_error
                  ~with_unicode
                  ~marker_color
          | (p, marker) :: _ ->
            let bc = p.begin_col in
            (* let ec = p.end_col in *)
            let marker_ann = marker_color is_error marker in
            let caret =
              if bc = n then (
                let caret_char =
                  if with_unicode then
                    "┬"
                  else
                    "^"
                in
                let dash_char =
                  if with_unicode then
                    "─"
                  else
                    "-"
                in
                let dashes = string_repeat (width_at n - 1) dash_char in
                  caret_char ^ dashes
              ) else (
                let dash_char =
                  if with_unicode then
                    "─"
                  else
                    "-"
                in
                  string_repeat (width_at n) dash_char
              )
            in
              [ annotate marker_ann caret ]
              @ show_markers
                  ~ms
                  ~n:(n + 1)
                  ~line_len
                  ~width_at
                  ~is_error
                  ~with_unicode
                  ~marker_color
      )

    and show_messages
          ~special_prefix
          ~(messages : (position * 'msg marker) list)
          ~(line_len : int)
          ~(left_len : int)
          ~(with_unicode : bool)
          ~(is_error : bool)
          ~(width_at : int -> int)
          ~(marker_color : bool -> 'msg marker -> string Annotation.t)
          ~widths_between
      : (string, string) annotated_doc
      =
      match Data.List.Safe.safe_uncons messages with
      | None ->
        (* no more messages to show *)
        mempty
      | Some (({ begin_col = bc; _ }, msg), pipes) ->
        let filtered_pipes =
          (* record only the pipes corresponding to markers on different starting positions *)
          List.filter
            (fun (p', m') ->
               p'.begin_col <> bc
               && not
                    (match m' with
                     | Blank ->
                       true
                     | _ ->
                       false))
            pipes
        in
        let nubbed_pipes =
          (* and then remove all duplicates *)
          let seen = Hashtbl.create 8 in
            List.filter
              (fun (p', _) ->
                 if Hashtbl.mem seen p'.begin_col then
                   false
                 else (
                   Hashtbl.add seen p'.begin_col ();
                   true
                 ))
              filtered_pipes
        in
        let rec all_columns n ms =
          (* transform the list of remaining markers into a single document line *)
          match ms with
          | [] ->
            1, []
          | ({ begin_col = bc; _ }, col) :: ms' ->
            if n = bc then (
              let n', cols = all_columns (n + 1) ms' in
                n', col :: cols
            ) else if n < bc then (
              let n', cols = all_columns (n + 1) ms in
                n', codestyle (String.make (width_at n) ' ') <^> cols
            ) else (
              let n', cols = all_columns (n + 1) ms' in
                n', codestyle (String.make (width_at n) ' ') <^> cols
            )
        in
        let has_successor = List.length filtered_pipes <> List.length pipes in
        let line_start pipes : (string, string) annotated_doc =
          (* the start of the line contains the "dot"-prefix as well as all the pipes for all the still not rendered marker messages *)
          let sorted_pipes =
            List.sort (fun (p1, _) (p2, _) -> compare p1.begin_col p2.begin_col) pipes
          in
          let n, (docs : (string, string) annotated_doc) =
            all_columns 1 (List.map (fun (p, col) -> p, col) sorted_pipes)
          in
          let number_of_spaces = widths_between ~begin_col:n ~end_col:bc in
            dot_prefix left_len with_unicode
            <^> special_prefix
            <^> docs
            <^> codestyle (String.make number_of_spaces ' ')
        in
        let prefix : (string, string) annotated_doc =
          (* split the list so that all pipes before can have `|`s but pipes after won't *)
          let pipes_before, pipes_after =
            List.partition (fun (p', _) -> p'.begin_col < bc) nubbed_pipes
          in
          let pipes_before_rendered : (position * (string, 'a) annotated_block) list =
            (* pre-render pipes which are before because they will be shown *)
            List.map
              (fun (position, marker) : (position * (string, 'a) annotated_block) ->
                 let ann =
                   annotate
                     (marker_color is_error marker)
                     (if with_unicode then
                        "│"
                      else
                        "|")
                 in
                   position, ann)
              pipes_before
          in
          let last_begin_position =
            match
              Data.List.Safe.safe_last
                (List.sort
                   (fun (p1, _) (p2, _) -> compare p1.begin_col p2.begin_col)
                   pipes_after)
            with
            | None ->
              None
            | Some (p', _) ->
              Some p'.begin_col
          in
          let line_len =
            match last_begin_position with
            | None ->
              0
            | Some col ->
              widths_between ~begin_col:bc ~end_col:col
          in
          let current_pipe =
            if with_unicode then
              if has_successor then
                "├"
              else
                "╰"
            else if has_successor then
              "|"
            else
              "`"
          in
          let line_char =
            if with_unicode then
              "─"
            else
              "-"
          in
          let point_char =
            if with_unicode then
              "╸"
            else
              "-"
          in
          let bc' = bc + line_len + 2 in
          let pipes_before_message_start =
            List.filter (fun (p', _) -> p'.begin_col < bc') pipes_after
          in
          (* consider pipes before, as well as pipes which came before the text rectangle bounds *)
          let pipes_before_message_rendered
            : (position * (string, 'a) annotated_block) list
            =
            List.map
              (fun (position, marker) ->
                 let ann =
                   annotate
                     (marker_color is_error marker)
                     (if with_unicode then
                        "│"
                      else
                        "|")
                 in
                   position, ann)
              (pipes_before @ pipes_before_message_start)
          in
            (* also pre-render pipes which are before the message text bounds, because they will be shown if the message is on
                 multiple lines *)
            (* Haskell source code:

  lineStart pipesBeforeRendered
                      <> annotate (markerColor isError msg) (currentPipe <> pretty (replicate lineLen lineChar) <> pointChar)
                      <+> annotate (markerColor isError msg) (replaceLinesWith (space <> lineStart pipesBeforeMessageRendered <+> if List.null pipesBeforeMessageStart then "  " else " ") 0 $ annotated $ markerMessage msg)
            *)
            line_start pipes_before_rendered
            <^> [ annotate
                    (marker_color is_error msg)
                    (current_pipe ^ string_repeat line_len line_char ^ point_char)
                ]
            <+>
            (*
               let msg_text =
                (* annotate
                  (marker_color is_error msg)
                  (replace_lines_with
                     ~repl:
                       (codestyle " "
                       <^> List.fold_left ( <^> ) []
                             (List.map
                                (fun x -> [ x ])
                                pipes_before_message_rendered)
                       <^> codestyle
                             (if pipes_before_message_start = [] then "  "
                              else " "))
                     0 (marker_message msg)) *)
                let ann = marker_color is_error msg in
                marker_message ann msg *)
            annotate_doc
              (marker_color is_error msg)
              (replace_lines_with
                 ~repl:
                   (space
                    <^> line_start pipes_before_message_rendered
                    <^> codestyle
                          (if pipes_before_message_start = [] then
                             "  "
                           else
                             " "))
                 0
                 (marker_message Annotation.CodeStyle msg))
        in
          hardline
          <^> debugstyle "?6"
          <^> prefix
          <^> debugstyle "?7"
          <^> show_messages
                ~special_prefix
                ~messages:pipes
                ~line_len
                ~left_len
                ~with_unicode
                ~is_error
                ~width_at
                ~marker_color
                ~widths_between

    (* and replace_lines_with ~repl n (s : (string, string) annotated_doc) : string
          =
        (* Split by [AnsiStyle.newline] *)
        let lines =
          let rec aux acc x =
            let y = Stringext.cut ~on:AnsiStyle.newline x in
            match y with
            | None -> List.rev (x :: acc)
            | Some (left, right) -> aux (left :: acc) right
          in
          aux [] (render s)
        in
        let start =
          render (codestyle "\"" <^> repl <^> codestyle (String.make n ' '))
        in
        start ^ String.concat (AnsiStyle.newline ^ start) lines *)

    (* and render_hack doc =
        let buf = Buffer.create 256 in
        List.iter
          (fun (ablock : (string, string) annotated_block) ->
            let astyle = Theme.style ablock in
            AnsiStyle.output buf astyle)
          doc;
        Buffer.contents buf *)

    and replace_lines_with
          ~(repl : (string, _) annotated_doc)
          n
          (d : (string, _) annotated_doc)
      : (string, _) annotated_doc
      =
      let repl_with_nesting = hardline <^> repl <^> codestyle (String.make n ' ') in
        List.map
          (fun ((style, _) as block : (string, _) annotated_block) ->
             if AnsiStyle.is_hardline style then
               repl_with_nesting <^> [ block ]
             else
               [ block ])
          d
        |> List.flatten

    and marker_message ann = function
      | This m ->
        [ annotate ann m ]
      | Where m ->
        [ annotate ann m ]
      | Maybe m ->
        [ annotate ann m ]
      | Blank ->
        []

    and marker_color is_error marker =
      if is_error then
        Annotation.MarkerStyle (markerstyle marker)
      else
        Annotation.ThisColor false
    ;;
  end
  end
