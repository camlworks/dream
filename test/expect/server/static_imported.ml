(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2021 Anton Bachin *)



(* Static-file and conditional-request cases adapted from the test suites of
   other web frameworks. Expectations record Dream's current behavior;
   "Upstream:" comments note where the sources expect something different.
   Each test starts with an "Origin:" comment naming the upstream test and line
   it comes from, or saying that it was added for Dream.

   Sources (cases adapted, not code copied):

   - jshttp/fresh, test/fresh.js (MIT)
     https://github.com/jshttp/fresh/blob/ee7367318cf86a77e8259c63ee014ff0f8853437/test/fresh.js *)



module Message = Dream_pure.Message
module Stream = Dream_pure.Stream

let () =
  ignore Initialize.require

let status response =
  Dream.status_to_int (Dream.status response)



(* Conditional requests. The loader answers with fixed validators. *)

let last_modified = "Sat, 01 Jan 2000 00:00:00 GMT"

let validator_loader headers _local_root _path _request =
  Message.response
    ~headers:(("Content-Type", "text/plain")::headers)
    (Stream.string "body") Stream.null
  |> Lwt.return

let conditional ?(method_ = `GET) ?(etag = Some "\"foo\"")
    ?(last_modified = Some last_modified) headers =
  let validators =
    (match etag with None -> [] | Some e -> ["ETag", e]) @
    (match last_modified with None -> [] | Some l -> ["Last-Modified", l])
  in
  let app =
    Dream.router [
      Dream.any "/static/**"
        (Dream.static ~loader:(validator_loader validators) "www");
    ]
  in
  let response =
    Dream.test app (Dream.request ~method_ ~headers ~target:"/static/x" "") in
  let shown =
    headers
    |> List.map (fun (name, value) -> Printf.sprintf "%s: %S" name value)
    |> String.concat ", "
  in
  Printf.printf "%i  %s\n" (status response) shown

let lm0 = Some "Sat, 01 Jan 2000 00:00:00 GMT"

(* Origin: jshttp/fresh test/fresh.js, "when requested with If-None-Match"
   (L6-L93). The response's ETag is "foo" unless stated otherwise. *)
let%expect_test _ =
  conditional [];
  conditional ["If-None-Match", "\"foo\""];
  conditional ~etag:(Some "\"bar\"") ["If-None-Match", "\"foo\""];
  conditional ["If-None-Match", " \"bar\" , \"foo\""];
  conditional ["If-None-Match", "\"bar\",\t\"foo\""];
  conditional ~etag:None ~last_modified:None ["If-None-Match", "\"foo\""];
  conditional ~etag:(Some "W/\"foo\"") ["If-None-Match", "W/\"foo\""];
  conditional ~etag:(Some "\"foo\"") ["If-None-Match", "W/\"foo\""];
  conditional ["If-None-Match", "\"foo\""];
  conditional ~etag:(Some "W/\"foo\"") ["If-None-Match", "\"foo\""];
  conditional ["If-None-Match", "*"];
  conditional ["If-None-Match", "*, \"bar\""];
  [%expect {|
    200
    304  If-None-Match: "\"foo\""
    200  If-None-Match: "\"foo\""
    304  If-None-Match: " \"bar\" , \"foo\""
    304  If-None-Match: "\"bar\",\t\"foo\""
    200  If-None-Match: "\"foo\""
    304  If-None-Match: "W/\"foo\""
    304  If-None-Match: "W/\"foo\""
    304  If-None-Match: "\"foo\""
    304  If-None-Match: "\"foo\""
    304  If-None-Match: "*"
    200  If-None-Match: "*, \"bar\"" |}]
  (* Upstream (fresh): stale (200) without a precondition, on a mismatch, and
     without an ETag; "*" is ignored unless it is the only value, so
     "*, \"bar\"" is stale. Go, by contrast, matches "*" anywhere. No action:
     Dream agrees with fresh. The header is invalid, since RFC 9110 §13.1.2
     allows "*" only on its own, and the references disagree on it. *)

(* Origin: jshttp/fresh test/fresh.js, "when requested with Cache-Control:
   no-cache" (L172-L193). *)
let%expect_test _ =
  conditional ["Cache-Control", " no-cache"];
  conditional ["Cache-Control", " no-cache"; "If-None-Match", "\"foo\""];
  conditional ~etag:None ~last_modified:lm0
    ["Cache-Control", " no-cache";
     "If-Modified-Since", "Sat, 01 Jan 2000 01:00:00 GMT"];
  [%expect {|
    200  Cache-Control: " no-cache"
    304  Cache-Control: " no-cache", If-None-Match: "\"foo\""
    200  Cache-Control: " no-cache", If-Modified-Since: "Sat, 01 Jan 2000 01:00:00 GMT" |}]
  (* Upstream (fresh): all stale (200). Go, Starlette and actix ignore the
     directive. No action: Dream sides with the majority; no-cache in a
     request addresses caches (RFC 9111 §5.2.1.4), not the origin server. *)

(* Origin: not from an upstream suite; added for Dream. Range is not
   supported: the full representation is always sent (see Dream.static). *)
let%expect_test _ =
  conditional ["Range", "bytes=0-1"];
  conditional ["Range", "bytes=9-50"];
  conditional ["If-Range", "\"foo\""; "Range", "bytes=0-1"];
  [%expect {|
    200  Range: "bytes=0-1"
    200  Range: "bytes=9-50"
    200  If-Range: "\"foo\"", Range: "bytes=0-1" |}]
