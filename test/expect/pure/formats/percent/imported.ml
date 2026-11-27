(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2021 Anton Bachin *)



(* Percent-encoding test vectors adapted from other projects' test suites.
   Expectations record Dream's current behavior; "Upstream:" comments note
   where the source expects something different. Each test starts with an
   "Origin:" comment naming the upstream test and line it comes from, or
   saying that it was added for Dream.

   Sources (inputs adapted, not code copied):

   - Go net/url, src/net/url/url_test.go, unescapeTests and pathEscapeTests
     (BSD-3-Clause)
     https://github.com/golang/go/blob/5e9534e62225b2f58f3b4b3d410e63f29f6566f5/src/net/url/url_test.go
   - Node.js, test/parallel/test-querystring.js, qsUnescapeTestCases (MIT)
     https://github.com/nodejs/node/blob/5440ac1f66a0986e08519ace929634cfff2a1e82/test/parallel/test-querystring.js
   - CPython, Lib/test/test_urllib.py, unquote tests (PSF-2.0)
     https://github.com/python/cpython/blob/59829477e0b03008c23e6901d655a1e9b0bb2c62/Lib/test/test_urllib.py *)



let decode s =
  Printf.printf "%-28S -> %S\n" s (Dream.from_percent_encoded s)

let encode ?international s =
  Printf.printf "%S\n" (Dream.to_percent_encoded ?international s)



(* Origin: Go net/url url_test.go, unescapeTests (L995), checked with
   QueryUnescape. *)
let%expect_test _ =
  decode "";
  decode "abc";
  decode "1%41";
  decode "1%41%42%43";
  decode "%4a";
  decode "%6F";
  decode "%";
  decode "%a";
  decode "%1";
  decode "123%45%6";
  decode "%zzzzz";
  decode "a+b";
  decode "a%20b";
  [%expect {|
    ""                           -> ""
    "abc"                        -> "abc"
    "1%41"                       -> "1A"
    "1%41%42%43"                 -> "1ABC"
    "%4a"                        -> "J"
    "%6F"                        -> "o"
    "%"                          -> "%"
    "%a"                         -> "%a"
    "%1"                         -> "%1"
    "123%45%6"                   -> "123E%6"
    "%zzzzz"                     -> "%zzzzz"
    "a+b"                        -> "a+b"
    "a%20b"                      -> "a b" |}]
  (* Upstream (Go): "%", "%a", "%1", "123%45%6" and "%zzzzz" are errors, and
     "a+b" decodes to "a b" (query unescaping). No action: WHATWG, Node and
     CPython also pass malformed escapes through, and '+' means a space only in
     form data, which Dream.from_form_urlencoded decodes. *)

(* Origin: Node test-querystring.js, qsUnescapeTestCases (L170-L181). *)
let%expect_test _ =
  decode "there%2Qare%0-fake%escaped values in%%%%this%9Hstring";
  decode "%20%21%22%23%24%25%26%27%28%29%2A%2B%2C%2D%2E%2F%30%31%32%33%34%35%36%37";
  decode "%%2a";
  decode "%2sf%2a";
  decode "%2%2af%2a";
  [%expect {|
    "there%2Qare%0-fake%escaped values in%%%%this%9Hstring" -> "there%2Qare%0-fake%escaped values in%%%%this%9Hstring"
    "%20%21%22%23%24%25%26%27%28%29%2A%2B%2C%2D%2E%2F%30%31%32%33%34%35%36%37" -> " !\"#$%&'()*+,-./01234567"
    "%%2a"                       -> "%*"
    "%2sf%2a"                    -> "%2sf*"
    "%2%2af%2a"                  -> "%2*f*" |}]

(* Origin: Node test-querystring.js, unescapeBuffer (L382 and L409-L413). *)
let%expect_test _ =
  decode "%d3%f2Ug%1f6v%24%5e%98%cb%0d%ac%a2%2f%9d%eb%d8%a2%e6";
  decode "a%";
  decode "a%2";
  decode "a%20";
  decode "a%2g";
  decode "a%%";
  [%expect {|
    "%d3%f2Ug%1f6v%24%5e%98%cb%0d%ac%a2%2f%9d%eb%d8%a2%e6" -> "\211\242Ug\0316v$^\152\203\r\172\162/\157\235\216\162\230"
    "a%"                         -> "a%"
    "a%2"                        -> "a%2"
    "a%20"                       -> "a "
    "a%2g"                       -> "a%2g"
    "a%%"                        -> "a%%" |}]

(* Origin: CPython test_urllib.py, test_unquoting_badpercent (L1109),
   test_unquoting_mixed_case (L1145), test_unquoting_plus (L1166), and the
   UTF-8 tests at L1179 and L1229. *)
let%expect_test _ =
  decode "%xab";
  decode "%x";
  decode "%";
  decode "%Ab%eA";
  decode "are+there+spaces...";
  decode "br%C3%BCckner_sapporo_20050930.doc";
  decode "%E6%BC%A2%E5%AD%97";
  [%expect {|
    "%xab"                       -> "%xab"
    "%x"                         -> "%x"
    "%"                          -> "%"
    "%Ab%eA"                     -> "\171\234"
    "are+there+spaces..."        -> "are+there+spaces..."
    "br%C3%BCckner_sapporo_20050930.doc" -> "br\195\188ckner_sapporo_20050930.doc"
    "%E6%BC%A2%E5%AD%97"         -> "\230\188\162\229\173\151" |}]

(* Origin: not from an upstream suite; added for Dream. *)
let%expect_test _ =
  decode "%00";
  decode "%252F";
  decode "%G0";
  decode "%0";
  [%expect {|
    "%00"                        -> "\000"
    "%252F"                      -> "%2F"
    "%G0"                        -> "%G0"
    "%0"                         -> "%0" |}]

(* Origin: Go net/url url_test.go, pathEscapeTests (L1138). *)
let%expect_test _ =
  encode ~international:false "";
  encode ~international:false "abc";
  encode ~international:false "abc+def";
  encode ~international:false "a/b";
  encode ~international:false "one two";
  encode ~international:false "10%";
  encode ~international:false " ?&=#+%!<>#\"{}|\\^[]`\xe2\x98\xba\t:/@$'()*,;";
  encode " ?&=#+%!<>#\"{}|\\^[]`\xe2\x98\xba\t:/@$'()*,;";
  [%expect {|
    ""
    "abc"
    "abc%2Bdef"
    "a%2Fb"
    "one%20two"
    "10%25"
    "%20%3F%26%3D%23%2B%25%21%3C%3E%23%22%7B%7D%7C%5C%5E%5B%5D%60%E2%98%BA%09%3A%2F%40%24%27%28%29%2A%2C%3B"
    "%20%3F%26%3D%23%2B%25%21%3C%3E%23%22%7B%7D%7C%5C%5E%5B%5D%60\226\152\186%09%3A%2F%40%24%27%28%29%2A%2C%3B" |}]
  (* Upstream (Go PathEscape): "abc+def", and for the long string
     "%20%3F&=%23+%25%21%3C%3E%23%22%7B%7D%7C%5C%5E%5B%5D%60%E2%98%BA%09:%2F@$%27%28%29%2A%2C%3B".
     No action: escaping a character that may appear raw does not change what
     decoders read. *)

(* Origin: not from an upstream suite; added for Dream. *)
let%expect_test _ =
  encode "*-._~";
  encode "\000";
  encode "a\nb\rc";
  encode "\xff\xfe";
  encode ~international:false "\xff\xfe";
  [%expect {|
    "%2A-._~"
    "%00"
    "a%0Ab%0Dc"
    "\255\254"
    "%FF%FE" |}]
