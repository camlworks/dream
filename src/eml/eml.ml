(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2021 Anton Bachin *)



(* Location handling is done by updating a reference with the location of the
   last character read. This is pretty fragile, and depends on the tokenizer
   never looking so far forward as to invalidate the locations that it cares
   about. Locations are 0-based. *)
module Location :
sig
  val current : unit -> int * int
  val adjust : int -> unit
  val reset : unit -> unit
  val stream : (unit -> char option) -> char Stream.t
end =
struct
  let line =
    ref 0

  let column =
    ref 0

  let current () =
    !line, !column

  let adjust by =
    column := !column + by

  let reset () =
    line := 0;
    column := 0

  let stream underlying =
    let ended = ref false in

    Stream.from begin fun _index ->
      if !ended then
        None
      else
        match underlying () with
        | None ->
          ended := true;
          None
        | Some '\n' as c ->
          incr line;
          column := 0;
          c
        | c ->
          incr column;
          c
    end
end



(* We need to retain the locations of code tokens, so we can emit the proper
   #line directives for good error messages from the compiler. *)
type 'a with_location = {
  line : int;
  column : int;
  what : 'a;
}

type code_block_token = [
  (* A block of OCaml code. These start at the beginning of the input file, and
     continue until a line that starts with '<'. They occur again whenever the
     template text ends. Template text ends on a line with less indentation than
     the first template line, or at a %% terminator. *)
  | `Code_block of string with_location
]

type options_token = [
  (* Passes template-wide options to the template code generator phase. The
     string is any options text found after %%. The int is the indentation level
     of the token beginning the template, whether %% or an implicit start. *)
  | `Options of string * int
]

type newline_token = [
  (* A newline character within template text. The tokenizer notes these for
     future passes that un-indent the template and remove lines containing only
     embedded code. *)
  | `Newline
]

type template_token = [
  (* Once the template starts, text, by default, is accumulated into these
     tokens. These strings contain no newlines. *)
  | `Text of string

  (* Code found within the template text, i.e. in <% ... %> and its variants.
     The variant indicates what to do with the code - but this is irrelevant at
     the token level; the tokenizer just needs to note it for the later
     transformers to process. *)
  | `Embedded of (string * string) with_location
]

type token = [
  | code_block_token
  | options_token
  | newline_token
  | template_token
]

module Token :
sig
  val show : token -> string
end =
struct
  let show = function
    | `Code_block {line; column; what = code} ->
      Printf.sprintf "(%i, %i) Code_block\n%s" (line + 1) column code
    | `Options (options, indent) ->
      Printf.sprintf "Options %s, %i" options indent
    | `Text payload ->
      Printf.sprintf "Text {|%s|}" payload
    | `Newline ->
      "Newline"
    | `Embedded {line; column; what = options, code} ->
      Printf.sprintf "(%i, %i) Embedded (%s) %s" (line + 1) column options code
end

(* The tokenizer responds to some ASCII characters, and passes everything else
   through unchanged. So, it is UTF-8-safe. *)
module Tokenizer :
sig
  val scan : ?syntax:[ `OCaml | `Reason ] -> char Stream.t -> token list
end =
struct

  (* Individual token type scanners. *)

  let token_buffer =
    Buffer.create 4096

  let lookahead_buffer =
    Buffer.create 128

  let finish buffer =
    let result = Buffer.contents buffer in
    Buffer.clear buffer;
    result

  let rec scan_whitespace stream columns =
    match Stream.peek stream with
    | Some ' ' ->
      Buffer.add_char lookahead_buffer ' ';
      Stream.junk stream;
      scan_whitespace stream (columns + 1)
    | _ ->
      finish lookahead_buffer


  (* Template text is detected line-by-line, but a line inside an OCaml
     (* *) comment must never begin template text - otherwise the comment's
     body and terminator are tokenized as template (see #365). Knowing whether
     the scanner is inside a comment takes a little more of OCaml's lexical
     conventions than counting comment delimiters:

     - Comments nest.
     - String literals are lexed inside comments, so a "*)" inside a string
       inside a comment does not close the comment.
     - A "(*" inside a string literal ("..." or {id|...|id}) in code does not
       open a comment.
     - A double quote in a character literal ('"') is not a string delimiter,
       while an apostrophe in a type variable ('a) is not a character literal.
     - An apostrophe can also continue an identifier (x'), where it does not
       open a character literal either.
     - Extension quoted strings ({%ext|...|} and {%%ext delim|...|delim}) are
       raw, like {id|...|id}.

     The scanner state is advanced by scan_code_block one consumed character
     at a time. The int in each constructor is the comment nesting depth; zero
     means outside any comment. Tracking applies only to OCaml input; Reason
     .eml.re input is scanned exactly as before. *)
  type code_syntax =
    | Code of int
    | Identifier of int
      (* Inside an identifier or literal: an apostrophe here continues the
         token (x', b'c'), rather than opening a character literal. *)
    | Open_comment of int
      (* At '(': a '*' next enters a comment. *)
    | Close_comment of int
      (* At '*' with depth >= 1: a ')' next leaves a comment. *)
    | String_literal of int
    | String_escape of int
      (* At a backslash inside a string literal. *)
    | Character of int
      (* At an apostrophe: maybe a character literal, maybe a type
         variable. *)
    | Character_escape of int
      (* At a backslash after an apostrophe. *)
    | Character_end of int * char option
      (* After one (possibly escaped) character following an apostrophe. If no
         closing apostrophe follows, an unescaped character is replayed as
         code, since it was not a character literal ('a followed by "(*", for
         example). *)
    | Quoted_string_open of int * string
      (* At '{', accumulating a possible "{id|" opening delimiter. *)
    | Quoted_extension_start of int
      (* After "{%" or "{%%": expecting an extension quoted string's
         attribute id, as in {%html|...|}. The id must be non-empty. *)
    | Quoted_extension of int
      (* Consuming the rest of an extension quoted string's attribute id. *)
    | Quoted_extension_delimiter of int * string
      (* After the attribute id and a blank: accumulating the delimiter, as
         in {%sql foo|...|foo}. *)
    | Quoted_string of int * string
    | Quoted_string_close of int * string * string
      (* At '|' inside {id|...|id}, accumulating a possible |id} closing
         delimiter. *)

  (* Template text cannot begin on a line that starts inside a comment
     (comment nesting depth over zero), nor on one that starts inside a
     string or quoted string literal, whether inside a comment or not. *)
  let suppresses_template_detection = function
    | Code depth
    | Identifier depth
    | Open_comment depth
    | Close_comment depth
    | Character depth
    | Character_escape depth
    | Character_end (depth, _)
    | Quoted_string_open (depth, _)
    | Quoted_extension_start depth
    | Quoted_extension depth
    | Quoted_extension_delimiter (depth, _) ->
      depth > 0
    | String_literal _
    | String_escape _
    | Quoted_string (_, _)
    | Quoted_string_close (_, _, _) ->
      true

  let rec next_syntax syntax character =
    match syntax, character with
    | Code depth, '(' ->
      Open_comment depth
    | Code depth, '*' when depth > 0 ->
      Close_comment depth
    | Code depth, '"' ->
      String_literal depth
    | Code depth, '\'' ->
      Character depth
    | Code depth, '{' ->
      Quoted_string_open (depth, "")
    | Code depth, ('a'..'z' | 'A'..'Z' | '0'..'9' | '_') ->
      Identifier depth
    | Code depth, _ ->
      Code depth
    | Identifier depth, ('a'..'z' | 'A'..'Z' | '0'..'9' | '_' | '\'') ->
      Identifier depth
    | Identifier depth, _ ->
      next_syntax (Code depth) character
    | Open_comment depth, '*' ->
      Code (depth + 1)
    | Open_comment depth, _ ->
      next_syntax (Code depth) character
    | Close_comment depth, ')' ->
      Code (depth - 1)
    | Close_comment depth, '*' ->
      Close_comment depth
    | Close_comment depth, _ ->
      next_syntax (Code depth) character
    | String_literal depth, '"' ->
      Code depth
    | String_literal depth, '\\' ->
      String_escape depth
    | String_literal depth, _ ->
      String_literal depth
    | String_escape depth, _ ->
      String_literal depth
    | Character depth, '\\' ->
      Character_escape depth
    | Character depth, '\'' ->
      Code depth
    | Character depth, _ ->
      Character_end (depth, Some character)
    | Character_escape depth, _ ->
      Character_end (depth, None)
    | Character_end (depth, _), '\'' ->
      Code depth
    | Character_end (depth, replayed), _ ->
      let syntax =
        Option.fold
          ~none:(Code depth) ~some:(next_syntax (Code depth)) replayed in
      next_syntax syntax character
    | Quoted_string_open (depth, identifier), '|' ->
      Quoted_string (depth, identifier)
    | Quoted_string_open (depth, identifier), ('a'..'z' | '_') ->
      Quoted_string_open (depth, identifier ^ String.make 1 character)
    | Quoted_string_open (depth, ""), '%' ->
      Quoted_extension_start depth
    | Quoted_string_open (depth, _), _ ->
      next_syntax (Code depth) character
    | Quoted_extension_start depth, '%' ->
      Quoted_extension_start depth
    | Quoted_extension_start depth, ('a'..'z' | 'A'..'Z' | '_') ->
      Quoted_extension depth
    | Quoted_extension_start depth, _ ->
      next_syntax (Code depth) character
    | Quoted_extension depth, '|' ->
      Quoted_string (depth, "")
    | Quoted_extension depth,
      ('a'..'z' | 'A'..'Z' | '0'..'9' | '_' | '\'' | '.' | '%') ->
      Quoted_extension depth
    | Quoted_extension depth, (' ' | '\t') ->
      Quoted_extension_delimiter (depth, "")
    | Quoted_extension depth, _ ->
      next_syntax (Code depth) character
    | Quoted_extension_delimiter (depth, identifier), '|' ->
      Quoted_string (depth, identifier)
    | Quoted_extension_delimiter (depth, identifier), ('a'..'z' | '_') ->
      Quoted_extension_delimiter (depth, identifier ^ String.make 1 character)
    | Quoted_extension_delimiter (depth, ""), (' ' | '\t') ->
      Quoted_extension_delimiter (depth, "")
    | Quoted_extension_delimiter (depth, _), _ ->
      next_syntax (Code depth) character
    | Quoted_string (depth, identifier), '|' ->
      Quoted_string_close (depth, identifier, "")
    | Quoted_string (depth, identifier), _ ->
      Quoted_string (depth, identifier)
    | Quoted_string_close (depth, identifier, closing), '}'
      when closing = identifier ->
      Code depth
    | Quoted_string_close (depth, identifier, closing), ('a'..'z' | '_') ->
      Quoted_string_close (depth, identifier, closing ^ String.make 1 character)
    | Quoted_string_close (depth, identifier, _), '|' ->
      Quoted_string_close (depth, identifier, "")
    | Quoted_string_close (depth, identifier, _), _ ->
      Quoted_string (depth, identifier)

  (* Consumes all characters line-by-line, until a line begins with at least two
     spaces followed by <. At the end of this scan, the stream is at the first
     significant character on the line that ended the code block, or at the end
     of input. The string contains the whitespace characters from the beginning
     of the line that terminated the code block. Lines beginning inside an
     OCaml comment or string literal never end the code block (see #365). *)
  let scan_code_block :
      [ `OCaml | `Reason ] -> string -> char Stream.t -> token * string =

    let is_template_line leading_whitespace stream =
      match leading_whitespace, Stream.peek stream with
      | (None | Some ""), Some '%' ->
        true, ""
      | _ ->
        let more_whitespace = scan_whitespace stream 0 in
        match Stream.npeek 2 stream with
        | '<'::_ ->
          true, more_whitespace
        | ['%'; '%'] ->
          true, more_whitespace
        | _ ->
          false, more_whitespace
    in

    let rec scan_lines advance syntax leading_whitespace stream =
      if suppresses_template_detection syntax then
        (* Inside a comment or a string literal, the line is consumed as code
           without template detection. Its leading whitespace is still in the
           stream, and is consumed by finish_line. *)
        finish_line advance syntax stream
      else
        let is_template, whitespace =
          is_template_line leading_whitespace stream in
        if is_template then
          finish token_buffer, whitespace
        else begin
          Buffer.add_string token_buffer whitespace;
          finish_line
            advance
            (Seq.fold_left advance syntax (String.to_seq whitespace))
            stream
        end

    and finish_line advance syntax stream =
      match Stream.peek stream with
      | Some '\n' ->
        Buffer.add_char token_buffer '\n';
        Stream.junk stream;
        scan_lines advance (advance syntax '\n') None stream
      | Some c ->
        Buffer.add_char token_buffer c;
        Stream.junk stream;
        finish_line advance (advance syntax c) stream
      | None ->
        finish token_buffer, ""
    in

    fun language leading_whitespace stream ->
      let advance =
        match language with
        | `OCaml -> next_syntax
        | `Reason -> fun syntax _character -> syntax
      in
      let line, _column = Location.current () in
      let code, leftover_whitespace =
        scan_lines advance (Code 0) (Some leading_whitespace) stream in
      `Code_block {
        line;
        column = 0;
        what = (leading_whitespace ^ code);
      },
      leftover_whitespace

  (* Consumes up to one line of input that may contain text. Stops on newlines,
     <%, and end of input. *)
  let scan_text : string -> char Stream.t -> token =

    let rec finish_line stream =
      match Stream.peek stream with
      | Some '\n' | None ->
        finish token_buffer
      | Some '<' ->
        begin match Stream.npeek 2 stream with
        | ['<'; '%'] ->
          finish token_buffer
        | _ ->
          Buffer.add_char token_buffer '<';
          Stream.junk stream;
          finish_line stream
        end
      | Some c ->
        Buffer.add_char token_buffer c;
        Stream.junk stream;
        finish_line stream
    in

    fun leading_whitespace stream ->
      Buffer.add_string token_buffer leading_whitespace;
      `Text (finish_line stream)

  (* This is called when <% is found in template text; the stream front is <%.
     Matches options until the first space, then scans for %>. *)
  let scan_embedded : char Stream.t -> token =

    let rec scan_options stream =
      match Stream.peek stream with
      | None ->
        finish token_buffer
      | Some ' ' ->
        Stream.junk stream;
        finish token_buffer
      | Some c ->
        Buffer.add_char token_buffer c;
        Stream.junk stream;
        scan_options stream
    in

    let rec scan_code stream =
      match Stream.peek stream with
      | None ->
        finish token_buffer
      | Some '%' ->
        begin match Stream.npeek 2 stream with
        | [_; '>'] ->
          Stream.junk stream;
          Stream.junk stream;
          finish token_buffer
        | _ ->
          Buffer.add_char token_buffer '%';
          Stream.junk stream;
          scan_code stream
        end
      | Some c ->
        Buffer.add_char token_buffer c;
        Stream.junk stream;
        scan_code stream
    in

    fun stream ->
      (* Get rid of the <% and read any options. *)
      Stream.junk stream;
      Stream.junk stream;
      let options = scan_options stream in

      (* Note the current location, read the code, and emit the token. *)
      let line, column = Location.current () in
      `Embedded {
        line;
        column;
        what = options, scan_code stream;
      }

  (* Called at the beginning of line when the first character is '%'. *)
  let scan_embedded_line : char Stream.t -> token =

    let rec scan_code stream =
      match Stream.peek stream with
      | None ->
        finish token_buffer
      | Some '\n' ->
        Buffer.add_char token_buffer '\n';
        Stream.junk stream;
        finish token_buffer
      | Some c ->
        Buffer.add_char token_buffer c;
        Stream.junk stream;
        scan_code stream
    in

    fun stream ->
      Stream.junk stream;
      let line, column = Location.current () in
      `Embedded {
        line;
        column;
        what = "", scan_code stream;
      }

  (* Called at '%%' when a template terminator is encountered. *)
  let scan_terminator_options : char Stream.t -> string =

    let rec scan stream =
      match Stream.peek stream with
      | None ->
        finish token_buffer
      | Some '\n' ->
        Stream.junk stream;
        finish token_buffer
      | Some c ->
        Buffer.add_char token_buffer c;
        Stream.junk stream;
        scan stream
    in

    fun stream ->
      Stream.junk stream;
      Stream.junk stream;
      scan stream



  (* Tokenizer state machine. *)

  let rec at_code_block language tokens leading_whitespace stream =
    let token, leftover_whitespace =
      scan_code_block language leading_whitespace stream in
    let tokens = token::tokens in
    (* A code block can only be terminated by template text or end of input. *)
    match Stream.peek stream with
    | None -> tokens
    | Some _ ->
      (* TODO Test that completely blank lines don't break out of the
         template. *)
      let indent = String.length leftover_whitespace in
      at_text_line language tokens true indent leftover_whitespace stream

  and at_text_line language tokens first indent leading_whitespace stream =
    match Stream.peek stream with
    | None ->
      tokens
    | Some '%' when leading_whitespace = "" ->
      let tokens = (scan_embedded_line stream)::tokens in
      at_text_line language tokens false indent "" stream
    | _ ->
      let more_whitespace = scan_whitespace stream 0 in
      match Stream.npeek 2 stream with
      | ['%'; '%'] ->
        let line, _ = Location.current () in
        let options = scan_terminator_options stream, indent in
        if first then
          at_text_line
            language ((`Options options)::tokens) false indent "" stream
        else
          if String.trim (fst options) <> "" then
            Printf.ksprintf failwith
              "Line %i: text following closing '%%%%'" line
          else
            at_code_block language tokens "" stream
      | _ ->
        let all_whitespace = leading_whitespace ^ more_whitespace in
        let next = Stream.peek stream in
        if String.length all_whitespace >= indent || next = Some '\n' then
          let tokens =
            if first then
              (`Options ("", indent))::tokens
            else
              tokens
          in
          at_text language tokens indent all_whitespace stream
        else
          at_code_block language tokens all_whitespace stream

  and at_text language tokens indent leading_whitespace stream =
    let token = scan_text leading_whitespace stream in
    let tokens = token::tokens in
    (* Template text could have been terminated by embedded code, a newline, or
       end of input. In case it was terminated by a newline, check if the next
       line begins with text in the first column. If so, that is another code
       block. Otherwise, it is more template text. *)
    match Stream.peek stream with
    | None -> tokens
    | Some '\n' ->
      Stream.junk stream;
      (* let tokens = `Newline::tokens in *)
      at_text_line language (`Newline::tokens) false indent "" stream
      (* begin match Stream.peek stream with
      | None -> tokens
      | Some ' ' -> at_text_line tokens false indent "" stream
      | Some '\n' -> at_text tokens indent "" stream
      | Some '%' -> at_text_line tokens false indent "" stream
      | Some _ -> Location.adjust (-1); at_code_block tokens "" stream *)
      (* TODO Is this last case redundant at this point? Should continue with
         at_text_line; it will detect the un-indentation of the template. *)
      (* end; *)
    (* If the text scanner stopped at <, it is actually <% and this is an
       embedded code block. *)
    | Some '<' ->
      let tokens = (scan_embedded stream)::tokens in
      at_text language tokens indent "" stream
    (* This case should be impossible, because the text parser would have
       consumed any other character. *)
    | Some _ ->
      assert false

  let scan ?(syntax = `OCaml) stream =
    stream
    |> at_code_block syntax [] ""
    |> List.rev
end



type template = [
  | code_block_token
  | `Template of (string * int) * template_token list list
]

module Transform :
sig
  (* Groups text chunks into templates. A template begins at the first chunk
     following a code block, and ends at the last chunk before the next code
     block or end of input. *)
  val delimit : token list -> template list

  (* Within each template, finds the maximum amount of leading whitespace on
     all the lines, and removes that much whitespace from each line. *)
  val unindent : template list -> template list

  (* Removes lines that consist of only whitespace, including embedded code
     without options. *)
  val empty_lines : template list -> template list

  (* Combines adjacent texts. *)
  val coalesce : template list -> template list

  (* Filters out empty text. *)
  val trim : template list -> template list
end =
struct
  let delimit tokens =

    (* During this function, we unconditionally insert Begin before the first
       Text, Newline, or Embedded, because we have already seen a code block,
       and are looking for the beginning of the template. It will practically
       always be the next token, but be careful in case a future pass allows
       consecutive Code_blocks. *)
    let rec top_level (accumulator : template list) = function
      | (`Options options)::tokens ->
        template_level options accumulator [] [] tokens
      | (#template_token | `Newline)::_ as tokens ->
        (* This case should be impossible due to the addition of `Option tokens
           at the start of every template, carrying indentation information. So,
           it should be removed at the next opportunity. *)
        template_level ("", 0) accumulator [] [] tokens
      | (`Code_block _ as token)::tokens ->
        top_level (token::accumulator) tokens
      | [] ->
        List.rev accumulator

    (* This function runs when in a template. It scans for Code_block or end of
       input; upon finding either, it appends End, and returns to the
       insert_begin state. *)
    and template_level options accumulator template line = function
      | (`Code_block _ | `Options _)::_ | [] as tokens ->
        let template = (List.rev line)::template in
        top_level ((`Template (options, List.rev template))::accumulator) tokens
      | `Newline::tokens ->
        template_level options accumulator ((List.rev line)::template) [] tokens
      | (#template_token as token)::tokens ->
        template_level options accumulator template (token::line) tokens

    in

    top_level [] tokens



  let map_templates f templates =
    templates
    |> List.map (function
      | `Template (options, template) -> `Template (options, f options template)
      | `Code_block _ as token -> token)



  let rec whitespace_prefix index s =
    if index >= String.length s then
      max_int
    else
      if s.[index] != ' ' then
        index
      else
        whitespace_prefix (index + 1) s

  (* This function is dead code at this point, because the templater now uses
     indentation information from the tokenizer, rather than detecting common
     indentation after tokenization. It can be deleted once the tokenizer's
     detection is proven robust. *)
  let _common_whitespace template =
    template
    |> List.fold_left begin fun amount line ->
      match line with
      | (`Text text)::_ -> min amount (whitespace_prefix 0 text)
      | _ -> amount
    end max_int
    |> fun amount ->
      if amount = max_int then 0
      else amount

  let unindent_template amount template =
    template
    |> List.map begin function
      | (`Text text)::line ->
        let text =
          if amount >= String.length text then ""
          else String.sub text amount (String.length text - amount)
        in
        (`Text text)::line
      | line -> line
    end

  let unindent templates =
    templates |> map_templates (fun (_, indent) template ->
      unindent_template indent template)



  (* Empty lines filtering is dead code at this point. It can be removed once
     using % to filter empty lines is shown to be practical. *)
  let is_empty line =
    line |> List.for_all (function
      | `Text text -> String.trim text = ""
      | `Embedded {what = options, _; _} -> options = "")

  let leave_embdedded line =
    line |> List.filter (function
      | `Embedded _ -> true
      | _ -> false)

  let rec append_embeddeds accumulator = function
    | (`True line)::(`Embeddeds orphans)::lines ->
      append_embeddeds accumulator ((`True (line @ orphans))::lines)
    | line::lines ->
      append_embeddeds (line::accumulator) lines
    | [] ->
      List.rev accumulator

  let rec prepend_embeddeds accumulator = function
    | (`Embeddeds orphans)::(`Embeddeds more)::lines ->
      prepend_embeddeds accumulator ((`Embeddeds (orphans @ more))::lines)
    | (`Embeddeds orphans)::(`True line)::lines ->
      prepend_embeddeds ((`True (orphans @ line))::accumulator) lines
    | line::lines ->
      prepend_embeddeds (line::accumulator) lines
    | [] ->
      List.rev accumulator

  let empty_lines_from_template _ template =
    template
    |> List.map (fun line ->
      if is_empty line then
        `Embeddeds (leave_embdedded line)
      else
        `True line)
    |> append_embeddeds []
    |> prepend_embeddeds []
    |> function
      | [`Embeddeds tokens] -> [tokens]
      | true_lines ->
        true_lines |> List.map (function
          | `True line -> line
          | `Embeddeds _ -> assert false)

  let empty_lines templates =
    templates |> map_templates empty_lines_from_template



  let rec coalesce_tokens accumulator = function
    | (`Text text)::(`Text text')::tokens ->
      coalesce_tokens accumulator ((`Text (text ^ text'))::tokens)
    | token::tokens ->
      coalesce_tokens (token::accumulator) tokens
    | [] ->
      List.rev accumulator

  let coalesce_template _ template =
    template
    |> List.map (fun line -> (`Text "\n")::line)
    |> List.flatten
    |> (function
      | [] -> []
      | _newline::tokens -> tokens)
    |> coalesce_tokens []
    |> fun tokens -> [tokens]

  let coalesce templates =
    templates |> map_templates coalesce_template



  let trim templates =
    templates |> map_templates (fun _ lines ->
      lines |> List.map (fun line ->
        line |> List.filter (function
          | `Text "" -> false
          | _ -> true)))
end



module Generate :
sig
  val generate :
    reason:bool -> string -> (string -> unit) -> template list -> unit
end =
struct
  type output = {
    print : string -> unit;
    init : unit -> unit;
    finish : unit -> unit;
    text : string -> unit;
    format : string -> unit;
    format_end : unit -> unit;
  }

  let string print = {
    print;

    init = (fun () ->
      print "let ___eml_buffer = Buffer.create 4096 in\n");

    finish = (fun () ->
      print "(Buffer.contents ___eml_buffer)\n");

    text =
      Printf.ksprintf print "(Buffer.add_string ___eml_buffer %S);\n";

    format =
      Printf.ksprintf print "(Printf.bprintf ___eml_buffer %S ";

    format_end = (fun () ->
      print ");\n");
  }

  let string_reason print = {
    print;

    init = (fun () ->
      print "let ___eml_buffer = Buffer.create(4096);\n");

    finish = (fun () ->
      print "Buffer.contents(___eml_buffer)\n");

    text =
      Printf.ksprintf print "Buffer.add_string(___eml_buffer, %S);\n";

    format =
      Printf.ksprintf print "Printf.bprintf(___eml_buffer, %S)";

    format_end = (fun () ->
      print ";\n");
  }

  (* TODO Test in unit tests. *)
  let stream print = {
    print;

    init = (fun () ->
      print "let ___eml_write string = Dream.write response string in\n");

    finish = (fun () ->
      print "Lwt.return_unit\n");

    text =
      Printf.ksprintf print "let%%lwt () = ___eml_write %S in\n";

    format =
      Printf.ksprintf print "let%%lwt () = Printf.ksprintf ___eml_write %S ";

    format_end = (fun () ->
      print " in\n");
  }

  let stream_reason print = {
    print;

    init = (fun () ->
      print "let ___eml_write = string => Dream.write(response, string);\n");

    finish = (fun () ->
      print "Lwt.return_unit\n");

    text =
      Printf.ksprintf print "let%%lwt () = ___eml_write(%S);\n";

    format =
      Printf.ksprintf print "let%%lwt () = Printf.ksprintf(___eml_write, %S)";

    format_end = (fun () ->
      print ";\n");
  }

  let generate_template_body location output tokens =
    tokens |> List.iter begin function
      | `Text text ->
        (* Printf.ksprintf output.print "(Buffer.add_string ___eml_buffer %S);\n" text *)
        output.text text

      | `Embedded {line; column; what = "", code} ->
        Printf.ksprintf output.print "#%i \"%s\"\n" (line + 1) location;
        Printf.ksprintf output.print "%s%s\n" (String.make column ' ') code

      (* TODO Really need tests for this. *)
      | `Embedded {line; column; what = format, code} ->
        let format, needs_escape =
          match format.[String.length format - 1] with
          | '!' ->
            String.sub format 0 (String.length format - 1), false
          | 's' | 'S' | 'c' | 'C' | 'a' | 't' ->
            format, true
          | _ ->
            format, false
        in

        output.format ("%" ^ format);
        if needs_escape then
          output.print "(Dream.html_escape ";
        output.print "(\n";

        Printf.ksprintf output.print "#%i \"%s\"\n" (line + 1) location;
        Printf.ksprintf output.print "%s%s\n" (String.make column ' ') code;

        if needs_escape then
          output.print ")";
        output.print ")";
        output.format_end ();
    end

  let generate ~reason location print templates =
    templates |> List.iter begin function
      | `Code_block {line; what; _} ->
        Printf.ksprintf print "#%i \"%s\"\n" (line + 1) location;
        print what

      | `Template ((options, _), lines) ->
        let output =
          match reason, String.trim options with
          | false, "" -> string print
          | true,  "" -> string_reason print
          | false, "response" -> stream print
          | true,  "response" -> stream_reason print
          | _, s -> Printf.ksprintf failwith "Unknown template options '%s'" s
        in
        (* By this point, the template should be only one "line," with all the
           newlines built into the strings. We still flatten it, just in
           case. *)
        output.init ();
        generate_template_body location output (List.flatten lines);
        output.finish ()
    end
end



let process_file (input_file, location, syntax, std_out) =
  let reason, extension = match syntax with
  | `OCaml -> (false, ".ml")
  | `Reason -> (true, ".re")
  in

  let output_file =
    let rec remove_extensions filename =
      match Filename.chop_extension filename with
      | filename -> remove_extensions filename
      | exception Invalid_argument _ -> filename
    in
    remove_extensions input_file ^ extension
  in

  (* We don't bother closing these - the OCaml runtime and/or kernel will close
     it automatically on process exit, anyway. *)
  let input_channel = open_in input_file in
  let output_channel = if std_out then stdout else open_out output_file in

  let input_stream = Location.stream (fun () ->
    try Some (input_char input_channel)
    with End_of_file -> None)
  in

  Location.reset ();

  input_stream
  |> Tokenizer.scan ~syntax
  |> Transform.delimit
  |> Transform.unindent
  (* |> Transform.empty_lines *)
  |> Transform.coalesce
  |> Transform.trim
  |> Generate.generate ~reason location (output_string output_channel)
