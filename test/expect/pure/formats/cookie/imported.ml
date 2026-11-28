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

(* Origin: Go cookie_test.go, TestParseCookie (L742), lines L754-L778. *)
let%expect_test _ =
  parse "Cookie-1=v$1";
  parse "Cookie-1=v$1;c2=v2";
  parse "k1=";
  parse "equal-not-found";
  parse "=v1";
  parse "k1=\\";
  [%expect {|
    ["Cookie-1"="v$1"]
    ["c2"="v2"; "Cookie-1"="v$1"]
    ["k1"=""]
    []
    [""="v1"]
    ["k1"="\\"] |}]
  (* Upstream (Go): "=v1" (empty name) and a value of a single backslash (not a
     cookie-octet) are errors. No action: the application receives these pieces
     as sent, and neither can be read as another cookie. *)

(* Origin: jshttp/cookie parse-cookie.spec.ts, L15-L74 and L93. *)
let%expect_test _ =
  parse "foo=bar";
  parse "FOO    = bar;   baz  =   raz";
  parse " \t ";
  parse "foo=; bar=";
  parse "f=;b=";
  parse "email=%20%22%2c%3b%2f";
  parse "  foo  =  \"bar\"  ";
  parse " foo = \" a b c \" ";
  parse " = bar ";
  parse "   =   ";
  parse "\tfoo\t=\tbar\t";
  parse "foo=%1;bar=bar";
  parse "foo=bar;fizz  ;  buzz";
  parse "  fizz; foo=  bar";
  parse "toString=foo;valueOf=bar";
  [%expect {|
    ["foo"="bar"]
    ["baz"="raz"; "FOO"="bar"]
    []
    ["bar"=""; "foo"=""]
    ["b"=""; "f"=""]
    ["email"="%20%22%2c%3b%2f"]
    ["foo"="\"bar\""]
    ["foo"="\" a b c \""]
    [""="bar"]
    [""=""]
    ["foo"="bar"]
    ["bar"="bar"; "foo"="%1"]
    ["foo"="bar"]
    ["foo"="bar"]
    ["valueOf"="bar"; "toString"="foo"] |}]
  (* Upstream (jshttp): values are percent-decoded by default. No action: Dream
     returns raw values (see Dream.from_cookie and Dream.all_cookies), so an
     application decodes whatever encoding it chose when setting them. *)

(* Origin: Werkzeug test_http.py, test_bad_cookies (L410). *)
let%expect_test _ =
  parse "first=IamTheFirst ; a=1; oops ; a=2 ;second = andMeTwo;";
  parse "spam=ham; duck=mallard; ; ";
  [%expect {|
    ["second"="andMeTwo"; "a"="2"; "a"="1"; "first"="IamTheFirst"]
    ["duck"="mallard"; "spam"="ham"] |}]
  (* Upstream (Werkzeug): "oops" gets an empty value. No action: RFC 6265
     §4.2.1 requires '=' in every cookie-pair, so a conforming client never
     sends such a piece. *)

(* Origin: CPython test_http_cookies.py, test_invalid_cookies (L293) and
   test_illegal_chars (L317). *)
let%expect_test _ =
  parse "]foo=x";
  parse "[foo=x";
  parse "blah]foo=x";
  parse "Set-Cookie: foo=bar";
  parse "a=b; c,d=e";
  [%expect {|
    ["]foo"="x"]
    ["[foo"="x"]
    ["blah]foo"="x"]
    ["Set-Cookie: foo"="bar"]
    ["c,d"="e"; "a"="b"] |}]
  (* Upstream (CPython): all rejected entirely. No action: these names are not
     RFC 6265 tokens, but the application receives them as sent, and none can
     be read as another cookie. *)



(* Serializing Set-Cookie: values. *)

(* Origin: Werkzeug test_http.py, test_cookie_quoting (L430),
   test_cookie_domain_resolving (L439) and test_cookie_unicode_dumping
   (L443). *)
let%expect_test _ =
  show @@ Dream.to_set_cookie "foo" "?foo" ~path:"/";
  show @@ Dream.to_set_cookie "foo" "bar" ~domain:"\xe2\x98\x83.com" ~path:"/";
  show @@ Dream.to_set_cookie "foo" "\xe2\x98\x83" ~path:"/";
  [%expect {|
    "foo=?foo; Path=/"
    "foo=bar; Domain=\226\152\131.com; Path=/"
    "foo=\226\152\131; Path=/" |}]
  (* Upstream (Werkzeug): the domain is IDNA-encoded (xn--n3h.com), and the
     value is octal-escaped: "\"\\342\\230\\203\"". No action: Dream writes
     the bytes it is given; IDNA conversion is left to the caller, and octal
     escapes are a Python convention, not part of RFC 6265. *)

(* Origin: Werkzeug test_http.py, test_cookie_maxsize (L473). *)
let%expect_test _ =
  let value = String.concat "" (List.init 1360 (fun _ -> "bar")) in
  Printf.printf "%i\n" (String.length (Dream.to_set_cookie "foo" (value ^ "b")));
  Printf.printf "%i\n"
    (String.length (Dream.to_set_cookie "foo" (value ^ "ba")));
  [%expect {|
    4085
    4086 |}]
  (* Upstream (Werkzeug): the first is 4093 bytes long with its default
     "; Path=/"; the second triggers a "cookie is too large" warning. No
     action: Dream enforces no cookie size or count limits; user agents apply
     their own (RFC 6265 §6.1). *)
