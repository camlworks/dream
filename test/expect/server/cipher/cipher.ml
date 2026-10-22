(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2021 Anton Bachin *)



let secret_1 =
  "abc"

let secret_2 =
  "def"

let nonce_1 =
  "abcdefghijkl"

let nonce_2 =
  "opqrstuvwxyz"

let encrypt secret nonce plaintext associated_data =
  Dream__cipher.Cipher.AEAD_AES_256_GCM.test_encrypt
    ~associated_data ~secret ~nonce plaintext
  |> Dream.to_base64url
  |> print_endline

let%expect_test _ =
  encrypt secret_1 nonce_1 "foo" "";
  encrypt secret_1 nonce_1 "fon" "";
  encrypt secret_1 nonce_2 "foo" "";
  encrypt secret_1 nonce_2 "fon" "";
  encrypt secret_2 nonce_1 "foo" "";
  encrypt secret_2 nonce_1 "fon" "";
  encrypt secret_2 nonce_2 "foo" "";
  encrypt secret_2 nonce_2 "fon" "";
  encrypt secret_1 nonce_1 "foo" "bar";
  encrypt secret_1 nonce_1 "fon" "bar";
  encrypt secret_1 nonce_2 "foo" "bar";
  encrypt secret_1 nonce_2 "fon" "bar";
  encrypt secret_2 nonce_1 "foo" "bar";
  encrypt secret_2 nonce_1 "fon" "bar";
  encrypt secret_2 nonce_2 "foo" "bar";
  encrypt secret_2 nonce_2 "fon" "bar";
  [%expect {|
    AGFiY2RlZmdoaWprbAzPcSEY4l7tSiDwIkk8ZfrFQQk
    AGFiY2RlZmdoaWprbAzPcCTJ-mJdrOKmcXtgqKJjGrI
    AG9wcXJzdHV2d3h5eqAJLHQ4dESlArPNBNiZza-USfI
    AG9wcXJzdHV2d3h5eqAJLXHpbHgV5HGbV-rFAPcyEkk
    AGFiY2RlZmdoaWprbNnUV1LsmdeLx8BgzZbQCzhRhQM
    AGFiY2RlZmdoaWprbNnUVrOLjFEg9zHbIfit_bhMglc
    AG9wcXJzdHV2d3h5etiGF4AINO312f7CMjZrdBQYJDA
    AG9wcXJzdHV2d3h5etiGFmFvIWte6Q953lgWgpQFI2Q
    AGFiY2RlZmdoaWprbAzPcRwPIoNND5fhGNGGqnkQ55k
    AGFiY2RlZmdoaWprbAzPcBneOr_96VW3S-PaZyG2vCI
    AG9wcXJzdHV2d3h5eqAJLEkvtJkFRwTcPkAjAixB72I
    AG9wcXJzdHV2d3h5eqAJLUz-rKW1ocaKbXJ_z3TntNk
    AGFiY2RlZmdoaWprbNnUV1K4sVao-kqinuCoViIVC-o
    AGFiY2RlZmdoaWprbNnUVrPfpNADyrsZco7VoKIIDL4
    AG9wcXJzdHV2d3h5etiGF4BcHGzW5HQAYUATKQ5cqtk
    AG9wcXJzdHV2d3h5etiGFmE7Cep91IW7jS5u345BrY0 |}]



let encrypt secret plaintext =
  Dream__cipher.Cipher.AEAD_AES_256_GCM.encrypt ~secret plaintext
  |> Dream.to_base64url

let%expect_test _ =
  Printf.printf "%B\n%!" (encrypt secret_1 "foo" = encrypt secret_1 "foo");
  [%expect {| false |}]



let decrypt secret associated_data ciphertext =
  let result =
    Dream__cipher.Cipher.AEAD_AES_256_GCM.decrypt
      ~associated_data ~secret ciphertext in
  match result with
  | None -> print_endline "None"
  | Some plaintext -> Printf.printf "%S\n" plaintext

let encrypt secret nonce plaintext associated_data =
  Dream__cipher.Cipher.AEAD_AES_256_GCM.test_encrypt
    ~associated_data ~secret ~nonce plaintext

let%expect_test _ =
  decrypt secret_1 "" (encrypt secret_1 nonce_1 "foo" "");
  decrypt secret_1 "" (encrypt secret_1 nonce_2 "foo" "");
  decrypt secret_1 "" (encrypt secret_2 nonce_1 "foo" "");
  decrypt secret_1 "" (encrypt secret_1 nonce_1 "bar" "");
  decrypt secret_2 "" (encrypt secret_1 nonce_1 "foo" "");
  decrypt secret_1 "bar" (encrypt secret_1 nonce_1 "foo" "bar");
  decrypt secret_1 "bar" (encrypt secret_1 nonce_1 "foo" "baz");
  decrypt secret_1 "" (encrypt secret_1 nonce_1 "foo" "bar");
  decrypt secret_1 "" "";
  decrypt secret_1 "" "ab";
  decrypt secret_1 "" "\x00abcdefghijklmnopqrstuvwxyz";
  decrypt secret_1 "" "\x01abcdefghijklmnopqrstuvwxyz";
  [%expect {|
    "foo"
    "foo"
    None
    "bar"
    None
    "foo"
    None
    None
    None
    None
    None
    None |}]



(* Decryption tries the main secret and then each of [~old_secrets] in turn (key
   rotation), and must carry [associated_data] through to every attempt.
   Regression test for https://github.com/camlworks/dream/issues/432: a payload
   encrypted with associated data under an old secret used to fail once a new
   main secret was tried first, because the recursive call dropped
   [associated_data] — so rotating the key broke every existing cookie, session,
   and CSRF token. *)

(* Run set_secret purely for its side effect of attaching the secrets to a fresh
   request. *)
let request_with_secrets ?old_secrets secret =
  let request = Dream.request "" in
  let _ : Dream.response Lwt.t =
    Dream.set_secret ?old_secrets secret
      (fun _ -> Lwt.return (Dream.response "")) request
  in
  request

let decrypt_result = function
  | None -> print_endline "None"
  | Some plaintext -> Printf.printf "%S\n" plaintext

let%expect_test _ =
  (* Encrypt with associated data under the pre-rotation secret. *)
  let ciphertext =
    Dream.encrypt ~associated_data:"bar" (request_with_secrets secret_2) "foo" in
  (* Post-rotation: new main secret, the old one kept for decryption. The main
     secret fails, so decryption must fall back to the old secret and still
     carry the associated data. *)
  let rotated = request_with_secrets ~old_secrets:[secret_2] secret_1 in
  decrypt_result (Dream.decrypt ~associated_data:"bar" rotated ciphertext);
  (* Control: rotation without associated data already worked. *)
  let plain =
    Dream.encrypt (request_with_secrets secret_2) "foo" in
  decrypt_result (Dream.decrypt rotated plain);
  (* Without the old secret, the ciphertext is correctly rejected. *)
  let no_rotation = request_with_secrets secret_1 in
  decrypt_result (Dream.decrypt ~associated_data:"bar" no_rotation ciphertext);
  [%expect {|
    "foo"
    "foo"
    None |}]
