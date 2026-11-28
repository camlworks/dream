(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2021 Anton Bachin *)



module Message = Dream_pure.Message
module Stream = Dream_pure.Stream

let () =
  ignore Initialize.require

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
  Stream.stream reader Stream.no_writer, closed

(* A custom loader whose response carries validators, a Content-Location, and
   headers a 304 must not keep. *)
let loader body _local_root _path _request =
  Message.response
    ~headers:[
      "Content-Type", "text/plain";
      "Content-Location", "/static/hello.en";
      "ETag", etag;
      "X-Custom", "dropped on 304";
    ]
    body Stream.null
  |> Lwt.return

let run ?(headers = []) () =
  let body, closed = tracked_body () in
  let app =
    Dream.router [
      Dream.get "/static/**" (Dream.static ~loader:(loader body) "www");
    ]
  in
  let response = Dream.test app (Dream.request ~headers ~target:"/static/hello" "") in
  Printf.printf "%i\n" (Dream.status_to_int (Dream.status response));
  Dream.all_headers response
  |> List.sort compare
  |> List.iter (fun (name, value) -> Printf.printf "%s: %s\n" name value);
  Printf.printf "body closed: %b\n" !closed

(* A matching If-None-Match yields a 304 that keeps Content-Location alongside
   the validators (RFC 9110 §15.4.5), and closes the loader's body. *)
let%expect_test _ =
  run ~headers:["If-None-Match", etag] ();
  [%expect {|
    304
    Content-Location: /static/hello.en
    ETag: "abc"
    body closed: true |}]

(* Without a matching precondition, the loader's response passes through
   untouched and its body is left open for the server to send. *)
let%expect_test _ =
  run ~headers:["If-None-Match", "\"stale\""] ();
  [%expect {|
    200
    Content-Location: /static/hello.en
    Content-Type: text/plain
    ETag: "abc"
    X-Custom: dropped on 304
    body closed: false |}]



(* Conditional requests against a loader that answers with fixed validators. *)

let validator_loader headers _local_root _path _request =
  Message.response
    ~headers:(("Content-Type", "text/plain")::headers)
    (Stream.string "body") Stream.null
  |> Lwt.return

let conditional ?(etag = Some "\"foo\"")
    ?(last_modified = Some "Sat, 01 Jan 2000 00:00:00 GMT") headers =
  let validators =
    (match etag with None -> [] | Some e -> ["ETag", e]) @
    (match last_modified with None -> [] | Some l -> ["Last-Modified", l])
  in
  let app =
    Dream.router [
      Dream.get "/static/**"
        (Dream.static ~loader:(validator_loader validators) "www");
    ]
  in
  let response =
    Dream.test app (Dream.request ~headers ~target:"/static/x" "") in
  let shown =
    headers
    |> List.map (fun (name, value) -> Printf.sprintf "%s: %S" name value)
    |> String.concat ", "
  in
  Printf.printf "%i  %s\n" (Dream.status_to_int (Dream.status response)) shown

let lm0 = Some "Sat, 01 Jan 2000 00:00:00 GMT"
let lm1 = Some "Sat, 01 Jan 2000 01:00:00 GMT"

(* Origin: not from an upstream suite; added for Dream. An If-None-Match with
   no entity-tags (empty, blank, or only a comma), and an If-None-Match with no
   ETag in the response, each with a matching If-Modified-Since. Go's
   checkIfNoneMatch and Starlette's is_not_modified (in their code, not their
   tests) treat a header with no entity-tags as absent. *)
let%expect_test _ =
  conditional ~last_modified:lm0
    ["If-None-Match", ""; "If-Modified-Since", "Sat, 01 Jan 2000 00:00:00 GMT"];
  conditional ~last_modified:lm0
    ["If-None-Match", " "; "If-Modified-Since", "Sat, 01 Jan 2000 00:00:00 GMT"];
  conditional ~last_modified:lm0
    ["If-None-Match", ","; "If-Modified-Since", "Sat, 01 Jan 2000 00:00:00 GMT"];
  conditional ~etag:None ~last_modified:lm0
    ["If-None-Match", "\"foo\"";
     "If-Modified-Since", "Sat, 01 Jan 2000 00:00:00 GMT"];
  [%expect {|
    200  If-None-Match: "", If-Modified-Since: "Sat, 01 Jan 2000 00:00:00 GMT"
    200  If-None-Match: " ", If-Modified-Since: "Sat, 01 Jan 2000 00:00:00 GMT"
    200  If-None-Match: ",", If-Modified-Since: "Sat, 01 Jan 2000 00:00:00 GMT"
    200  If-None-Match: "\"foo\"", If-Modified-Since: "Sat, 01 Jan 2000 00:00:00 GMT" |}]
  (* Expected: 304 for the first three, where If-Modified-Since should apply.
     An If-None-Match with no entity-tags counts as present today, so it
     disables If-Modified-Since. *)
