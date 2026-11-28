(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2021 Anton Bachin *)



(* Cookie test vectors adapted from the test suites of other web frameworks and
   standard libraries. Each expectation below records Dream's current behavior;
   when the upstream suite expects something different, an "Upstream:" comment
   says what it expects. Each test starts with an "Origin:" comment naming the
   upstream test and line it comes from, or saying that it was added for Dream.

   Sources (inputs adapted, not code copied):

   - Go net/http, src/net/http/cookie_test.go (BSD-3-Clause)
     https://github.com/golang/go/blob/5e9534e62225b2f58f3b4b3d410e63f29f6566f5/src/net/http/cookie_test.go
   - jshttp/cookie 2.0.2, src/parse-cookie.spec.ts and
     src/stringify-set-cookie.spec.ts (MIT)
     https://github.com/jshttp/cookie/tree/a437ef03993af559900010f62c294647589c29db/src
   - Werkzeug, tests/test_http.py (BSD-3-Clause)
     https://github.com/pallets/werkzeug/blob/0f43c6ebd426039e4b99ec22535c2c8a2ec2f69f/tests/test_http.py
   - CPython, Lib/test/test_http_cookies.py (PSF-2.0)
     https://github.com/python/cpython/blob/59829477e0b03008c23e6901d655a1e9b0bb2c62/Lib/test/test_http_cookies.py *)



let parse string =
  string
  |> Dream.from_cookie
  |> List.map (fun (name, value) -> Printf.sprintf "%S=%S" name value)
  |> String.concat "; "
  |> Printf.printf "[%s]\n"

let show =
  Printf.printf "%S\n"



(* Parsing Cookie: headers. *)

(* Origin: Go cookie_test.go, readCookiesTests (L439). *)
let%expect_test _ =
  parse "Cookie-1=\"v$1\"; c2=\"v2\"";
  parse "Cookie-1=\"v$1\"; c2=v2;";
  [%expect {|
    ["c2"="\"v2\""; "Cookie-1"="\"v$1\""]
    ["c2"="v2"; "Cookie-1"="\"v$1\""] |}]
  (* Upstream (Go): quotes around values are stripped. *)

(* Origin: Go cookie_test.go, TestParseCookie (L782) and readCookiesTests
   (L499): at most defaultCookieMaxNum = 3000 cookies are accepted. *)
let%expect_test _ =
  let header = String.concat ";" (List.init 3001 (fun _ -> "a=")) in
  Printf.printf "%i\n" (List.length (Dream.from_cookie header));
  [%expect {| 3001 |}]

(* Origin: CPython test_http_cookies.py, test_unquote (L110). *)
let%expect_test _ =
  parse "a=\"b=\\\"\"";
  [%expect {| [] |}]
  (* Upstream (CPython): a="b=\"" once unquoted. *)

(* Origin: Werkzeug test_http.py, test_parse_cookie (L380). *)
let%expect_test _ =
  parse
    "dismiss-top=6; CP=null*; PHPSESSID=0a539d42abc001cdc762809248d4beed;\
     a=42; b=\"\\\";\"; ; fo234{=bar;blub=Blah; \"__Secure-c\"=d;\
     ==__Host-eq=bad;__Host-eq=good;";
  [%expect {| ["__Host-eq"="good"; "\"__Secure-c\""="d"; "blub"="Blah"; "fo234{"="bar"; "b"="\"\\\""; "a"="42"; "PHPSESSID"="0a539d42abc001cdc762809248d4beed"; "CP"="null*"; "dismiss-top"="6"] |}]
  (* Upstream (Werkzeug): the quoted name "__Secure-c" and "==__Host-eq=bad"
     are dropped, as a guard against cookie prefix spoofing, and b is
     "\";". No action on the names: neither yields a cookie named
     __Secure-c or __Host-eq, since the first keeps its quotes and the second
     is dropped (or, with #476, gets the empty name). The value of b depends
     on unquoting, an open question recorded at from_cookie in
     src/pure/formats.ml. *)

(* Origin: Werkzeug test_http.py, test_cookie_quoting (L433) and
   test_parse_set_cookie_directive (L436). *)
let%expect_test _ =
  parse "foo=\"foo\\054bar\"";
  parse "foo=\"?foo\"; version=\"0.1\";";
  [%expect {|
    ["foo"="\"foo\\054bar\""]
    ["version"="\"0.1\""; "foo"="\"?foo\""] |}]
  (* Upstream (Werkzeug): values are unquoted and octal escapes decoded:
     foo="foo,bar", then foo="?foo" and version="0.1". Unquoting is an open
     question recorded at from_cookie in src/pure/formats.ml. The octal
     escapes need no action: they are a Python convention, not part of
     RFC 6265. *)

(* Origin: Werkzeug test_http.py, test_cookie_unicode_key_value (L452). The
   upstream string is the Latin-1 reading of these UTF-8 bytes. *)
let%expect_test _ =
  parse "\xf0\x9f\x8d\xaa=\xf0\x9f\x90\xad";
  [%expect {| ["\240\159\141\170"="\240\159\144\173"] |}]

(* Origin: CPython test_http_cookies.py, test_basic (L15-L42). Only the
   name=value parts are portable: CPython also reads Set-Cookie attributes
   from these strings. *)
let%expect_test _ =
  parse "chips=ahoy; vienna=finger";
  parse "keebler=\"E=mc2; L=\\\"Loves\\\"; fudge=;\"";
  parse "key:term=value:term";
  parse "a=b; c=[; d=r; f=h";
  [%expect {|
    ["vienna"="finger"; "chips"="ahoy"]
    ["fudge"=""; "L"="\\\"Loves\\\""]
    ["key:term"="value:term"]
    ["f"="h"; "d"="r"; "c"="["; "a"="b"] |}]
  (* Upstream (CPython): the quoted keebler value spans the ';' and is one
     cookie. *)

(* Origin: CPython test_http_cookies.py, test_extra_spaces (L258). *)
let%expect_test _ =
  parse "eggs  =  scrambled  ;  secure  ;  path  =  bar   ; foo=foo   ";
  [%expect {| ["foo"="foo"; "path"="bar"; "eggs"="scrambled"] |}]



(* Serializing Set-Cookie: values. *)

(* Origin: Go cookie_test.go, writeSetCookiesTests (L20), cookies 1-9 and
   15-16 (L25-L87). Go orders attributes differently; the order has no
   meaning. Dream has no Partitioned attribute, so cookie-16 omits it. No
   action on Partitioned: it is a feature Dream does not offer. *)
let%expect_test _ =
  show @@ Dream.to_set_cookie "cookie-1" "v$1";
  show @@ Dream.to_set_cookie "cookie-2" "two" ~max_age:3600.;
  show @@ Dream.to_set_cookie "cookie-3" "three" ~domain:".example.com";
  show @@ Dream.to_set_cookie "cookie-4" "four" ~path:"/restricted/";
  show @@ Dream.to_set_cookie "cookie-5" "five" ~domain:"wrong;bad.abc";
  show @@ Dream.to_set_cookie "cookie-6" "six" ~domain:"bad-.abc";
  show @@ Dream.to_set_cookie "cookie-7" "seven" ~domain:"127.0.0.1";
  show @@ Dream.to_set_cookie "cookie-8" "eight" ~domain:"::1";
  show @@ Dream.to_set_cookie "cookie-9" "expiring" ~expires:1257894000.;
  show @@ Dream.to_set_cookie "cookie-13" "samesite-lax" ~same_site:`Lax;
  show @@ Dream.to_set_cookie "cookie-14" "samesite-strict" ~same_site:`Strict;
  show @@ Dream.to_set_cookie "cookie-15" "samesite-none" ~same_site:`None;
  show @@ Dream.to_set_cookie "cookie-16" "partitioned" ~same_site:`None
    ~secure:true ~path:"/";
  [%expect {|
    "cookie-1=v$1"
    "cookie-2=two; Max-Age=3600"
    "cookie-3=three; Domain=.example.com"
    "cookie-4=four; Path=/restricted/"
    "cookie-5=five; Domain=wrong;bad.abc"
    "cookie-6=six; Domain=bad-.abc"
    "cookie-7=seven; Domain=127.0.0.1"
    "cookie-8=eight; Domain=::1"
    "cookie-9=expiring; Expires=Tue, 10 Nov 2009 23:00:00 GMT"
    "cookie-13=samesite-lax; SameSite=Lax"
    "cookie-14=samesite-strict; SameSite=Strict"
    "cookie-15=samesite-none; SameSite=None"
    "cookie-16=partitioned; Path=/; Secure; SameSite=None" |}]
  (* Upstream (Go): Domain drops a leading dot; invalid domains
     ("wrong;bad.abc", "bad-.abc", "::1") are omitted. The leading dot needs
     no action: user agents ignore it (RFC 6265 §5.2.3). Invalid domains are
     a decision recorded at to_set_cookie in src/pure/formats.ml. *)

(* Origin: Go cookie_test.go, writeSetCookiesTests (L92-L152): special values,
   the empty value, and invalid names. *)
let%expect_test _ =
  show @@ Dream.to_set_cookie "special-1" "a z";
  show @@ Dream.to_set_cookie "special-2" " z";
  show @@ Dream.to_set_cookie "special-3" "a ";
  show @@ Dream.to_set_cookie "special-4" " ";
  show @@ Dream.to_set_cookie "special-5" "a,z";
  show @@ Dream.to_set_cookie "special-6" ",z";
  show @@ Dream.to_set_cookie "special-7" "a,";
  show @@ Dream.to_set_cookie "special-8" ",";
  show @@ Dream.to_set_cookie "empty-value" "";
  show @@ Dream.to_set_cookie "\t" "";
  show @@ Dream.to_set_cookie "\r" "";
  show @@ Dream.to_set_cookie "a\nb" "v";
  show @@ Dream.to_set_cookie "a\rb" "v";
  [%expect {|
    "special-1=a z"
    "special-2= z"
    "special-3=a "
    "special-4= "
    "special-5=a,z"
    "special-6=,z"
    "special-7=a,"
    "special-8=,"
    "empty-value="
    "\t="
    "\r="
    "a\nb=v"
    "a\rb=v" |}]
  (* Upstream (Go): values containing a space or comma are double-quoted;
     cookies with invalid names are not emitted at all. *)

(* Origin: Go cookie_test.go, TestCookieSanitizeValue (L555) and
   TestCookieSanitizePath (L591). *)
let%expect_test _ =
  show @@ Dream.to_set_cookie "a" "foo;bar";
  show @@ Dream.to_set_cookie "a" "foo\\bar";
  show @@ Dream.to_set_cookie "a" "foo\"bar";
  show @@ Dream.to_set_cookie "a" "\x00\x7e\x7f\x80";
  show @@ Dream.to_set_cookie "a" "b" ~path:"/path with space/";
  show @@ Dream.to_set_cookie "a" "b" ~path:"/just;no;semicolon\x00orstuff/";
  [%expect {|
    "a=foo;bar"
    "a=foo\\bar"
    "a=foo\"bar"
    "a=\000~\127\128"
    "a=b; Path=/path with space/"
    "a=b; Path=/just;no;semicolon\000orstuff/" |}]
  (* Upstream (Go): invalid bytes (';', '\', '"', controls, non-ASCII) are
     removed from values and paths. *)

(* Origin: not from an upstream suite; added for Dream. Go turns a negative
   MaxAge into Max-Age=0 (in cookie.go, not in its tests). *)
let%expect_test _ =
  show @@ Dream.to_set_cookie "a" "b" ~max_age:(-1.);
  [%expect {| "a=b; Max-Age=0" |}]

(* Origin: jshttp/cookie stringify-set-cookie.spec.ts, "should URL-encode
   value" (L15) and "should pass through roundtrip-safe cookie-octet values"
   (L24). *)
let%expect_test _ =
  show @@ Dream.to_set_cookie "foo" "bar +baz";
  show @@ Dream.to_set_cookie "foo"
    "!#$&'()*+-./0123456789:<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[]^_`abcdefghijklmnopqrstuvwxyz{|}~";
  [%expect {xxx|
    "foo=bar +baz"
    "foo=!#$&'()*+-./0123456789:<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[]^_`abcdefghijklmnopqrstuvwxyz{|}~" |xxx}]
  (* Upstream (jshttp): "bar +baz" is percent-encoded by default. *)

(* Origin: jshttp/cookie stringify-set-cookie.spec.ts, invalid names (L76),
   values (L147), domains (L103) and paths (L240). *)
let%expect_test _ =
  List.iter (fun name -> show @@ Dream.to_set_cookie name "v")
    ["foo\n"; "foo\xe2\xa0\x8a"; "foo=bar"; "foo;bar"; "foo bar"; "foo\tbar"];
  List.iter (fun value -> show @@ Dream.to_set_cookie "foo" value)
    ["+\n"; "foo bar"; "foo\tbar"; "foo;bar"; "foo\xe2\xa0\x8a"];
  List.iter (fun domain -> show @@ Dream.to_set_cookie "foo" "bar" ~domain)
    ["example.com\n"; "sub.example.com\x00"; "my site.org"; "domain..com";
     "example.com; Path=/"; "example.com /* inject a comment */"];
  List.iter (fun path -> show @@ Dream.to_set_cookie "foo" "bar" ~path)
    ["/\n"; "/foo\x00"; "/path/with\rnewline"; "/; Path=/sensitive-data";
     "/login\"><script>alert(1)</script>"];
  [%expect {|
    "foo\n=v"
    "foo\226\160\138=v"
    "foo=bar=v"
    "foo;bar=v"
    "foo bar=v"
    "foo\tbar=v"
    "foo=+\n"
    "foo=foo bar"
    "foo=foo\tbar"
    "foo=foo;bar"
    "foo=foo\226\160\138"
    "foo=bar; Domain=example.com\n"
    "foo=bar; Domain=sub.example.com\000"
    "foo=bar; Domain=my site.org"
    "foo=bar; Domain=domain..com"
    "foo=bar; Domain=example.com; Path=/"
    "foo=bar; Domain=example.com /* inject a comment */"
    "foo=bar; Path=/\n"
    "foo=bar; Path=/foo\000"
    "foo=bar; Path=/path/with\rnewline"
    "foo=bar; Path=/; Path=/sensitive-data"
    "foo=bar; Path=/login\"><script>alert(1)</script>" |}]
  (* Upstream (jshttp): every input in this test throws. *)

(* Origin: jshttp/cookie stringify-set-cookie.spec.ts, "with maxAge option"
   (L202-L219). *)
let%expect_test _ =
  show @@ Dream.to_set_cookie "a" "b" ~max_age:infinity;
  show @@ Dream.to_set_cookie "a" "b" ~max_age:3.14;
  show @@ Dream.to_set_cookie "a" "b" ~max_age:1e21;
  show @@ Dream.to_set_cookie "a" "b" ~max_age:1000.;
  show @@ Dream.to_set_cookie "a" "b" ~max_age:0.;
  [%expect {|
    "a=b; Max-Age=34560000"
    "a=b; Max-Age=3"
    "a=b; Max-Age=34560000"
    "a=b; Max-Age=1000"
    "a=b; Max-Age=0" |}]
  (* Upstream (jshttp): Infinity, 3.14 and 1e21 throw. *)

(* Origin: not from an upstream suite; added for Dream. *)
let%expect_test _ =
  show @@ Dream.to_set_cookie "a" "b" ~max_age:nan;
  [%expect {| "a=b" |}]

(* Origin: Werkzeug test_http.py, test_dump_cookie (L397). Werkzeug defaults to
   Path=/, so it is passed explicitly where the upstream output has it. *)
let%expect_test _ =
  show @@ Dream.to_set_cookie "foo" "bar baz blub" ~max_age:360.
    ~http_only:true ~path:"/";
  show @@ Dream.to_set_cookie "key" "xxx/" ~path:"/";
  show @@ Dream.to_set_cookie "key" "xxx=";
  [%expect {|
    "foo=bar baz blub; Max-Age=360; Path=/; HttpOnly"
    "key=xxx/; Path=/"
    "key=xxx=" |}]
  (* Upstream (Werkzeug): "bar baz blub" is double-quoted. *)

(* Origin: CPython test_http_cookies.py, test_extended_encode (L174),
   test_comment_quoting (L323), test_set_secure_httponly_attrs (L205) and
   test_setter (L392). *)
let%expect_test _ =
  show @@ Dream.to_set_cookie "val" "some,funky;stuff";
  show @@ Dream.to_set_cookie "foo" "\xc2\xa9";
  show @@ Dream.to_set_cookie "Customer" "WILE_E_COYOTE" ~secure:true
    ~http_only:true;
  show @@ Dream.to_set_cookie "foo bar" "v";
  show @@ Dream.to_set_cookie "foo@bar" "v";
  [%expect {|
    "val=some,funky;stuff"
    "foo=\194\169"
    "Customer=WILE_E_COYOTE; Secure; HttpOnly"
    "foo bar=v"
    "foo@bar=v" |}]
  (* Upstream (CPython): "some,funky;stuff" becomes
     "\"some\\054funky\\073stuff\"", the value is "\"\\251\"", and the names
     "foo bar" and "foo@bar" are rejected. The octal escapes need no action
     (see above). Invalid names and values are a decision recorded at
     to_set_cookie in src/pure/formats.ml. *)

(* Origin: not from an upstream suite; added for Dream. The full attribute
   set, and SameSite=None without Secure. *)
let%expect_test _ =
  show @@ Dream.to_set_cookie "c" "v" ~path:"/" ~domain:"example.com"
    ~expires:0. ~max_age:3600. ~secure:true ~http_only:true ~same_site:`Lax;
  show @@ Dream.to_set_cookie "a" "b" ~same_site:`None;
  [%expect {|
    "c=v; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Max-Age=3600; Domain=example.com; Path=/; Secure; HttpOnly; SameSite=Lax"
    "a=b; SameSite=None" |}]
