(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2021 Anton Bachin *)



let show ?syntax input =
  Eml.Location.reset ();

  let underlying = Stream.of_string input in
  let input_stream = Eml.Location.stream (fun () ->
    try Some (Stream.next underlying)
    with _ -> None) in

  try
    input_stream
    |> Eml.Tokenizer.scan ?syntax
    |> List.map Eml.Token.show
    |> List.iter print_endline
  with Failure message ->
    print_endline message

let%expect_test _ =
  show "";
  [%expect {| (1, 0) Code_block |}]

let%expect_test _ =
  show " ";
  [%expect {| (1, 0) Code_block |}]

let%expect_test _ =
  show " \n ";
  [%expect {| (1, 0) Code_block |}]

let%expect_test _ =
  show "\n\n";
  [%expect {| (1, 0) Code_block |}]

let%expect_test _ =
  show "let foo =\n  bar\n";
  [%expect {|
    (1, 0) Code_block
    let foo =
      bar |}]

let%expect_test _ =
  show "let foo =\n< bar";
  [%expect {xxx|
    (1, 0) Code_block
    let foo =

    Options , 0
    Text {|< bar|} |xxx}]

let%expect_test _ =
  show "let foo =\n < bar";
  [%expect {xxx|
    (1, 0) Code_block
    let foo =

    Options , 1
    Text {| < bar|} |xxx}]

let%expect_test _ =
  show "let foo =\n  < bar";
  [%expect {xxx|
    (1, 0) Code_block
    let foo =

    Options , 2
    Text {|  < bar|} |xxx}]

let%expect_test _ =
  show "let foo =\n   < bar";
  [%expect {xxx|
    (1, 0) Code_block
    let foo =

    Options , 3
    Text {|   < bar|} |xxx}]

let%expect_test _ =
  show "let foo =\n  <html>\n  </html>";
  [%expect {xxx|
    (1, 0) Code_block
    let foo =

    Options , 2
    Text {|  <html>|}
    Newline
    Text {|  </html>|} |xxx}]

let%expect_test _ =
  show "let foo =\n  <html>\n  plain";
  [%expect {xxx|
    (1, 0) Code_block
    let foo =

    Options , 2
    Text {|  <html>|}
    Newline
    Text {|  plain|} |xxx}]

let%expect_test _ =
  show "let foo =\n  <html>\n  </html>\nlet bar = ()\n";
  [%expect {xxx|
    (1, 0) Code_block
    let foo =

    Options , 2
    Text {|  <html>|}
    Newline
    Text {|  </html>|}
    Newline
    (4, 0) Code_block
    let bar = () |xxx}]

let%expect_test _ =
  show "let foo =\n  <% a %>\n";
  [%expect {xxx|
    (1, 0) Code_block
    let foo =

    Options , 2
    Text {|  |}
    (2, 5) Embedded () a
    Text {||}
    Newline |xxx}]

let%expect_test _ =
  show "let foo =\n  <% a % %>\n";
  [%expect {xxx|
    (1, 0) Code_block
    let foo =

    Options , 2
    Text {|  |}
    (2, 5) Embedded () a %
    Text {||}
    Newline |xxx}]

let%expect_test _ =
  show "let foo =\n  <% a %%>\n";
  [%expect {xxx|
    (1, 0) Code_block
    let foo =

    Options , 2
    Text {|  |}
    (2, 5) Embedded () a %
    Text {||}
    Newline |xxx}]

let%expect_test _ =
  show "let foo =\n  <%= a %>\n";
  [%expect {xxx|
    (1, 0) Code_block
    let foo =

    Options , 2
    Text {|  |}
    (2, 6) Embedded (=) a
    Text {||}
    Newline |xxx}]

let%expect_test _ =
  show "let foo =\n  <% a\nb %>\n";
  [%expect {xxx|
    (1, 0) Code_block
    let foo =

    Options , 2
    Text {|  |}
    (2, 5) Embedded () a
    b
    Text {||}
    Newline |xxx}]

let%expect_test _ =
  show "let foo =\n  <%";
  [%expect {xxx|
    (1, 0) Code_block
    let foo =

    Options , 2
    Text {|  |}
    (2, 4) Embedded ()
    Text {||} |xxx}]

let%expect_test _ =
  show "let foo =\n  <%\na %>";
  [%expect {xxx|
    (1, 0) Code_block
    let foo =

    Options , 2
    Text {|  |}
    (3, 2) Embedded (
    a)
    Text {||} |xxx}]

let%expect_test _ =
  show "let foo =\n  <% \n a";
  [%expect {xxx|
    (1, 0) Code_block
    let foo =

    Options , 2
    Text {|  |}
    (2, 5) Embedded ()
     a
    Text {||} |xxx}]

let%expect_test _ =
  show "let foo =\n  <html>\n\na";
  [%expect {xxx|
    (1, 0) Code_block
    let foo =

    Options , 2
    Text {|  <html>|}
    Newline
    Text {||}
    Newline
    (4, 0) Code_block
    a |xxx}]

let%expect_test _ =
  show "let foo =\n% abc";
  [%expect {xxx|
    (1, 0) Code_block
    let foo =

    (2, 1) Embedded ()  abc |xxx}]

let%expect_test _ =
  show "let foo =\n% abc\n";
  [%expect {xxx|
    (1, 0) Code_block
    let foo =

    (2, 1) Embedded ()  abc |xxx}]

let%expect_test _ =
  show "let foo =\n% abc\n% def";
  [%expect {xxx|
    (1, 0) Code_block
    let foo =

    (2, 1) Embedded ()  abc

    (3, 1) Embedded ()  def |xxx}]

let%expect_test _ =
  show "let foo =\n  <html>\n% abc\n  </html>";
  [%expect {xxx|
    (1, 0) Code_block
    let foo =

    Options , 2
    Text {|  <html>|}
    Newline
    (3, 1) Embedded ()  abc

    Text {|  </html>|} |xxx}]

let%expect_test _ =
  show "let foo=\n % bar";
  [%expect {|
    (1, 0) Code_block
    let foo=
     % bar |}]

let%expect_test _ =
  show "let foo=\n  <html>\n % bar";
  [%expect {xxx|
    (1, 0) Code_block
    let foo=

    Options , 2
    Text {|  <html>|}
    Newline
    (3, 0) Code_block
     % bar |xxx}]

let%expect_test _ =
  show "let foo\n  <html>\n\n% bar";
  [%expect {xxx|
    (1, 0) Code_block
    let foo

    Options , 2
    Text {|  <html>|}
    Newline
    Text {||}
    Newline
    (4, 1) Embedded ()  bar |xxx}]

let%expect_test _ =
  show "let foo\n  <html>\n \n% bar";
  [%expect {xxx|
    (1, 0) Code_block
    let foo

    Options , 2
    Text {|  <html>|}
    Newline
    Text {| |}
    Newline
    (4, 1) Embedded ()  bar |xxx}]

let%expect_test _ =
  show "let foo = \n  <html>\nbar";
  [%expect {xxx|
    (1, 0) Code_block
    let foo =

    Options , 2
    Text {|  <html>|}
    Newline
    (3, 0) Code_block
    bar |xxx}]

let%expect_test _ =
  show "let foo\n %% a = b\n bar";
  [%expect {xxx|
    (1, 0) Code_block
    let foo

    Options  a = b, 1
    Text {| bar|} |xxx}]

let%expect_test _ =
  show "let foo\n %% a = b\n bar\n %%\n baz";
  [%expect {xxx|
    (1, 0) Code_block
    let foo

    Options  a = b, 1
    Text {| bar|}
    Newline
    (5, 0) Code_block
     baz |xxx}]

let%expect_test _ =
  show "let foo\n %% a = b\n %%";
  [%expect {|
    (1, 0) Code_block
    let foo

    Options  a = b, 1
    (3, 0) Code_block |}]

let%expect_test _ =
  show "let foo\n %% a = b\n %% c\n";
  [%expect {| Line 2: text following closing '%%' |}]

(* Template detection is suppressed inside OCaml comments (#365). *)

let%expect_test _ =
  show "  (*\n  <p>foo</p>\n  *)\n";
  [%expect {|
    (1, 0) Code_block
      (*
      <p>foo</p>
      *) |}]

let%expect_test _ =
  show "(* a\n  <p>b</p>\n*)\nlet c = ()\n  <p>d</p>\n";
  [%expect {xxx|
    (1, 0) Code_block
    (* a
      <p>b</p>
    *)
    let c = ()

    Options , 2
    Text {|  <p>d</p>|}
    Newline |xxx}]

let%expect_test _ =
  show "(* a (* b\n  <p>c</p>\n*)\n  <p>d</p>\n*)\n  <p>e</p>\n";
  [%expect {xxx|
    (1, 0) Code_block
    (* a (* b
      <p>c</p>
    *)
      <p>d</p>
    *)

    Options , 2
    Text {|  <p>e</p>|}
    Newline |xxx}]

let%expect_test _ =
  show "(* \"*)\" b\n  <p>c</p>\n*)\n";
  [%expect {|
    (1, 0) Code_block
    (* "*)" b
      <p>c</p>
    *) |}]

let%expect_test _ =
  show "let a\n(*\n%% b\n  <p>c</p>\n*)\n";
  [%expect {|
    (1, 0) Code_block
    let a
    (*
    %% b
      <p>c</p>
    *) |}]

let%expect_test _ =
  show "(* a *) let b = ()\n  <p>c</p>\n";
  [%expect {xxx|
    (1, 0) Code_block
    (* a *) let b = ()

    Options , 2
    Text {|  <p>c</p>|}
    Newline |xxx}]

(* A "(*" inside a string, character, or quoted string literal does not open
   a comment, so template detection is not suppressed after one. *)

let%expect_test _ =
  show "let a = \"(*\"\n  <p>b</p>\n";
  [%expect {xxx|
    (1, 0) Code_block
    let a = "(*"

    Options , 2
    Text {|  <p>b</p>|}
    Newline |xxx}]

let%expect_test _ =
  show "let a = '\"'\n  <p>b</p>\n";
  [%expect {xxx|
    (1, 0) Code_block
    let a = '"'

    Options , 2
    Text {|  <p>b</p>|}
    Newline |xxx}]

let%expect_test _ =
  show "let a = {|(*|}\n  <p>b</p>\n";
  [%expect {xxx|
    (1, 0) Code_block
    let a = {|(*|}

    Options , 2
    Text {|  <p>b</p>|}
    Newline |xxx}]

let%expect_test _ =
  show "type 'a t = 'a list\n  <p>b</p>\n";
  [%expect {xxx|
    (1, 0) Code_block
    type 'a t = 'a list

    Options , 2
    Text {|  <p>b</p>|}
    Newline |xxx}]

(* A ( and a * split across a line boundary do not open a comment. *)

let%expect_test _ =
  show "let a = (\n* b\n  <p>c</p>\n";
  [%expect {xxx|
    (1, 0) Code_block
    let a = (
    * b

    Options , 2
    Text {|  <p>c</p>|}
    Newline |xxx}]

(* Extension quoted strings {%ext|...|} and {%%ext delim|...|delim} are raw,
   in code and inside comments. *)

let%expect_test _ =
  show "let a = {%html|(*|}\n  <p>b</p>\n";
  [%expect {xxx|
    (1, 0) Code_block
    let a = {%html|(*|}

    Options , 2
    Text {|  <p>b</p>|}
    Newline |xxx}]

let%expect_test _ =
  show "let a = {%sql foo|(*|foo}\n  <p>b</p>\n";
  [%expect {xxx|
    (1, 0) Code_block
    let a = {%sql foo|(*|foo}

    Options , 2
    Text {|  <p>b</p>|}
    Newline |xxx}]

let%expect_test _ =
  show "(* {%html|*)|}\n  <p>c</p>\n*)\n";
  [%expect {xxx|
    (1, 0) Code_block
    (* {%html|*)|}
      <p>c</p>
    *) |xxx}]

(* An apostrophe that continues an identifier does not open a character
   literal. *)

let%expect_test _ =
  show "let _ = x'\"'(* \"\n  <p>Hi</p>\n";
  [%expect {xxx|
    (1, 0) Code_block
    let _ = x'"'(* "

    Options , 2
    Text {|  <p>Hi</p>|}
    Newline |xxx}]

(* An escaped double quote does not close a string, so a comment around one
   stays open. *)

let%expect_test _ =
  show "(* \"\\\"*)\" a\n  <p>b</p>\n*)\n";
  [%expect {|
    (1, 0) Code_block
    (* "\"*)" a
      <p>b</p>
    *) |}]

(* A quoted string inside a comment is raw, so its "*)" does not close the
   comment. *)

let%expect_test _ =
  show "(* {|*)|} a\n  <p>b</p>\n*)\n";
  [%expect {xxx|
    (1, 0) Code_block
    (* {|*)|} a
      <p>b</p>
    *) |xxx}]

(* Comment tracking applies only to OCaml syntax. Reason input is scanned as
   before, so an OCaml comment opening, e.g. the "(*)" operator passed as an
   argument, has no effect on template detection. *)

let%expect_test _ =
  show "let a = f((*), b)\n  <p>c</p>\n";
  [%expect {|
    (1, 0) Code_block
    let a = f((*), b)
      <p>c</p> |}]

let%expect_test _ =
  show ~syntax:`Reason "let a = f((*), b)\n  <p>c</p>\n";
  [%expect {xxx|
    (1, 0) Code_block
    let a = f((*), b)

    Options , 2
    Text {|  <p>c</p>|}
    Newline |xxx}]

(* Template detection is also suppressed on lines that begin inside string
   and quoted string literals. *)

let%expect_test _ =
  show "let icon = {%html|\n  <svg></svg>\n|}\n  <p>b</p>\n";
  [%expect {xxx|
    (1, 0) Code_block
    let icon = {%html|
      <svg></svg>
    |}

    Options , 2
    Text {|  <p>b</p>|}
    Newline |xxx}]

let%expect_test _ =
  show "let s = {|\n  <p>a</p>\n|}\nlet t = ()\n  <p>b</p>\n";
  [%expect {xxx|
    (1, 0) Code_block
    let s = {|
      <p>a</p>
    |}
    let t = ()

    Options , 2
    Text {|  <p>b</p>|}
    Newline |xxx}]

let%expect_test _ =
  show "let s = \"\n  <p>a</p>\n\"\n  <p>b</p>\n";
  [%expect {xxx|
    (1, 0) Code_block
    let s = "
      <p>a</p>
    "

    Options , 2
    Text {|  <p>b</p>|}
    Newline |xxx}]

(* An extension quoted string's attribute id cannot be empty, so "{%|" and
   "{% foo|" do not open quoted strings. *)

let%expect_test _ =
  show "let a = b {%|c\n  <p>d</p>\n";
  [%expect {xxx|
    (1, 0) Code_block
    let a = b {%|c

    Options , 2
    Text {|  <p>d</p>|}
    Newline |xxx}]
