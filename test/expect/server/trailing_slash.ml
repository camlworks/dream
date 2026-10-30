(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream. *)



let () =
  ignore Initialize.require

(* Run [target] through [Dream.trailing_slash policy] in front of a router that
   has a handler at each of [/one] and [/two/], and print the resulting status,
   any [Location] header, and the body of whichever handler ran. *)
let show ?status ?(method_ = `GET) policy target =
  let app =
    Dream.trailing_slash ?status policy
    @@ Dream.router [
      Dream.get "/one" (fun _ -> Dream.respond "one");
      Dream.get "/two/" (fun _ -> Dream.respond "two");
    ]
  in
  let response =
    Dream.request ~method_ ~target ""
    |> Dream.test app
  in
  let status = Dream.status response in
  Printf.printf "%s -> %i %s"
    target (Dream.status_to_int status) (Dream.status_to_string status);
  (match Dream.header response "Location" with
   | Some location -> Printf.printf "  Location: %s" location
   | None -> ());
  print_newline ();
  let body =
    Dream.client_stream response
    |> Obj.magic
    |> Dream_pure.Stream.read_until_close
    |> Lwt_main.run
  in
  if body <> "" then Printf.printf "%s\n" body

(* Strict: /one and /two/ are matched only in their declared form. *)
let%expect_test _ =
  show `Strict "/one";
  show `Strict "/one/";
  show `Strict "/two/";
  show `Strict "/two";
  [%expect {|
    /one -> 200 OK
    one
    /one/ -> 404 Not Found
    /two/ -> 200 OK
    two
    /two -> 404 Not Found |}]

(* Drop: a trailing slash is stripped before routing; routes are declared
   without one, so /one and /one/ both reach the handler with 200. *)
let%expect_test _ =
  show `Drop "/one";
  show `Drop "/one/";
  [%expect {|
    /one -> 200 OK
    one
    /one/ -> 200 OK
    one |}]

(* Append: a trailing slash is added before routing; routes are declared with
   one, so /two and /two/ both reach the handler with 200. *)
let%expect_test _ =
  show `Append "/two";
  show `Append "/two/";
  [%expect {|
    /two -> 200 OK
    two
    /two/ -> 200 OK
    two |}]

(* Redirect_drop: the slashed form 301s to the slash-less canonical URL, which
   then serves 200. The query string is preserved. *)
let%expect_test _ =
  show `Redirect_drop "/one";
  show `Redirect_drop "/one/";
  show `Redirect_drop "/one/?a=1&b=2";
  [%expect {|
    /one -> 200 OK
    one
    /one/ -> 301 Moved Permanently  Location: /one
    /one/?a=1&b=2 -> 301 Moved Permanently  Location: /one?a=1&b=2 |}]

(* Redirect_append: the slash-less form 301s to the slashed canonical URL. *)
let%expect_test _ =
  show `Redirect_append "/two/";
  show `Redirect_append "/two";
  [%expect {|
    /two/ -> 200 OK
    two
    /two -> 301 Moved Permanently  Location: /two/ |}]

(* ~status overrides the redirect code; 308 preserves the method. *)
let%expect_test _ =
  show ~status:`Permanent_Redirect `Redirect_drop "/one/";
  show ~status:`Permanent_Redirect ~method_:`POST `Redirect_drop "/one/";
  [%expect {|
    /one/ -> 308 Permanent Redirect  Location: /one
    /one/ -> 308 Permanent Redirect  Location: /one |}]

(* The root path is never rewritten or redirected under any policy. *)
let%expect_test _ =
  show `Redirect_drop "/";
  show `Drop "/";
  show `Redirect_append "/";
  [%expect {|
    / -> 404 Not Found
    / -> 404 Not Found
    / -> 404 Not Found |}]
