(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2021 Anton Bachin *)



let () =
  ignore Initialize.require

(* Reads the whole body, so the size limit is actually enforced, and reports the
   number of bytes it received. *)
let echo_handler request =
  let%lwt body = Dream.body request in
  Dream.respond (string_of_int (String.length body))

(* Ignores the body entirely. *)
let ignore_handler _request =
  Dream.respond "ok"

let run ?(handler = echo_handler) ?headers ~limit body =
  let request = Dream.request ?headers body in
  let response = Dream.test (Dream.body_size_limit limit handler) request in
  let body = Lwt_main.run (Dream.body response) in
  Printf.printf "%i %s\n" (Dream.status_to_int (Dream.status response)) body

(* A body within the limit is read normally. *)
let%expect_test _ =
  run ~limit:10 "hello";
  [%expect {| 200 5 |}]

(* A body exactly at the limit is allowed. *)
let%expect_test _ =
  run ~limit:5 "hello";
  [%expect {| 200 5 |}]

(* A body past the limit is rejected with 413 as it is read, even without a
   Content-Length header. *)
let%expect_test _ =
  run ~limit:5 "hello!";
  [%expect {| 413 |}]

(* An advertised Content-Length past the limit is rejected immediately, without
   reading the body. *)
let%expect_test _ =
  run ~limit:5 ~headers:["Content-Length", "1000000"] "";
  [%expect {| 413 |}]

(* An advertised Content-Length within the limit does not trigger the fast-path
   rejection; the body is read normally. *)
let%expect_test _ =
  run ~limit:10 ~headers:["Content-Length", "5"] "hello";
  [%expect {| 200 5 |}]

(* A handler that never reads the body is not affected by an over-limit body
   that carries no Content-Length. *)
let%expect_test _ =
  run ~handler:ignore_handler ~limit:5 "hello, world!";
  [%expect {| 200 ok |}]

(* A negative limit is rejected when the middleware is constructed. *)
let%expect_test _ =
  (match
     Dream.test
       (Dream.body_size_limit (-1) echo_handler)
       (Dream.request "hello")
   with
   | _ -> print_endline "accepted"
   | exception Invalid_argument message -> print_endline message);
  [%expect {| Dream.body_size_limit: negative limit |}]
