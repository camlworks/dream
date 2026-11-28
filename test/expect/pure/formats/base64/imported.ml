(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2021 Anton Bachin *)



(* base64url test vectors from RFC 4648, mapped to the URL-safe alphabet
   without padding. Each test starts with an "Origin:" comment naming the
   section it comes from, or saying that it was added for Dream.
   https://www.rfc-editor.org/rfc/rfc4648 *)



let encode s =
  Printf.printf "%-24S -> %S\n" s (Dream.to_base64url s)

let decode s =
  match Dream.from_base64url s with
  | None -> Printf.printf "%-16S -> None\n" s
  | Some decoded -> Printf.printf "%-16S -> Some %S\n" s decoded

(* Origin: RFC 4648 section 10 (test vectors) and section 9 (the three
   illustration inputs, 0x14fb9c03d97e and its prefixes). *)
let%expect_test _ =
  encode "";
  encode "f";
  encode "fo";
  encode "foo";
  encode "foob";
  encode "fooba";
  encode "foobar";
  encode "\x14\xfb\x9c\x03\xd9\x7e";
  encode "\x14\xfb\x9c\x03\xd9";
  encode "\x14\xfb\x9c\x03";
  [%expect {|
    ""                       -> ""
    "f"                      -> "Zg"
    "fo"                     -> "Zm8"
    "foo"                    -> "Zm9v"
    "foob"                   -> "Zm9vYg"
    "fooba"                  -> "Zm9vYmE"
    "foobar"                 -> "Zm9vYmFy"
    "\020\251\156\003\217~"  -> "FPucA9l-"
    "\020\251\156\003\217"   -> "FPucA9k"
    "\020\251\156\003"       -> "FPucAw" |}]

(* Origin: RFC 4648 sections 10 and 9, decoded back. *)
let%expect_test _ =
  List.iter decode
    [""; "Zg"; "Zm8"; "Zm9v"; "Zm9vYg"; "Zm9vYmE"; "Zm9vYmFy"; "FPucA9l-";
     "FPucA9k"; "FPucAw"];
  [%expect {|
    ""               -> Some ""
    "Zg"             -> Some "f"
    "Zm8"            -> Some "fo"
    "Zm9v"           -> Some "foo"
    "Zm9vYg"         -> Some "foob"
    "Zm9vYmE"        -> Some "fooba"
    "Zm9vYmFy"       -> Some "foobar"
    "FPucA9l-"       -> Some "\020\251\156\003\217~"
    "FPucA9k"        -> Some "\020\251\156\003\217"
    "FPucAw"         -> Some "\020\251\156\003" |}]

(* Origin: not from an upstream suite; added for Dream. Both alphabet
   characters that differ from standard base64. *)
let%expect_test _ =
  encode "\xfb\xff";
  decode "-_8";
  [%expect {|
    "\251\255"               -> "-_8"
    "-_8"            -> Some "\251\255" |}]

