(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2021 Anton Bachin *)



(* Request-target test vectors adapted from Go net/url and from the examples in
   RFC 9112 section 3.2. Expectations record Dream's current behavior;
   "Upstream:" comments note where the source expects something different.
   Each test starts with an "Origin:" comment naming the upstream test and line
   it comes from, or saying that it was added for Dream.

   - Go net/url, src/net/url/url_test.go (BSD-3-Clause)
     https://github.com/golang/go/blob/5e9534e62225b2f58f3b4b3d410e63f29f6566f5/src/net/url/url_test.go
   - RFC 9112, HTTP/1.1, section 3.2
     https://www.rfc-editor.org/rfc/rfc9112#section-3.2 *)



let split target =
  let path, query = Dream.split_target target in
  Printf.printf "%-44S -> %S %S\n" target path query

(* Origin: Go net/url url_test.go, parseRequestURLTests (L777-L801). Go
   rejects "foo.html" and "../dir/" as request URIs. *)
let%expect_test _ =
  split "http://foo.com";
  split "http://foo.com/";
  split "http://foo.com/path";
  split "/";
  split "//not.a.user@not.a.host/just/a/path";
  split "//not.a.user@%66%6f%6f.com/just/a/path/also";
  split "*";
  split "http://192.168.0.1:8080/";
  split "http://[fe80::1]/";
  split "foo.html";
  split "../dir/";
  [%expect {|
    "http://foo.com"                             -> "" ""
    "http://foo.com/"                            -> "/" ""
    "http://foo.com/path"                        -> "/path" ""
    "/"                                          -> "/" ""
    "//not.a.user@not.a.host/just/a/path"        -> "//not.a.user@not.a.host/just/a/path" ""
    "//not.a.user@%66%6f%6f.com/just/a/path/also" -> "//not.a.user@foo.com/just/a/path/also" ""
    "*"                                          -> "*" ""
    "http://192.168.0.1:8080/"                   -> "/" ""
    "http://[fe80::1]/"                          -> "/" ""
    "foo.html"                                   -> "foo.html" ""
    "../dir/"                                    -> "../dir/" "" |}]
  (* Upstream (Go): an absolute-form target with an empty path has request URI
     "/" (requritests, L1694). *)

(* Origin: Go net/url url_test.go, requritests (L1694 and L1703). *)
let%expect_test _ =
  split "http://example.com";
  split "/a b";
  [%expect {|
    "http://example.com"                         -> "" ""
    "/a b"                                       -> "/a%20b" "" |}]
  (* Upstream (Go): the request URIs are "/" and "/a%20b". *)

(* Origin: RFC 9112 sections 3.2.1-3.2.4, one example of each form of
   request-target. *)
let%expect_test _ =
  split "/where?q=now";
  split "http://www.example.org/pub/WWW/TheProject.html";
  split "www.example.com:80";
  split "*";
  [%expect {|
    "/where?q=now"                               -> "/where" "q=now"
    "http://www.example.org/pub/WWW/TheProject.html" -> "/pub/WWW/TheProject.html" ""
    "www.example.com:80"                         -> "80" ""
    "*"                                          -> "*" "" |}]
  (* Upstream (RFC 9112): "www.example.com:80" is the authority-form, used only
     with CONNECT; it is not a path. *)

(* Origin: not from an upstream suite; added for Dream. *)
let%expect_test _ =
  split "http://h?x";
  split "http://h/a//b?q#f";
  split "https://u@h:8080/p?q";
  split "/a?b?c";
  split "/a#b?c";
  split "/%2e%2e/etc";
  split "/%2E%2E/etc";
  split "/a/%2e/b";
  split "/a%2Fb";
  split "/a%252Fb";
  split "/a%zz";
  split "/a%";
  split "/\xce\xbb";
  split "/a%00b";
  split "/?a=b;c=d";
  split "/%3F?x";
  split "/a;b?c";
  [%expect {|
    "http://h?x"                                 -> "" "x"
    "http://h/a//b?q#f"                          -> "/a//b" "q"
    "https://u@h:8080/p?q"                       -> "/p" "q"
    "/a?b?c"                                     -> "/a" "b?c"
    "/a#b?c"                                     -> "/a" ""
    "/%2e%2e/etc"                                -> "/../etc" ""
    "/%2E%2E/etc"                                -> "/../etc" ""
    "/a/%2e/b"                                   -> "/a/./b" ""
    "/a%2Fb"                                     -> "/a%2Fb" ""
    "/a%252Fb"                                   -> "/a%252Fb" ""
    "/a%zz"                                      -> "/a%25zz" ""
    "/a%"                                        -> "/a%25" ""
    "/\206\187"                                  -> "/%CE%BB" ""
    "/a%00b"                                     -> "/a%00b" ""
    "/?a=b;c=d"                                  -> "/" "a=b;c=d"
    "/%3F?x"                                     -> "/%3F" "x"
    "/a;b?c"                                     -> "/a;b" "c" |}]
