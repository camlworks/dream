(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2021 Anton Bachin *)



(* Static-file and conditional-request cases adapted from the test suites of
   other web frameworks. Expectations record Dream's current behavior;
   "Upstream:" comments note where the sources expect something different.
   Each test starts with an "Origin:" comment naming the upstream test and line
   it comes from, or saying that it was added for Dream.

   Sources (cases adapted, not code copied):

   - Go net/http, src/net/http/fs_test.go (BSD-3-Clause)
     https://github.com/golang/go/blob/5e9534e62225b2f58f3b4b3d410e63f29f6566f5/src/net/http/fs_test.go
   - jshttp/fresh, test/fresh.js (MIT)
     https://github.com/jshttp/fresh/blob/ee7367318cf86a77e8259c63ee014ff0f8853437/test/fresh.js
   - pillarjs/send, test/send.js (MIT)
     https://github.com/pillarjs/send/blob/4d246b3429f3ea44bb3a3193ef30d4497400f8ef/test/send.js
   - expressjs/serve-static, test/test.js (MIT)
     https://github.com/expressjs/serve-static/blob/6e3606f2892df213e8fa738b51a36ba711e86ce8/test/test.js
   - Elixir Plug, test/plug/static_test.exs (Apache-2.0)
     https://github.com/elixir-plug/plug/blob/f6cb9a9d8d001ed3a5e011312e7bd4726d7f124e/test/plug/static_test.exs
   - Starlette, tests/test_staticfiles.py (BSD-3-Clause)
     https://github.com/Kludex/starlette/blob/63d868e1b89063fa1059dafe239e41f924c33805/tests/test_staticfiles.py
   - actix-files, src/lib.rs and src/path_buf.rs (MIT OR Apache-2.0)
     https://github.com/actix/actix-web/tree/98f5b221eafd2095b6d3f3c45bab7d962f00838f/actix-files/src *)



module Message = Dream_pure.Message
module Stream = Dream_pure.Stream

let () =
  ignore Initialize.require

let status response =
  Dream.status_to_int (Dream.status response)



(* Path validation. The loader echoes the path it receives, so these tests show
   exactly which request paths reach a loader. *)

let echo_loader _local_root path _request =
  Message.response (Stream.string path) Stream.null
  |> Lwt.return

let path_app =
  Dream.router [
    Dream.any "/static/**" (Dream.static ~loader:echo_loader "www");
  ]

let get ?(method_ = `GET) target =
  let response = Dream.test path_app (Dream.request ~method_ ~target "") in
  let label =
    match method_ with
    | `GET -> target
    | _ -> Dream.method_to_string method_ ^ " " ^ target
  in
  match status response with
  | 200 ->
    let body = Lwt_main.run (Dream.body response) in
    Printf.printf "%-44S 200 loader got %S\n" label body
  | n -> Printf.printf "%-44S %i\n" label n

(* Origin: Go fs_test.go, TestServeFile_DotDot (L211-L225). *)
let%expect_test _ =
  get "/static/../file";
  get "/static/..";
  get "/static/../";
  get "/static/../foo";
  get "/static/..\\foo";
  get "/static/file/a..";
  get "/static/file/a/..";
  get "/static/file/a\\..";
  [%expect {|
    "/static/../file"                            404
    "/static/.."                                 404
    "/static/../"                                404
    "/static/../foo"                             404
    "/static/..\\foo"                            404
    "/static/file/a.."                           200 loader got "file/a.."
    "/static/file/a/.."                          404
    "/static/file/a\\.."                         404 |}]
  (* Upstream (Go): 400, except "/file/a.." (200). *)

(* Origin: Go fs_test.go, TestFileServerCleans (L318-L329). *)
let%expect_test _ =
  get "/static//foo.txt";
  get "/static/../foo.txt";
  [%expect {|
    "/static//foo.txt"                           200 loader got "foo.txt"
    "/static/../foo.txt"                         404 |}]
  (* Upstream (Go): both are served as "/foo.txt". *)

(* Origin: pillarjs/send test/send.js, L44, L50, L56, L1207, L1216, L1261 and
   L1278. *)
let%expect_test _ =
  get "/static/some%20thing.txt";
  get "/static/do..ts.txt";
  get "/static/some%99thing.txt";
  get "/static/tobi.html/";
  get "/static/pets/../name.txt";
  get "/static/pets/../../send.js";
  get "/static/../name.dir/name.txt";
  [%expect {|
    "/static/some%20thing.txt"                   200 loader got "some thing.txt"
    "/static/do..ts.txt"                         200 loader got "do..ts.txt"
    "/static/some%99thing.txt"                   200 loader got "some\153thing.txt"
    "/static/tobi.html/"                         404
    "/static/pets/../name.txt"                   404
    "/static/pets/../../send.js"                 404
    "/static/../name.dir/name.txt"               404 |}]
  (* Upstream (send): "/some%99thing.txt" is 400 (malformed URI);
     "/pets/../name.txt" is resolved and served (200); the two paths that leave
     the root are 403. *)

(* Origin: expressjs/serve-static test/test.js, L71, L276 and L608. *)
let%expect_test _ =
  get "/static//todo@txt";
  get "/static/%";
  get "/static/users/%2e%2e/%2e%2e/todo.txt";
  [%expect {|
    "/static//todo@txt"                          200 loader got "todo@txt"
    "/static/%"                                  200 loader got "%"
    "/static/users/%2e%2e/%2e%2e/todo.txt"       404 |}]
  (* Upstream (serve-static): "/%" is 400 without fallthrough, and the
     traversal is 403 without fallthrough. *)

(* Origin: Elixir Plug test/plug/static_test.exs, L251, L258, L269 and L278. *)
let%expect_test _ =
  get "/static/another/fallback%2Ftxt";
  get "/static/public/fixtures/../fixtures/static/file.txt";
  get "/static/public/fixtures/%2E%2E/fixtures/static/file.txt";
  get "/static/public/c:\\foo.txt";
  [%expect {|
    "/static/another/fallback%2Ftxt"             404
    "/static/public/fixtures/../fixtures/static/file.txt" 404
    "/static/public/fixtures/%2E%2E/fixtures/static/file.txt" 404
    "/static/public/c:\\foo.txt"                 404 |}]
  (* Upstream (Plug): the last three raise InvalidPathError (400). *)

(* Origin: Starlette tests/test_staticfiles.py, lookup_path tests (L645 and
   L655). Upstream calls lookup_path directly; here the paths go through a
   request. *)
let%expect_test _ =
  get "/static//etc/passwd";
  get "/static/\\\\server\\share";
  [%expect {|
    "/static//etc/passwd"                        200 loader got "etc/passwd"
    "/static/\\\\server\\share"                  404 |}]
  (* Upstream (Starlette): both are refused. *)

(* Origin: actix-files src/path_buf.rs tests (L151-L240) and src/lib.rs, L578,
   L995 and test_hidden_files_reject_cur_dir_segment (L1458). *)
let%expect_test _ =
  get "/static/test/*tt";
  get "/static/test/tt:";
  get "/static/test/tt<";
  get "/static/test/./file.txt";
  get "/static/test%2Ffile.txt";
  get "/static/C:test.txt";
  get "/static/C:../whatever";
  get "/static/:test.txt";
  get "/static/t%65st/Cargo.toml";
  get "/static/test%0A%0B%0C%0Dnewline.text";
  get "/static/./Cargo.toml";
  [%expect {|
    "/static/test/*tt"                           200 loader got "test/*tt"
    "/static/test/tt:"                           200 loader got "test/tt:"
    "/static/test/tt<"                           200 loader got "test/tt<"
    "/static/test/./file.txt"                    404
    "/static/test%2Ffile.txt"                    404
    "/static/C:test.txt"                         200 loader got "C:test.txt"
    "/static/C:../whatever"                      200 loader got "C:../whatever"
    "/static/:test.txt"                          200 loader got ":test.txt"
    "/static/t%65st/Cargo.toml"                  200 loader got "test/Cargo.toml"
    "/static/test%0A%0B%0C%0Dnewline.text"       200 loader got "test\n\011\012\rnewline.text"
    "/static/./Cargo.toml"                       404 |}]
  (* Upstream (actix): "*tt", "tt:" and "tt<" are rejected (bad start or end
     character); "/./Cargo.toml" is 400. The drive-letter paths are accepted
     on Unix. *)

(* Origin: not from an upstream suite; added for Dream. More encodings of
   traversal: encoded and double-encoded dots, encoded backslashes, overlong
   UTF-8 dots and slashes, and fullwidth dots. *)
let%expect_test _ =
  get "/static/%2e%2e/x";
  get "/static/.%2e/x";
  get "/static/%2e./x";
  get "/static/%252e%252e/x";
  get "/static/..%5c..%5cetc%5cpasswd";
  get "/static/a%5cb";
  get "/static/%c0%ae%c0%ae/%c0%afetc%c0%afpasswd";
  get "/static/%ef%bc%8e%ef%bc%8e/x";
  get "/static/%zz";
  get "/static/%4";
  [%expect {|
    "/static/%2e%2e/x"                           404
    "/static/.%2e/x"                             404
    "/static/%2e./x"                             404
    "/static/%252e%252e/x"                       200 loader got "%2e%2e/x"
    "/static/..%5c..%5cetc%5cpasswd"             404
    "/static/a%5cb"                              404
    "/static/%c0%ae%c0%ae/%c0%afetc%c0%afpasswd" 200 loader got "\192\174\192\174/\192\175etc\192\175passwd"
    "/static/%ef%bc%8e%ef%bc%8e/x"               200 loader got "\239\188\142\239\188\142/x"
    "/static/%zz"                                200 loader got "%zz"
    "/static/%4"                                 200 loader got "%4" |}]

(* Origin: pillarjs/send test/send.js, L62. *)
let%expect_test _ =
  get "/static/some%00thing.txt";
  [%expect {| "/static/some%00thing.txt"                   200 loader got "some\000thing.txt" |}]
  (* Upstream (send): 400. *)

(* Origin: Go fs_test.go, testFileServerNullByte (L751-L757). *)
let%expect_test _ =
  get "/static/file%00";
  get "/static/%00";
  get "/static/file/qwe/%00";
  [%expect {|
    "/static/file%00"                            200 loader got "file\000"
    "/static/%00"                                200 loader got "\000"
    "/static/file/qwe/%00"                       200 loader got "file/qwe/\000" |}]
  (* Upstream (Go): 404. *)

(* Origin: Elixir Plug test/plug/static_test.exs, L287. *)
let%expect_test _ =
  get "/static/sample.txt%00.html";
  [%expect {| "/static/sample.txt%00.html"                 200 loader got "sample.txt\000.html" |}]
  (* Upstream (Plug): InvalidPathError (400). *)

(* Origin: not from an upstream suite; added for Dream. *)
let%expect_test _ =
  get "/static";
  get "/static/";
  get "/static/dir/";
  [%expect {|
    "/static"                                    404
    "/static/"                                   404
    "/static/dir/"                               404 |}]

(* Origin: expressjs/serve-static test/test.js, L91 (HEAD), L99 (POST) and
   L338 (OPTIONS); actix-files src/lib.rs, L1011 (POST) and L1019 (PUT); Plug
   test/plug/static_test.exs, L244 (POST). *)
let%expect_test _ =
  get ~method_:`HEAD "/static/file";
  get ~method_:`POST "/static/file";
  get ~method_:`OPTIONS "/static/file";
  get ~method_:`PUT "/static/file";
  [%expect {|
    "HEAD /static/file"                          200 loader got ""
    "POST /static/file"                          404
    "OPTIONS /static/file"                       404
    "PUT /static/file"                           404 |}]
  (* Upstream: actix answers 405; serve-static, without fallthrough, answers
     405 with "Allow: GET, HEAD"; Plug passes the request on (404 here). *)

(* Origin: not from an upstream suite; added for Dream. *)
let%expect_test _ =
  get ~method_:`DELETE "/static/file";
  [%expect {| "DELETE /static/file"                        404 |}]



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
let lm1 = Some "Sat, 01 Jan 2000 01:00:00 GMT"

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

(* Origin: Go fs_test.go, testServeContent (L943): not_modified_etag,
   not_modified_etag_no_seek, if_none_match_mismatch and
   if_none_match_malformed (L1010-L1041). *)
let%expect_test _ =
  conditional ["If-None-Match", "\"foo\""];
  conditional ~etag:(Some "W/\"foo\"") ["If-None-Match", "\"baz\", W/\"foo\""];
  conditional ["If-None-Match", "\"Foo\""];
  conditional ["If-None-Match", ","];
  [%expect {|
    304  If-None-Match: "\"foo\""
    304  If-None-Match: "\"baz\", W/\"foo\""
    200  If-None-Match: "\"Foo\""
    200  If-None-Match: "," |}]

(* Origin: Starlette tests/test_staticfiles.py, L224-L230, the wildcard test
   (L236) and the non-matching test (L252). *)
let%expect_test _ =
  conditional ["If-None-Match", "W/\"foo\", \"123\""];
  conditional ["If-None-Match", "\"123\",\tW/\"foo\""];
  conditional ["If-None-Match", "*"];
  conditional ["If-None-Match", " \t* \t"];
  conditional ["If-None-Match", "\"123\""];
  conditional ["If-None-Match", "\"*\""];
  conditional ["If-None-Match", "\"foo,*,bar\""];
  [%expect {|
    304  If-None-Match: "W/\"foo\", \"123\""
    304  If-None-Match: "\"123\",\tW/\"foo\""
    304  If-None-Match: "*"
    304  If-None-Match: " \t* \t"
    200  If-None-Match: "\"123\""
    200  If-None-Match: "\"*\""
    200  If-None-Match: "\"foo,*,bar\"" |}]

(* Origin: Elixir Plug test/plug/static_test.exs, L134 (304 expected) and L145
   (200 expected). *)
let%expect_test _ =
  conditional ["If-None-Match", "W/\"foo\""];
  conditional ["If-None-Match", "\"other\", \"foo\""];
  conditional ["If-None-Match", "\"other\",W/\"foo\""];
  conditional ["If-None-Match", "*"];
  conditional ["If-None-Match", "\"other\""];
  conditional ["If-None-Match", "\"other\", W/\"another\""];
  [%expect {|
    304  If-None-Match: "W/\"foo\""
    304  If-None-Match: "\"other\", \"foo\""
    304  If-None-Match: "\"other\",W/\"foo\""
    304  If-None-Match: "*"
    200  If-None-Match: "\"other\""
    200  If-None-Match: "\"other\", W/\"another\"" |}]

(* Origin: not from an upstream suite; added for Dream. Entity-tags that Go's
   scanETag (in fs.go, not in its tests) does not parse, and a quoted ETag
   containing a comma, which only a custom loader can produce. *)
let%expect_test _ =
  conditional ["If-None-Match", "w/\"foo\""];
  conditional ["If-None-Match", "foo"];
  conditional ~etag:(Some "foo") ["If-None-Match", "foo"];
  conditional ["If-None-Match", "W/"];
  conditional ["If-None-Match", "W/\"truc"];
  conditional ~etag:(Some "\"a,b\"") ["If-None-Match", "\"a,b\""];
  [%expect {|
    200  If-None-Match: "w/\"foo\""
    200  If-None-Match: "foo"
    200  If-None-Match: "foo"
    200  If-None-Match: "W/"
    200  If-None-Match: "W/\"truc"
    304  If-None-Match: "\"a,b\"" |}]
  (* Go gives the same results. *)

(* Origin: jshttp/fresh test/fresh.js, "when requested with If-Modified-Since"
   (L96-L135). *)
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
    304  If-Modified-Since: "Sat, 01 Jan 2000 01:00:00 GMT"
    200  If-Modified-Since: "Sat, 01 Jan 2000 00:00:00 GMT"
    200  If-Modified-Since: "foo"
    200  If-Modified-Since: "Sat, 01 Jan 2000 00:00:00 GMT" |}]

(* Origin: not from an upstream suite; added for Dream. An exact match, two
   identical strings that are not dates, and the same date in the RFC 850 and
   asctime formats and in lower case. Go's ParseTime (not its tests) accepts
   all three formats. *)
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
    200  If-Modified-Since: "foo"
    304  If-Modified-Since: "Saturday, 01-Jan-00 00:00:00 GMT"
    304  If-Modified-Since: "Sat Jan  1 00:00:00 2000"
    200  If-Modified-Since: "sat, 01 jan 2000 00:00:00 GMT" |}]

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
    304  If-Modified-Since: "Saturday, 01-Jan-00 00:00:01 GMT" |}]

(* Origin: jshttp/fresh test/fresh.js, "when requested with If-Modified-Since
   and If-None-Match" (L138-L169). *)
let%expect_test _ =
  conditional ~last_modified:lm0
    ["If-None-Match", "\"foo\"";
     "If-Modified-Since", "Sat, 01 Jan 2000 01:00:00 GMT"];
  conditional ~last_modified:lm1
    ["If-None-Match", "\"foo\"";
     "If-Modified-Since", "Sat, 01 Jan 2000 00:00:00 GMT"];
  conditional ~etag:(Some "\"bar\"") ~last_modified:lm0
    ["If-None-Match", "\"foo\"";
     "If-Modified-Since", "Sat, 01 Jan 2000 01:00:00 GMT"];
  conditional ~etag:(Some "\"bar\"") ~last_modified:lm1
    ["If-None-Match", "\"foo\"";
     "If-Modified-Since", "Sat, 01 Jan 2000 00:00:00 GMT"];
  [%expect {|
    304  If-None-Match: "\"foo\"", If-Modified-Since: "Sat, 01 Jan 2000 01:00:00 GMT"
    304  If-None-Match: "\"foo\"", If-Modified-Since: "Sat, 01 Jan 2000 00:00:00 GMT"
    200  If-None-Match: "\"foo\"", If-Modified-Since: "Sat, 01 Jan 2000 01:00:00 GMT"
    200  If-None-Match: "\"foo\"", If-Modified-Since: "Sat, 01 Jan 2000 00:00:00 GMT" |}]

(* Origin: Starlette tests/test_staticfiles.py, L279-L281: when
   If-None-Match is present, If-Modified-Since is ignored. *)
let%expect_test _ =
  conditional ~last_modified:lm0
    ["If-None-Match", "\"123\"";
     "If-Modified-Since", "Sat, 01 Jan 2000 00:00:00 GMT"];
  [%expect {| 200  If-None-Match: "\"123\"", If-Modified-Since: "Sat, 01 Jan 2000 00:00:00 GMT" |}]

(* Origin: not from an upstream suite; added for Dream. An empty
   If-None-Match, and an If-None-Match with no ETag in the response, each
   with a matching If-Modified-Since. *)
let%expect_test _ =
  conditional ~last_modified:lm0
    ["If-None-Match", ""; "If-Modified-Since", "Sat, 01 Jan 2000 00:00:00 GMT"];
  conditional ~etag:None ~last_modified:lm0
    ["If-None-Match", "\"foo\"";
     "If-Modified-Since", "Sat, 01 Jan 2000 00:00:00 GMT"];
  [%expect {|
    304  If-None-Match: "", If-Modified-Since: "Sat, 01 Jan 2000 00:00:00 GMT"
    200  If-None-Match: "\"foo\"", If-Modified-Since: "Sat, 01 Jan 2000 00:00:00 GMT" |}]
  (* As in Go and Starlette (in their code, not their tests), an empty
     If-None-Match counts as absent. *)

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
    304  Cache-Control: " no-cache", If-Modified-Since: "Sat, 01 Jan 2000 01:00:00 GMT" |}]
  (* Upstream (fresh): all stale (200). Go, Starlette and actix ignore the
     directive. No action: Dream sides with the majority; no-cache in a
     request addresses caches (RFC 9111 §5.2.1.4), not the origin server. *)

(* Origin: Go fs_test.go, testServeContent (L943): ifmatch_matches,
   ifmatch_star, ifmatch_failed, ifmatch_fails_on_weak_etag,
   if_unmodified_since_true and if_unmodified_since_false (L1138-L1190). RFC
   9110 sections 13.1.1 and 13.1.4 require an origin server to evaluate these
   for GET. *)
let%expect_test _ =
  conditional ~etag:(Some "\"A\"") ["If-Match", "\"Z\", \"A\""];
  conditional ~etag:(Some "\"A\"") ["If-Match", "*"];
  conditional ~etag:(Some "\"A\"") ["If-Match", "\"B\""];
  conditional ~etag:(Some "W/\"A\"") ["If-Match", "W/\"A\""];
  conditional ~last_modified:lm0
    ["If-Unmodified-Since", "Sat, 01 Jan 2000 00:00:00 GMT"];
  conditional ~last_modified:lm0
    ["If-Unmodified-Since", "Fri, 31 Dec 1999 23:59:58 GMT"];
  [%expect {|
    200  If-Match: "\"Z\", \"A\""
    200  If-Match: "*"
    412  If-Match: "\"B\""
    412  If-Match: "W/\"A\""
    200  If-Unmodified-Since: "Sat, 01 Jan 2000 00:00:00 GMT"
    412  If-Unmodified-Since: "Fri, 31 Dec 1999 23:59:58 GMT" |}]

(* Origin: pillarjs/send test/send.js, "where If-Match is set" (L471-L503) and
   "where If-Unmodified-Since is set" (L560-L592). In the second case, the
   file's ETag is not in the list. *)
let%expect_test _ =
  conditional ["If-Match", "*"];
  conditional ~etag:(Some "\"baz\"") ["If-Match", " \"foo\",, \"bar\" ,"];
  conditional ["If-Match", "\"foo\", \"bar\", \"foo\""];
  conditional ~last_modified:lm0
    ["If-Unmodified-Since", "Sat, 01 Jan 2000 00:00:00 GMT"];
  conditional ~last_modified:lm0
    ["If-Unmodified-Since", "Fri, 31 Dec 1999 23:59:00 GMT"];
  conditional ["If-Unmodified-Since", "foo"];
  [%expect {|
    200  If-Match: "*"
    412  If-Match: " \"foo\",, \"bar\" ,"
    200  If-Match: "\"foo\", \"bar\", \"foo\""
    200  If-Unmodified-Since: "Sat, 01 Jan 2000 00:00:00 GMT"
    412  If-Unmodified-Since: "Fri, 31 Dec 1999 23:59:00 GMT"
    200  If-Unmodified-Since: "foo" |}]

(* Origin: actix-files src/lib.rs, test_if_match_overrides_if_unmodified_since
   (L250) and test_if_match_failure_with_if_unmodified_since (L264). *)
let%expect_test _ =
  conditional ~last_modified:lm0
    ["If-Match", "\"foo\"";
     "If-Unmodified-Since", "Thu, 01 Jan 1970 00:00:00 GMT"];
  conditional ~last_modified:lm0
    ["If-Match", "\"nonmatching-etag\"";
     "If-Unmodified-Since", "Sat, 01 Jan 2000 00:00:00 GMT"];
  [%expect {|
    200  If-Match: "\"foo\"", If-Unmodified-Since: "Thu, 01 Jan 1970 00:00:00 GMT"
    412  If-Match: "\"nonmatching-etag\"", If-Unmodified-Since: "Sat, 01 Jan 2000 00:00:00 GMT" |}]

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

(* Origin: actix-files src/lib.rs, test_if_none_match_get_and_head (L115),
   test_if_none_match_post (L141) and test_if_modified_since_post (L188). *)
let%expect_test _ =
  conditional ~method_:`HEAD ["If-None-Match", "\"foo\""];
  conditional ~method_:`POST ["If-None-Match", "\"foo\""];
  conditional ~method_:`POST ["If-None-Match", "*"];
  conditional ~method_:`POST ~last_modified:lm0
    ["If-Modified-Since", "Sat, 01 Jan 2000 00:00:00 GMT"];
  [%expect {|
    304  If-None-Match: "\"foo\""
    404  If-None-Match: "\"foo\""
    404  If-None-Match: "*"
    404  If-Modified-Since: "Sat, 01 Jan 2000 00:00:00 GMT" |}]
  (* Upstream (actix): POST with a matching If-None-Match gives 412. *)



(* The file system loader: dotfiles and symlinks, in a temporary directory. *)

let temp_root () =
  let root =
    Filename.concat (Filename.get_temp_dir_name ())
      (Printf.sprintf "dream-static-%i-%i"
        (Unix.getpid ()) (Random.State.bits (Random.State.make_self_init ())))
  in
  Unix.mkdir root 0o700;
  root

let write path contents =
  let channel = open_out_bin path in
  output_string channel contents;
  close_out channel

let rec remove path =
  match (Unix.lstat path).st_kind with
  | Unix.S_DIR ->
    Array.iter (fun entry -> remove (Filename.concat path entry))
      (Sys.readdir path);
    Unix.rmdir path
  | _ -> Unix.unlink path

let with_fixture f =
  let base = temp_root () in
  let root = Filename.concat base "www" in
  let outside = Filename.concat base "outside" in
  Unix.mkdir root 0o700;
  Unix.mkdir outside 0o700;
  Unix.mkdir (Filename.concat root ".mine") 0o700;
  Unix.mkdir (Filename.concat root "dir") 0o700;
  Unix.mkdir (Filename.concat outside "html") 0o700;
  write (Filename.concat root "name.txt") "name";
  write (Filename.concat root ".hidden.txt") "hidden";
  write (Filename.concat root ".hidden") "hidden";
  write (Filename.concat root ".env") "SECRET=1";
  write (Filename.concat root ".mine/name.txt") "mine";
  write (Filename.concat root "dir/index.html") "index";
  write (Filename.concat outside "index.html") "outside";
  write (Filename.concat outside "html/page.html") "page";
  Unix.symlink (Filename.concat outside "index.html")
    (Filename.concat root "index.html");
  Unix.symlink (Filename.concat outside "html") (Filename.concat root "html");
  Fun.protect ~finally:(fun () -> remove base) (fun () -> f root)

let serve root target =
  let app = Dream.router [Dream.get "/static/**" (Dream.static root)] in
  let response = Dream.test app (Dream.request ~target "") in
  let label =
    if String.length target <= 40 then target
    else Printf.sprintf "%s... (%i bytes)" (String.sub target 0 20)
      (String.length target)
  in
  match status response with
  | 200 ->
    let body = Lwt_main.run (Dream.body response) in
    Printf.printf "%-28S 200 %S\n" label body
  | n -> Printf.printf "%-28S %i\n" label n

(* Origin: pillarjs/send test/send.js, L941, L947 and L972, and
   expressjs/serve-static test/test.js, L130. *)
let%expect_test _ =
  with_fixture (fun root ->
    serve root "/static/.hidden.txt";
    serve root "/static/.mine/name.txt";
    serve root "/static/.nothere";
    serve root "/static/.hidden");
  [%expect {|
    "/static/.hidden.txt"        200 "hidden"
    "/static/.mine/name.txt"     200 "mine"
    "/static/.nothere"           404
    "/static/.hidden"            200 "hidden" |}]
  (* Upstream (send, serve-static): dotfiles are ignored by default (404), or
     denied (403). actix hides them too; Plug and Starlette serve them. *)

(* Origin: not from an upstream suite; added for Dream. *)
let%expect_test _ =
  with_fixture (fun root ->
    serve root "/static/name.txt";
    serve root "/static/.env";
    serve root "/static/dir";
    serve root "/static/dir/";
    serve root "/static/name.txt/");
  [%expect {|
    "/static/name.txt"           200 "name"
    "/static/.env"               200 "SECRET=1"
    "/static/dir"                404
    "/static/dir/"               404
    "/static/name.txt/"          404 |}]

(* Origin: not from an upstream suite; added for Dream. A FIFO, which a loader
   that read it whole would hang on. *)
let%expect_test _ =
  with_fixture (fun root ->
    Unix.mkfifo (Filename.concat root "fifo") 0o600;
    serve root "/static/fifo");
  [%expect {| "/static/fifo"               404 |}]

(* Origin: Starlette tests/test_staticfiles.py, L491 (a path below a file) and
   test_staticfiles_filename_too_long (L506). *)
let%expect_test _ =
  with_fixture (fun root ->
    serve root "/static/name.txt/foo";
    serve root ("/static/" ^ String.make 5000 'a' ^ ".txt"));
  [%expect {|
    "/static/name.txt/foo"       404
    "/static/aaaaaaaaaaaa... (5012 bytes)" 404 |}]

(* Origin: Starlette tests/test_staticfiles.py,
   test_staticfiles_follows_symlinks (L540) and
   test_staticfiles_follows_symlink_directories (L561). Upstream enables
   follow_symlink=True and expects 200; Starlette's default (in its code, not
   these tests) refuses a symlink that resolves outside the root. *)
let%expect_test _ =
  with_fixture (fun root ->
    serve root "/static/index.html";
    serve root "/static/html/page.html");
  [%expect {|
    "/static/index.html"         200 "outside"
    "/static/html/page.html"     200 "page" |}]
