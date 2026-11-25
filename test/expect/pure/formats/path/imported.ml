(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2021 Anton Bachin *)



(* These tests record Dream's current behavior. They make no claim about
   which behavior is correct, Dream's or the one the upstream tests expect. *)



(* Path tests around dot-segments and encoded separators. No upstream suite
   tests Dream's path splitting directly, so these were added for Dream, as
   each test's "Origin:" comment says. For what dot-segment removal (RFC 3986
   section 5.2.4) would produce, see Go's resolvePathTests (BSD-3-Clause):
   https://github.com/golang/go/blob/5e9534e62225b2f58f3b4b3d410e63f29f6566f5/src/net/url/url_test.go#L1244 *)



let parse s =
  Dream.from_path s
  |> List.map (Printf.sprintf "%S")
  |> String.concat " "
  |> Printf.printf "%-12S -> [%s]\n" s

let render ?relative segments =
  Printf.printf "%S\n" (Dream.to_path ?relative segments)

(* Origin: not from an upstream suite; added for Dream. *)
let%expect_test _ =
  parse "/a/./b";
  parse "/a/../b";
  parse "%2e%2e";
  parse "/%2e%2e/a";
  parse "/.%2e/a";
  parse "a%2Fb%2F";
  parse "/%00";
  parse "/a+b";
  parse "///";
  parse "//";
  [%expect {|
    "/a/./b"     -> ["a" "." "b"]
    "/a/../b"    -> ["a" ".." "b"]
    "%2e%2e"     -> [".."]
    "/%2e%2e/a"  -> [".." "a"]
    "/.%2e/a"    -> [".." "a"]
    "a%2Fb%2F"   -> ["a/b/"]
    "/%00"       -> ["\000"]
    "/a+b"       -> ["a+b"]
    "///"        -> [""]
    "//"         -> [""] |}]

(* Origin: not from an upstream suite; added for Dream. *)
let%expect_test _ =
  render ["."; ".."];
  render ["a b"; "c+d"];
  render ["a?b"; "c#d"];
  render ["a/b"];
  render [""; ""];
  render ~relative:true [""; ""];
  [%expect {|
    "/./.."
    "/a%20b/c%2Bd"
    "/a%3Fb/c%23d"
    "/a%2Fb"
    "/"
    "" |}]
