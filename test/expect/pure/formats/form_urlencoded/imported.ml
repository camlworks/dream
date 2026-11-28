(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2021 Anton Bachin *)



(* application/x-www-form-urlencoded test vectors adapted from other projects'
   test suites. Expectations record Dream's current behavior; "Upstream:"
   comments note where the source expects something different. Each test
   starts with an "Origin:" comment naming the upstream test and line it comes
   from, or saying that it was added for Dream.

   Sources (inputs adapted, not code copied):

   - WHATWG web-platform-tests, url/urlencoded-parser.any.js and
     url/urlsearchparams-stringifier.any.js (BSD-3-Clause)
     https://github.com/web-platform-tests/wpt/tree/c93bdbe1676032a83981d207390b4f6ceeb88a03/url
   - Go net/url, src/net/url/url_test.go, parseTests and queryEscapeTests
     (BSD-3-Clause)
     https://github.com/golang/go/blob/5e9534e62225b2f58f3b4b3d410e63f29f6566f5/src/net/url/url_test.go *)



let decode string =
  string
  |> Dream.from_form_urlencoded
  |> List.map (fun (name, value) -> Printf.sprintf "%S=%S" name value)
  |> String.concat "; "
  |> Printf.printf "%-24S -> [%s]\n" string

let encode pairs =
  Printf.printf "%S\n" (Dream.to_form_urlencoded pairs)

(* Origin: WPT url/urlencoded-parser.any.js, L2-L11. WHATWG decodes to UTF-16
   and replaces invalid UTF-8 with U+FFFD; Dream works on bytes and keeps
   them. No action: replacing bytes would lose data an application may need,
   and an application that wants U+FFFD can replace them itself. *)
let%expect_test _ =
  decode "test";
  decode "\xef\xbb\xbftest=\xef\xbb\xbf";
  decode "%EF%BB%BFtest=%EF%BB%BF";
  decode "%EF%BF%BF=%EF%BF%BF";
  decode "%FE%FF";
  decode "%FF%FE";
  decode "\xe2\x80\xa0&\xe2\x80\xa0=x";
  decode "%C2";
  decode "%C2x";
  decode "_charset_=windows-1252&test=%C2x";
  [%expect {|
    "test"                   -> ["test"=""]
    "\239\187\191test=\239\187\191" -> ["\239\187\191test"="\239\187\191"]
    "%EF%BB%BFtest=%EF%BB%BF" -> ["\239\187\191test"="\239\187\191"]
    "%EF%BF%BF=%EF%BF%BF"    -> ["\239\191\191"="\239\191\191"]
    "%FE%FF"                 -> ["\254\255"=""]
    "%FF%FE"                 -> ["\255\254"=""]
    "\226\128\160&\226\128\160=x" -> ["\226\128\160"=""; "\226\128\160"="x"]
    "%C2"                    -> ["\194"=""]
    "%C2x"                   -> ["\194x"=""]
    "_charset_=windows-1252&test=%C2x" -> ["_charset_"="windows-1252"; "test"="\194x"] |}]

(* Origin: Go net/url url_test.go, parseTests (L1521-L1600). Since Go 1.17,
   ParseQuery reports an error for a ';' and drops the pair containing it. No
   action: Dream keeps ';' as a literal, as WHATWG, Node and CPython (since
   3.9.2) do. *)
let%expect_test _ =
  decode "a=1";
  decode "a=1&b=2";
  decode "a=1&a=2&a=banana";
  decode "ascii=%3Ckey%3A+0x90%3E";
  decode "a=1;b=2";
  decode "a;b=1";
  decode "a=%3B";
  decode "a%3Bb=1";
  decode "a=1&a=2;a=banana";
  decode "a;b&c=1";
  decode "a=1&b=2;a=3&c=4";
  decode "a=1&b=2;c=3";
  decode ";";
  decode "a=1;";
  decode "a=1&;";
  decode ";a=1&b=2";
  decode "a=1&b=2;";
  [%expect {|
    "a=1"                    -> ["a"="1"]
    "a=1&b=2"                -> ["a"="1"; "b"="2"]
    "a=1&a=2&a=banana"       -> ["a"="1"; "a"="2"; "a"="banana"]
    "ascii=%3Ckey%3A+0x90%3E" -> ["ascii"="<key: 0x90>"]
    "a=1;b=2"                -> ["a"="1;b=2"]
    "a;b=1"                  -> ["a;b"="1"]
    "a=%3B"                  -> ["a"=";"]
    "a%3Bb=1"                -> ["a;b"="1"]
    "a=1&a=2;a=banana"       -> ["a"="1"; "a"="2;a=banana"]
    "a;b&c=1"                -> ["a;b"=""; "c"="1"]
    "a=1&b=2;a=3&c=4"        -> ["a"="1"; "b"="2;a=3"; "c"="4"]
    "a=1&b=2;c=3"            -> ["a"="1"; "b"="2;c=3"]
    ";"                      -> [";"=""]
    "a=1;"                   -> ["a"="1;"]
    "a=1&;"                  -> ["a"="1"; ";"=""]
    ";a=1&b=2"               -> [";a"="1"; "b"="2"]
    "a=1&b=2;"               -> ["a"="1"; "b"="2;"] |}]

(* Origin: WPT url/urlsearchparams-stringifier.any.js, L3-L101. WHATWG
   encodes space as '+'. *)
let%expect_test _ =
  encode ["a", "b c"];
  encode ["a b", "c"];
  encode ["a", ""];
  encode ["a", ""; "a", ""];
  encode ["", "b"];
  encode ["", ""];
  encode ["a", "b+c"];
  encode ["a+b", "c"];
  encode ["=", "a"];
  encode ["b", "="];
  encode ["&", "a"];
  encode ["b", "&"];
  encode ["a", "*-._"];
  encode ["*-._", "c"];
  encode ["a", "b%c"];
  encode ["a%b", "c"];
  encode ["a", "b\000c"];
  encode ["a\000b", "c"];
  encode ["a", "b\xf0\x9f\x92\xa9c"];
  encode ["a\xf0\x9f\x92\xa9b", "c"];
  [%expect {|
    "a=b%20c"
    "a%20b=c"
    "a="
    "a=&a="
    "=b"
    "="
    "a=b%2Bc"
    "a%2Bb=c"
    "%3D=a"
    "b=="
    "%26=a"
    "b=%26"
    "a=*-._"
    "*-._=c"
    "a=b%25c"
    "a%25b=c"
    "a=b%00c"
    "a%00b=c"
    "a=b%F0%9F%92%A9c"
    "a%F0%9F%92%A9b=c" |}]
  (* Upstream (WHATWG): "a=b+c", "a+b=c", and "b=%3D". No action: decoders
     read %20 and '+' alike, and a raw '=' in a value is unambiguous, since a
     pair is split at its first '='. *)

(* Origin: Go net/url url_test.go, queryEscapeTests (L1095), each string used
   as a value, and encodeQueryTests (L1206). *)
let%expect_test _ =
  encode ["q", "one two"];
  encode ["q", "10%"];
  encode ["q", " ?&=#+%!<>#\"{}|\\^[]`\xe2\x98\xba\t:/@$'()*,;"];
  encode ["q", "dogs"; "q", "&"; "q", "7"];
  [%expect {|
    "q=one%20two"
    "q=10%25"
    "q=%20?%26=%23%2B%25!%3C%3E%23%22%7B%7D%7C%5C%5E%5B%5D%60%E2%98%BA%09:/@$'()*%2C%3B"
    "q=dogs&q=%26&q=7" |}]
  (* Upstream (Go QueryEscape): "one+two", and for the long value
     "+%3F%26%3D%23%2B%25%21%3C%3E%23%22%7B%7D%7C%5C%5E%5B%5D%60%E2%98%BA%09%3A%2F%40%24%27%28%29%2A%2C%3B".
     No action: decoders read %20 and '+' alike, and the characters Go escapes
     and Dream doesn't may appear raw in a query. *)
