(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2021 Anton Bachin *)

module Message = Dream_pure.Message
module Stream = Dream_pure.Stream

let () = ignore Initialize.require

let etag = "\"abc\""

(* A body stream that records whether it has been closed. Its reading function
   never completes: nothing in these tests reads it. *)
let tracked_body () =
  let closed = ref false in
  let reader =
    Stream.reader
      ~read:(fun ~data:_ ~flush:_ ~ping:_ ~pong:_ ~close:_ ~exn:_ -> ())
      ~close:(fun _code -> closed := true)
      ~abort:(fun _exn -> ())
  in
  (Stream.stream reader Stream.no_writer, closed)

(* A custom loader whose response carries validators, a Content-Location, and
   headers a 304 must not keep. *)
let loader body _local_root _path _request =
  Message.response
    ~headers:
      [
        ("Content-Type", "text/plain");
        ("Content-Location", "/static/hello.en");
        ("ETag", etag);
        ("X-Custom", "dropped on 304");
      ]
    body Stream.null
  |> Lwt.return

let run ?(headers = []) () =
  let body, closed = tracked_body () in
  let app =
    Dream.router
      [Dream.get "/static/**" (Dream.static ~loader:(loader body) "www")]
  in
  let response =
    Dream.test app (Dream.request ~headers ~target:"/static/hello" "")
  in
  Printf.printf "%i\n" (Dream.status_to_int (Dream.status response));
  Dream.all_headers response
  |> List.sort compare
  |> List.iter (fun (name, value) -> Printf.printf "%s: %s\n" name value);
  Printf.printf "body closed: %b\n" !closed

(* A matching If-None-Match yields a 304 that keeps Content-Location alongside
   the validators (RFC 9110 §15.4.5), and closes the loader's body. *)
let%expect_test _ =
  run ~headers:[("If-None-Match", etag)] ();
  [%expect
    {|
    304
    Content-Location: /static/hello.en
    ETag: "abc"
    body closed: true |}]

(* Without a matching precondition, the loader's response passes through
   untouched and its body is left open for the server to send. *)
let%expect_test _ =
  run ~headers:[("If-None-Match", "\"stale\"")] ();
  [%expect
    {|
    200
    Content-Location: /static/hello.en
    Content-Type: text/plain
    ETag: "abc"
    X-Custom: dropped on 304
    body closed: false |}]
