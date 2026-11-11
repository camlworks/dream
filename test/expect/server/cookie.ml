(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2021 Anton Bachin *)



let () =
  ignore Initialize.require



let set_cookie_handler name value request =
  let response = Dream.response "" in
  Dream.set_cookie ~encrypt:false response request name value;
  Lwt.return response

let drop_cookie_handler name request =
  let response = Dream.response "" in
  Dream.drop_cookie response request name;
  Lwt.return response

let run_cookie_handler ?(prefix = "") ?(tls = false) target routes =
  let request = Dream.request ~target "" in
  Dream__server.Helpers.set_tls request tls;
  Dream.test ~prefix (Dream.router routes) request

let set_cookie_header ?prefix ?tls target routes =
  run_cookie_handler ?prefix ?tls target routes
  |> fun response -> Dream.header response "Set-Cookie"

let cookie_path header =
  header
  |> String.split_on_char ';'
  |> List.map String.trim
  |> List.find_opt (String.starts_with ~prefix:"Path=")
  |> Option.value ~default:"Path=<none>"



let%expect_test _ =
  set_cookie_header "/sub/foo" [
    Dream.get "/sub/**" (set_cookie_handler "c" "v");
  ]
  |> Option.get
  |> cookie_path
  |> print_endline;
  [%expect {| Path=/ |}]

let%expect_test _ =
  set_cookie_header ~prefix:"/app" "/app/sub/foo" [
    Dream.get "/sub/**" (set_cookie_handler "c" "v");
  ]
  |> Option.get
  |> cookie_path
  |> print_endline;
  [%expect {| Path=/app |}]

let%expect_test _ =
  set_cookie_header ~prefix:"/app" "/app/sub/foo" [
    Dream.scope "/sub" [] [
      Dream.get "/foo" (set_cookie_handler "c" "v");
    ];
  ]
  |> Option.get
  |> cookie_path
  |> print_endline;
  [%expect {| Path=/app |}]

let%expect_test _ =
  let set_path =
    set_cookie_header ~prefix:"/app" "/app/sub/foo" [
      Dream.get "/sub/**" (set_cookie_handler "c" "v");
    ]
    |> Option.get
    |> cookie_path
  in
  let drop_path =
    set_cookie_header ~prefix:"/app" "/app/sub/foo" [
      Dream.get "/sub/**" (drop_cookie_handler "c");
    ]
    |> Option.get
    |> cookie_path
  in
  Printf.printf "set: %s\ndrop: %s\n" set_path drop_path;
  [%expect {|
    set: Path=/app
    drop: Path=/app |}]

let%expect_test _ =
  set_cookie_header ~tls:true "/sub/foo" [
    Dream.get "/sub/**" (set_cookie_handler "c" "v");
  ]
  |> Option.get
  |> print_endline;
  [%expect {|
    __Host-c=v; Path=/; Secure; HttpOnly; SameSite=Lax |}]
