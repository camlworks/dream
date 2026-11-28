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

(* Origin: jshttp/fresh test/fresh.js, "when requested with If-Modified-Since"
   (L96-L135), at
   https://github.com/jshttp/fresh/blob/ee7367318cf86a77e8259c63ee014ff0f8853437/test/fresh.js#L96-L135 *)
let%expect_test _ =
  conditional ~etag:None ~last_modified:lm1
    ["If-Modified-Since", "Sat, 01 Jan 2000 00:00:00 GMT"];
  conditional ~etag:None ~last_modified:lm0
    ["If-Modified-Since", "Sat, 01 Jan 2000 01:00:00 GMT"];
  conditional ~etag:None ~last_modified:None
    ["If-Modified-Since", "Sat, 01 Jan 2000 00:00:00 GMT"];
  conditional ~etag:None ~last_modified:lm0 ["If-Modified-Since", "foo"];
  conditional ~etag:None ~last_modified:(Some "foo")
    ["If-Modified-Since", "Sat, 01 Jan 2000 00:00:00 GMT"];
  [%expect {|
    200  If-Modified-Since: "Sat, 01 Jan 2000 00:00:00 GMT"
    200  If-Modified-Since: "Sat, 01 Jan 2000 01:00:00 GMT"
    200  If-Modified-Since: "Sat, 01 Jan 2000 00:00:00 GMT"
    200  If-Modified-Since: "foo"
    200  If-Modified-Since: "Sat, 01 Jan 2000 00:00:00 GMT" |}]
  (* Expected (fresh): only the second, a date later than Last-Modified, is
     fresh (304). If-Modified-Since is compared to Last-Modified as a
     string. *)

(* Origin: not from an upstream suite; added for Dream. An exact match, two
   identical strings that are not dates, and the same date in the RFC 850 and
   asctime formats and in lower case. Go's ParseTime (in its code, not its
   tests) accepts all three formats. *)
let%expect_test _ =
  conditional ~etag:None ~last_modified:lm0
    ["If-Modified-Since", "Sat, 01 Jan 2000 00:00:00 GMT"];
  conditional ~etag:None ~last_modified:(Some "foo")
    ["If-Modified-Since", "foo"];
  conditional ~etag:None ~last_modified:lm0
    ["If-Modified-Since", "Saturday, 01-Jan-00 00:00:00 GMT"];
  conditional ~etag:None ~last_modified:lm0
    ["If-Modified-Since", "Sat Jan  1 00:00:00 2000"];
  conditional ~etag:None ~last_modified:lm0
    ["If-Modified-Since", "sat, 01 jan 2000 00:00:00 GMT"];
  [%expect {|
    304  If-Modified-Since: "Sat, 01 Jan 2000 00:00:00 GMT"
    304  If-Modified-Since: "foo"
    200  If-Modified-Since: "Saturday, 01-Jan-00 00:00:00 GMT"
    200  If-Modified-Since: "Sat Jan  1 00:00:00 2000"
    200  If-Modified-Since: "sat, 01 jan 2000 00:00:00 GMT" |}]
  (* Expected: 304, 200, 304, 304, 200. Two equal strings that are not dates
     give 304, and the other two date formats are ignored. *)

(* Origin: not from an upstream suite; added for Dream. Dates that do not
   parse, so that If-Modified-Since is ignored: an impossible day, trailing
   characters, and a missing "GMT". Then the RFC 850 century rule: "99" is
   1999, earlier than Last-Modified, so the resource was modified, and "00" is
   2000. *)
let%expect_test _ =
  conditional ~etag:None ~last_modified:lm0
    ["If-Modified-Since", "Wed, 30 Feb 2000 00:00:00 GMT"];
  conditional ~etag:None ~last_modified:lm0
    ["If-Modified-Since", "Sat, 01 Jan 2000 00:00:00 GMT x"];
  conditional ~etag:None ~last_modified:lm0
    ["If-Modified-Since", "Sat, 01 Jan 2000 00:00:00"];
  conditional ~etag:None ~last_modified:lm0
    ["If-Modified-Since", "Friday, 31-Dec-99 23:59:59 GMT"];
  conditional ~etag:None ~last_modified:lm0
    ["If-Modified-Since", "Saturday, 01-Jan-00 00:00:01 GMT"];
  [%expect {|
    200  If-Modified-Since: "Wed, 30 Feb 2000 00:00:00 GMT"
    200  If-Modified-Since: "Sat, 01 Jan 2000 00:00:00 GMT x"
    200  If-Modified-Since: "Sat, 01 Jan 2000 00:00:00"
    200  If-Modified-Since: "Friday, 31-Dec-99 23:59:59 GMT"
    200  If-Modified-Since: "Saturday, 01-Jan-00 00:00:01 GMT" |}]
  (* Expected: 304 for the last, a date later than Last-Modified. *)
