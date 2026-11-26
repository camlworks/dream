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
   - CPython, Lib/test/test_urlparse.py, parse_qsl_test_cases (PSF-2.0)
     https://github.com/python/cpython/blob/59829477e0b03008c23e6901d655a1e9b0bb2c62/Lib/test/test_urlparse.py
   - Go net/url, src/net/url/url_test.go, parseTests (BSD-3-Clause)
     https://github.com/golang/go/blob/5e9534e62225b2f58f3b4b3d410e63f29f6566f5/src/net/url/url_test.go
   - Node.js, test/parallel/test-querystring.js, qsTestCases (MIT)
     https://github.com/nodejs/node/blob/5440ac1f66a0986e08519ace929634cfff2a1e82/test/parallel/test-querystring.js
   - servo/rust-url, url/tests/unit.rs, test_form_urlencoded
     (MIT OR Apache-2.0)
     https://github.com/servo/rust-url/blob/ad1c66cbff6e318393d872641e30589ff9687b9c/url/tests/unit.rs *)



let decode string =
  string
  |> Dream.from_form_urlencoded
  |> List.map (fun (name, value) -> Printf.sprintf "%S=%S" name value)
  |> String.concat "; "
  |> Printf.printf "%-24S -> [%s]\n" string

let encode pairs =
  Printf.printf "%S\n" (Dream.to_form_urlencoded pairs)

let round_trip string =
  Printf.printf "%-24S -> %S\n"
    string (Dream.to_form_urlencoded (Dream.from_form_urlencoded string))



(* Origin: WPT url/urlencoded-parser.any.js, L2-L11. WHATWG decodes to UTF-16
   and replaces invalid UTF-8 with U+FFFD; Dream works on bytes and keeps
   them. *)
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

(* Origin: WPT url/urlencoded-parser.any.js, L12-L36, without the cases that
   have empty pieces between '&' separators (next test). *)
let%expect_test _ =
  decode "";
  decode "a";
  decode "a=b";
  decode "a=";
  decode "=b";
  decode "a&a";
  decode "a&b&c";
  decode "a=b&c=d";
  decode "a=a&a=b&a=c";
  decode "a==a";
  decode "a=a+b+c+d";
  decode "%=a";
  decode "%a=a";
  decode "%a_=a";
  decode "%61=a";
  decode "%61+%4d%4D=";
  decode "id=0&value=%";
  decode "b=%2sf%2a";
  decode "b=%2%2af%2a";
  decode "b=%%2a";
  [%expect {|
    ""                       -> []
    "a"                      -> ["a"=""]
    "a=b"                    -> ["a"="b"]
    "a="                     -> ["a"=""]
    "=b"                     -> [""="b"]
    "a&a"                    -> ["a"=""; "a"=""]
    "a&b&c"                  -> ["a"=""; "b"=""; "c"=""]
    "a=b&c=d"                -> ["a"="b"; "c"="d"]
    "a=a&a=b&a=c"            -> ["a"="a"; "a"="b"; "a"="c"]
    "a==a"                   -> ["a"="=a"]
    "a=a+b+c+d"              -> ["a"="a b c d"]
    "%=a"                    -> ["%"="a"]
    "%a=a"                   -> ["%a"="a"]
    "%a_=a"                  -> ["%a_"="a"]
    "%61=a"                  -> ["a"="a"]
    "%61+%4d%4D="            -> ["a MM"=""]
    "id=0&value=%"           -> ["id"="0"; "value"="%"]
    "b=%2sf%2a"              -> ["b"="%2sf*"]
    "b=%2%2af%2a"            -> ["b"="%2*f*"]
    "b=%%2a"                 -> ["b"="%*"] |}]

(* Origin: WPT url/urlencoded-parser.any.js, L17-L19 and L23-L24: empty pieces
   between '&' separators. *)
let%expect_test _ =
  decode "&";
  decode "&a";
  decode "a&";
  decode "a=b&c=d&";
  decode "&&&a=b&&&&c=d&";
  [%expect {|
    "&"                      -> [""=""; ""=""]
    "&a"                     -> [""=""; "a"=""]
    "a&"                     -> ["a"=""; ""=""]
    "a=b&c=d&"               -> ["a"="b"; "c"="d"; ""=""]
    "&&&a=b&&&&c=d&"         -> [""=""; ""=""; ""=""; "a"="b"; ""=""; ""=""; ""=""; "c"="d"; ""=""] |}]
  (* Upstream (WHATWG): empty pieces are skipped: [], [a=""], [a=""],
     [a=b; c=d] and [a=b; c=d]. *)

(* Origin: CPython test_urlparse.py, parse_qsl_test_cases, L18-L32. *)
let%expect_test _ =
  decode "";
  decode "&";
  decode "&&";
  decode "=";
  decode "=a";
  decode "a";
  decode "a=";
  decode "a=b=c";
  decode "a%3Db=c";
  decode "a=b&c=d";
  decode "a=b%26c=d";
  decode "&a=b";
  decode "a=a+b&b=b+c";
  decode "a=1&a=2";
  [%expect {|
    ""                       -> []
    "&"                      -> [""=""; ""=""]
    "&&"                     -> [""=""; ""=""; ""=""]
    "="                      -> [""=""]
    "=a"                     -> [""="a"]
    "a"                      -> ["a"=""]
    "a="                     -> ["a"=""]
    "a=b=c"                  -> ["a"="b=c"]
    "a%3Db=c"                -> ["a=b"="c"]
    "a=b&c=d"                -> ["a"="b"; "c"="d"]
    "a=b%26c=d"              -> ["a"="b&c=d"]
    "&a=b"                   -> [""=""; "a"="b"]
    "a=a+b&b=b+c"            -> ["a"="a b"; "b"="b c"]
    "a=1&a=2"                -> ["a"="1"; "a"="2"] |}]
  (* Upstream (CPython): "&" and "&&" give [], and "&a=b" gives [a=b]. *)

(* Origin: CPython test_urlparse.py, parse_qsl_test_cases, L47-L48 (';' is not
   a separator, since CPython 3.9.2) and L52-L58 (non-ASCII; the bytes
   variants match Dream's byte semantics). *)
let%expect_test _ =
  decode ";a=b";
  decode "a=a+b;b=b+c";
  decode "\xc5\x81=\xc3\xa9";
  decode "%C5%81=%C3%A9";
  decode "%81=%A9";
  [%expect {|
    ";a=b"                   -> [";a"="b"]
    "a=a+b;b=b+c"            -> ["a"="a b;b=b c"]
    "\197\129=\195\169"      -> ["\197\129"="\195\169"]
    "%C5%81=%C3%A9"          -> ["\197\129"="\195\169"]
    "%81=%A9"                -> ["\129"="\169"] |}]

(* Origin: Go net/url url_test.go, parseTests (L1521-L1600). Since Go 1.17,
   ParseQuery reports an error for a ';' and drops the pair containing it. *)
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

(* Origin: Node test-querystring.js, qsTestCases (L40-L108). Node collapses
   duplicate keys into arrays; Dream keeps the pairs in order. *)
let%expect_test _ =
  decode "foo=bar";
  decode "foo=bar&foo=quux";
  decode "foo=1&bar=2";
  decode "my+weird+field=q1%212%22%27w%245%267%2Fz8%29%3F";
  decode "foo%3Dbaz=bar";
  decode "foo=baz=bar";
  decode " foo = bar ";
  decode "foo=%zx";
  decode "foo=%EF%BF%BD";
  decode "foo&bar=baz";
  decode "a=b&c&d=e";
  decode "a=b&c=&d=e";
  decode "a=b&=c&d=e";
  decode "a=b&=&c=d";
  decode "=";
  decode "+";
  decode "+=";
  decode "=+";
  decode "a=&a=value&a=";
  decode "foo+bar=baz+quux";
  decode "+foo=+bar";
  decode "a+";
  decode "=a+";
  decode "%20+";
  decode "=%20+";
  [%expect {|
    "foo=bar"                -> ["foo"="bar"]
    "foo=bar&foo=quux"       -> ["foo"="bar"; "foo"="quux"]
    "foo=1&bar=2"            -> ["foo"="1"; "bar"="2"]
    "my+weird+field=q1%212%22%27w%245%267%2Fz8%29%3F" -> ["my weird field"="q1!2\"'w$5&7/z8)?"]
    "foo%3Dbaz=bar"          -> ["foo=baz"="bar"]
    "foo=baz=bar"            -> ["foo"="baz=bar"]
    " foo = bar "            -> [" foo "=" bar "]
    "foo=%zx"                -> ["foo"="%zx"]
    "foo=%EF%BF%BD"          -> ["foo"="\239\191\189"]
    "foo&bar=baz"            -> ["foo"=""; "bar"="baz"]
    "a=b&c&d=e"              -> ["a"="b"; "c"=""; "d"="e"]
    "a=b&c=&d=e"             -> ["a"="b"; "c"=""; "d"="e"]
    "a=b&=c&d=e"             -> ["a"="b"; ""="c"; "d"="e"]
    "a=b&=&c=d"              -> ["a"="b"; ""=""; "c"="d"]
    "="                      -> [""=""]
    "+"                      -> [" "=""]
    "+="                     -> [" "=""]
    "=+"                     -> [""=" "]
    "a=&a=value&a="          -> ["a"=""; "a"="value"; "a"=""]
    "foo+bar=baz+quux"       -> ["foo bar"="baz quux"]
    "+foo=+bar"              -> [" foo"=" bar"]
    "a+"                     -> ["a "=""]
    "=a+"                    -> [""="a "]
    "%20+"                   -> ["  "=""]
    "=%20+"                  -> [""="  "] |}]

(* Origin: Node test-querystring.js, qsTestCases (L80-L108): the cases with
   empty pieces between '&' separators. *)
let%expect_test _ =
  decode "&&foo=bar&&";
  decode "&";
  decode "&&&&";
  decode "&=&";
  decode "&=&=";
  decode "+&";
  decode "+=&";
  decode "a&&b";
  decode "a=a&&b=b";
  decode "&a";
  decode "&=";
  decode "a&a&";
  decode "a+&";
  decode "=a+&";
  decode "%20+&";
  decode "=%20+&";
  [%expect {|
    "&&foo=bar&&"            -> [""=""; ""=""; "foo"="bar"; ""=""; ""=""]
    "&"                      -> [""=""; ""=""]
    "&&&&"                   -> [""=""; ""=""; ""=""; ""=""; ""=""]
    "&=&"                    -> [""=""; ""=""; ""=""]
    "&=&="                   -> [""=""; ""=""; ""=""]
    "+&"                     -> [" "=""; ""=""]
    "+=&"                    -> [" "=""; ""=""]
    "a&&b"                   -> ["a"=""; ""=""; "b"=""]
    "a=a&&b=b"               -> ["a"="a"; ""=""; "b"="b"]
    "&a"                     -> [""=""; "a"=""]
    "&="                     -> [""=""; ""=""]
    "a&a&"                   -> ["a"=""; "a"=""; ""=""]
    "a+&"                    -> ["a "=""; ""=""]
    "=a+&"                   -> [""="a "; ""=""]
    "%20+&"                  -> ["  "=""; ""=""]
    "=%20+&"                 -> [""="  "; ""=""] |}]
  (* Upstream (Node): empty pieces are skipped, so "&" and "&&&&" give {},
     "&=&" gives {"": ""}, and "&=&=" gives {"": ["", ""]}. *)

(* Origin: rust-url url/tests/unit.rs, test_form_urlencoded (L436). *)
let%expect_test _ =
  decode "foo=%C3%A9%26&bar=&foo=%23";
  [%expect {| "foo=%C3%A9%26&bar=&foo=%23" -> ["foo"="\195\169&"; "bar"=""; "foo"="#"] |}]

(* Origin: not from an upstream suite; added for Dream. Commas, NUL bytes,
   '#', encoded '+', and Node's "foo:bar" case (qsColonTestCases, L115) read
   with the default separators. *)
let%expect_test _ =
  decode "a=b,c";
  decode "a=b%2Cc";
  decode "a=%00";
  decode "a=b#c";
  decode "a=%2B";
  decode "a=+%2B+";
  decode "foo:bar";
  [%expect {|
    "a=b,c"                  -> ["a"="b,c"]
    "a=b%2Cc"                -> ["a"="b,c"]
    "a=%00"                  -> ["a"="\000"]
    "a=b#c"                  -> ["a"="b#c"]
    "a=%2B"                  -> ["a"="+"]
    "a=+%2B+"                -> ["a"=" + "]
    "foo:bar"                -> ["foo:bar"=""] |}]



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
  (* Upstream (WHATWG): "a=b+c", "a+b=c", and "b=%3D". *)

(* Origin: WPT url/urlsearchparams-stringifier.any.js, "URLSearchParams
   connected to URL" (L125) and "must not do newline normalization"
   (L141). *)
let%expect_test _ =
  encode ["a", "b,c"];
  encode ["a\nb", "c\rd"; "e\n\rf", "g\r\nh"];
  [%expect {|
    "a=b%2Cc"
    "a%0Ab=c%0Dd&e%0A%0Df=g%0D%0Ah" |}]

(* Origin: rust-url url/tests/unit.rs, test_form_urlencoded (L436). *)
let%expect_test _ =
  encode ["foo", "\xc3\xa9&"; "bar", ""; "foo", "#"];
  [%expect {| "foo=%C3%A9%26&bar=&foo=%23" |}]

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
     "+%3F%26%3D%23%2B%25%21%3C%3E%23%22%7B%7D%7C%5C%5E%5B%5D%60%E2%98%BA%09%3A%2F%40%24%27%28%29%2A%2C%3B". *)

(* Origin: WPT url/urlsearchparams-stringifier.any.js, "URLSearchParams.toString"
   (L104-L122): parse, then serialize. *)
let%expect_test _ =
  round_trip "a=b&c=d&&e&&";
  round_trip "a = b &a=b&c=d%20";
  round_trip "a=&a=b";
  round_trip "b=%2sf%2a";
  round_trip "b=%2%2af%2a";
  round_trip "b=%%2a";
  [%expect {|
    "a=b&c=d&&e&&"           -> "a=b&c=d&=&e=&=&="
    "a = b &a=b&c=d%20"      -> "a%20=%20b%20&a=b&c=d%20"
    "a=&a=b"                 -> "a=&a=b"
    "b=%2sf%2a"              -> "b=%252sf*"
    "b=%2%2af%2a"            -> "b=%252*f*"
    "b=%%2a"                 -> "b=%25*" |}]
  (* Upstream (WHATWG): "a=b&c=d&e=" and "a+=+b+&a=b&c=d+". *)

(* Origin: WPT url/urlsearchparams-stringifier.any.js, L83 (the URLSearchParams
   is built from "id=0&value=%"). *)
let%expect_test _ =
  round_trip "id=0&value=%";
  [%expect {| "id=0&value=%"           -> "id=0&value=%25" |}]
