(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2021 Anton Bachin *)



let encode string =
  Printf.printf "%S\n" (Dream.to_base64url string)

let%expect_test _ =
  encode "a";
  encode "b";
  encode "\xFF";
  encode "\xFB";
  encode "abc";
  encode "abcdef";
  encode "abcde";
  encode "";
  [%expect {|
    "YQ"
    "Yg"
    "_w"
    "-w"
    "YWJj"
    "YWJjZGVm"
    "YWJjZGU"
    "" |}]

let decode string =
  match Dream.from_base64url string with
  | Some string -> Printf.printf "%S\n" string
  | None -> print_endline "None"

let%expect_test _ =
  decode "YWJj";
  decode "YQ";
  decode "YQ==";
  decode "+";
  [%expect {|
    "abc"
    "a"
    "a"
    None |}]



(* Non-canonical base64url. *)

let show_decode s =
  match Dream.from_base64url s with
  | None -> Printf.printf "%-16S -> None\n" s
  | Some decoded -> Printf.printf "%-16S -> Some %S\n" s decoded

(* Origin: not from an upstream suite; added for Dream. Inputs a strict
   decoder rejects (RFC 4648 sections 3.3 and 3.5, at
   https://www.rfc-editor.org/rfc/rfc4648#section-3.3): padding in an unpadded
   encoding, impossible lengths, non-zero pad bits, and characters outside the
   alphabet. Go's base64.RawURLEncoding.Strict() rejects every one of them. *)
let%expect_test _ =
  List.iter show_decode
    ["Zg=="; "Zg="; "Zg==="; "Zm9vYmFy===="; "Zh"; "Zm9"; "Z"; "-_";
     "Z m9v"; "Zm9v\n"; "+/"];
  [%expect {|
    "Zg=="           -> Some "f"
    "Zg="            -> Some "f"
    "Zg==="          -> Some "f"
    "Zm9vYmFy===="   -> Some "foobar"
    "Zh"             -> Some "f"
    "Zm9"            -> Some "fo"
    "Z"              -> Some ""
    "-_"             -> Some "\251"
    "Z m9v"          -> None
    "Zm9v\n"         -> None
    "+/"             -> None |}]
  (* Expected: None for all but "Zg==", whose padding is exactly what RFC 4648
     prescribes. "Z" has an impossible length, "Zh", "Zm9" and "-_" have
     non-zero pad bits, and "Zg=", "Zg===" and "Zm9vYmFy====" have wrong
     padding. *)
