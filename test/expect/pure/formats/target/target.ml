(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2021 Anton Bachin *)



let decode string =
  string
  |> Dream.split_target
  |> fun (path, query) -> Printf.printf "%S %S\n" path query

let%expect_test _ =
  decode "";
  decode "?";
  decode "/";
  decode "/?";
  decode "/abc/def";
  (* A leading "//" is part of the target path, not an authority (issue #248);
     runs of leading slashes must be preserved verbatim. *)
  decode "//abc/def";
  decode "///abc/def";
  decode "////abc/def";
  (* A standalone "%2F" segment is an encoded slash and must be preserved, not
     collapsed to a bare '/' the way [Uri.path] does. *)
  decode "/abc/%2F/def";
  (* Absolute-form targets (RFC 9112 §3.2.2), as sent to proxies, carry a real
     authority that must be stripped, leaving just the path and query. *)
  decode "http://host/abc/def";
  decode "http://host/abc/def?a=b";
  decode "/abc/def/";
  decode "/abc/def?";
  decode "/abc/def/?";
  decode "/abc?a";
  decode "/abc?a=b&c=d";
  decode "/abc%2F%26def?a=b&c=d%2B";
  decode "/abc/#foo";
  decode "/abc/?de=f#foo";
  [%expect {|
    "" ""
    "" ""
    "/" ""
    "/" ""
    "/abc/def" ""
    "//abc/def" ""
    "///abc/def" ""
    "////abc/def" ""
    "/abc/%2F/def" ""
    "/abc/def" ""
    "/abc/def" "a=b"
    "/abc/def/" ""
    "/abc/def" ""
    "/abc/def/" ""
    "/abc" "a"
    "/abc" "a=b&c=d"
    "/abc%2F&def" "a=b&c=d%2B"
    "/abc/" ""
    "/abc/" "de=f" |}]



(* Absolute-form targets with an empty path, and the authority-form. *)

(* Origin: Go net/url url_test.go, parseRequestURLTests (L777) and requritests
   (L1694), at
   https://github.com/golang/go/blob/5e9534e62225b2f58f3b4b3d410e63f29f6566f5/src/net/url/url_test.go#L1694 *)
let%expect_test _ =
  decode "http://foo.com";
  decode "http://example.com";
  [%expect {|
    "/" ""
    "/" "" |}]

(* Origin: not from an upstream suite; added for Dream. *)
let%expect_test _ =
  decode "http://h?x";
  [%expect {| "/" "x" |}]

(* Origin: RFC 9112 section 3.2.3, the example of the authority-form, at
   https://www.rfc-editor.org/rfc/rfc9112#section-3.2.3 *)
let%expect_test _ =
  decode "www.example.com:80";
  [%expect {| "" "" |}]
