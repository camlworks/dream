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



(* Dream.from_filesystem, in a temporary directory. *)

let with_temp_root f =
  let root =
    Filename.concat (Filename.get_temp_dir_name ())
      (Printf.sprintf "dream-static-%i-%i"
        (Unix.getpid ()) (Random.State.bits (Random.State.make_self_init ())))
  in
  Unix.mkdir root 0o700;
  let rec remove path =
    match (Unix.lstat path).st_kind with
    | Unix.S_DIR ->
      Array.iter (fun entry -> remove (Filename.concat path entry))
        (Sys.readdir path);
      Unix.rmdir path
    | _ -> Unix.unlink path
  in
  Fun.protect ~finally:(fun () -> remove root) (fun () -> f root)

let serve root target =
  let app = Dream.router [Dream.get "/static/**" (Dream.static root)] in
  let response = Dream.test app (Dream.request ~target "") in
  match Dream.status_to_int (Dream.status response) with
  | 200 ->
    let body = Lwt_main.run (Dream.body response) in
    Printf.printf "%-18S 200 %S\n" target body
  | n -> Printf.printf "%-18S %i\n" target n

(* Origin: not from an upstream suite; added for Dream. A FIFO, next to a
   regular file and a directory. *)
let%expect_test _ =
  with_temp_root (fun root ->
    let channel = open_out_bin (Filename.concat root "name.txt") in
    output_string channel "name";
    close_out channel;
    Unix.mkdir (Filename.concat root "dir") 0o700;
    Unix.mkfifo (Filename.concat root "fifo") 0o600;
    serve root "/static/name.txt";
    serve root "/static/dir";
    serve root "/static/fifo");
  [%expect {|
    "/static/name.txt" 200 "name"
    "/static/dir"      404
    "/static/fifo"     404 |}]
