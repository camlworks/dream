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
     https://github.com/golang/go/blob/5e9534e62225b2f58f3b4b3d410e63f29f6566f5/src/net/url/url_test.go *)



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
