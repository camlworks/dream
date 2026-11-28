(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2021 Anton Bachin *)



(* Routing cases adapted from the test suites of other web frameworks.
   Expectations record Dream's current behavior; "Upstream:" comments note where
   the sources expect something different. Each test starts with an "Origin:"
   comment naming the upstream test and line it comes from, or saying that it
   was added for Dream. Routes are registered in the upstream order unless the
   test says otherwise: Dream picks the first matching route, while Go 1.22+,
   httprouter and matchit pick the most specific one.

   Sources (cases adapted, not code copied):

   - Go net/http ServeMux: routing_tree_test.go (BSD-3-Clause)
     https://github.com/golang/go/tree/5e9534e62225b2f58f3b4b3d410e63f29f6566f5/src/net/http
   - julienschmidt/httprouter: tree_test.go, router_test.go (BSD-3-Clause)
     https://github.com/julienschmidt/httprouter/tree/484018016424d215c0b87c42f4c9b57d980fbd00
   - ibraheemdev/matchit (axum's router): tests/match.rs (MIT)
     https://github.com/ibraheemdev/matchit/blob/4b5a2c356022f544187d6e67325d8e98dd7f11ca/tests/match.rs
   - pillarjs/router (Express 5): test/router.js, test/layer.js (MIT)
     https://github.com/pillarjs/router/tree/d4f4d863778a4db895b71c55aa8c26d45f61cf03/test
   - pillarjs/path-to-regexp: src/cases.spec.ts (MIT)
     https://github.com/pillarjs/path-to-regexp/blob/c439054f178ae93a09e30f902c3976ee5a2434a5/src/cases.spec.ts *)



module Dream =
struct
  include Dream
  let path = path [@ocaml.warning "-3"]
end

let () =
  ignore Initialize.require

(* A route whose handler reports its label, the given parameters, and, for
   wildcard routes, the remaining path. The label is also sent in an X-Route
   header, so that the route that answered a HEAD request, which has no body,
   can be shown. *)
let route ?(params = []) make pattern label =
  make pattern (fun request ->
    let params =
      params
      |> List.map (fun name ->
        Printf.sprintf " %s=%S" name (Dream.param request name))
      |> String.concat ""
    in
    let rest =
      if String.length pattern >= 2
         && String.sub pattern (String.length pattern - 2) 2 = "**" then
        Printf.sprintf " path=%S"
          ("/" ^ String.concat "/" (Dream.path request))
      else
        ""
    in
    Dream.respond ~headers:["X-Route", label] (label ^ params ^ rest))

let get ?params pattern label = route ?params Dream.get pattern label

let request ?(method_ = `GET) routes target =
  let response =
    Dream.test (Dream.router routes) (Dream.request ~method_ ~target "") in
  let label =
    match method_ with
    | `GET -> target
    | _ -> Dream.method_to_string method_ ^ " " ^ target
  in
  match Dream.status_to_int (Dream.status response) with
  | 200 when method_ = `HEAD ->
    let route =
      Option.value ~default:"?" (Dream.header response "X-Route") in
    Printf.printf "%-32S -> %s (no body)\n" label route
  | 200 ->
    Printf.printf "%-32S -> %s\n" label
      (Lwt_main.run (Dream.body response))
  | n ->
    let allow =
      match Dream.header response "Allow" with
      | None -> ""
      | Some allow -> " Allow: " ^ allow
    in
    Printf.printf "%-32S -> %i%s\n" label n allow

(* Origin: Go routing_tree_test.go, TestRoutingNodeMatch (L131-L178). Go's
   method-less pattern "/item/{user}" becomes a Dream.any route. *)
let%expect_test _ =
  let routes = [
    route Dream.post "/item/:user" "POST item" ~params:["user"];
    get "/item/:user" "GET item" ~params:["user"];
    route Dream.any "/item/:user" "any item" ~params:["user"];
    route Dream.any "/item/:user/:id" "any item/:user/:id" ~params:["user"; "id"];
    route Dream.any "/item/:user/new" "any item/:user/new" ~params:["user"];
    route Dream.any "/item/" "any item/";
    get "/headwins" "GET headwins";
    route Dream.head "/headwins" "HEAD headwins";
    route Dream.any "/path/**" "any path/**";
  ] in
  request routes "/item/jba";
  request routes ~method_:`POST "/item/jba";
  request routes ~method_:`HEAD "/item/jba";
  request routes ~method_:(`Method "get") "/item/jba";
  request routes ~method_:`POST "/item/jba/17";
  request routes "/item/jba/new";
  request routes "/item/";
  request routes "/item";
  request routes "/headwins";
  request routes ~method_:`HEAD "/headwins";
  request routes "/path/to/file";
  request routes "/path/*";
  [%expect {|
    "/item/jba"                      -> GET item user="jba"
    "POST /item/jba"                 -> POST item user="jba"
    "HEAD /item/jba"                 -> GET item (no body)
    "get /item/jba"                  -> any item user="jba"
    "POST /item/jba/17"              -> any item/:user/:id user="jba" id="17"
    "/item/jba/new"                  -> any item/:user/:id user="jba" id="new"
    "/item/"                         -> any item/
    "/item"                          -> 404
    "/headwins"                      -> GET headwins
    "HEAD /headwins"                 -> HEAD headwins (no body)
    "/path/to/file"                  -> any path/** path="/to/file"
    "/path/*"                        -> any path/** path="/*" |}]
  (* Upstream (Go): "/item/jba/new" goes to "/item/{user}/new". No action:
     Dream picks the first matching route, by design (see Dream.router). *)

(* Origin: httprouter tree_test.go, TestTreeWildcard (L144-L183).
   "*filepath" becomes "**". *)
let%expect_test _ =
  let routes = [
    get "/" "/";
    get "/cmd/:tool/:sub" "cmd/:tool/:sub" ~params:["tool"; "sub"];
    get "/cmd/:tool/" "cmd/:tool/" ~params:["tool"];
    get "/src/**" "src/**";
    get "/search/" "search/";
    get "/search/:query" "search/:query" ~params:["query"];
    get "/user_:name" "user_:name";
    get "/user_:name/about" "user_:name/about";
    get "/files/:dir/**" "files/:dir/**" ~params:["dir"];
    get "/doc/" "doc/";
    get "/doc/go_faq.html" "doc/go_faq.html";
    get "/doc/go1.html" "doc/go1.html";
    get "/info/:user/public" "info/:user/public" ~params:["user"];
    get "/info/:user/project/:project" "info/:user/project/:project"
      ~params:["user"; "project"];
  ] in
  List.iter (request routes)
    ["/"; "/cmd/test/"; "/cmd/test"; "/cmd/test/3"; "/src/";
     "/src/some/file.png"; "/search/";
     "/search/someth!ng+in+\xc3\xbcn\xc3\xacc\xc3\xb3d\xc3\xa9";
     "/search/someth!ng+in+\xc3\xbcn\xc3\xacc\xc3\xb3d\xc3\xa9/";
     "/user_gopher"; "/user_gopher/about"; "/files/js/inc/framework.js";
     "/info/gordon/public"; "/info/gordon/project/go"];
  [%expect {|
    "/"                              -> /
    "/cmd/test/"                     -> cmd/:tool/ tool="test"
    "/cmd/test"                      -> 404
    "/cmd/test/3"                    -> cmd/:tool/:sub tool="test" sub="3"
    "/src/"                          -> src/** path="/"
    "/src/some/file.png"             -> src/** path="/some/file.png"
    "/search/"                       -> search/
    "/search/someth!ng+in+\195\188n\195\172c\195\179d\195\169" -> search/:query query="someth!ng+in+\195\188n\195\172c\195\179d\195\169"
    "/search/someth!ng+in+\195\188n\195\172c\195\179d\195\169/" -> 404
    "/user_gopher"                   -> 404
    "/user_gopher/about"             -> 404
    "/files/js/inc/framework.js"     -> files/:dir/** dir="js" path="/inc/framework.js"
    "/info/gordon/public"            -> info/:user/public user="gordon"
    "/info/gordon/project/go"        -> info/:user/project/:project user="gordon" project="go" |}]
  (* Upstream (httprouter): "/user_gopher" matches "/user_:name" with
     name=gopher; Dream has no mid-segment parameters. No action: a parameter
     is a whole path component, by design (see Dream.router). *)

(* Origin: matchit tests/match.rs, double_overlap (L247). *)
let%expect_test _ =
  let routes = [
    get "/:object/:id" "/:object/:id" ~params:["object"; "id"];
    get "/secret/:id/path" "/secret/:id/path" ~params:["id"];
    get "/secret/978" "/secret/978";
    get "/other/:object/:id/" "/other/:object/:id/" ~params:["object"; "id"];
    get "/other/an_object/:id" "/other/an_object/:id" ~params:["id"];
    get "/other/static/path" "/other/static/path";
    get "/other/long/static/path/" "/other/long/static/path/";
  ] in
  List.iter (request routes)
    ["/secret/978/path"; "/some_object/978"; "/secret/978";
     "/super_secret/978/"; "/other/object/1/"; "/other/object/1/2";
     "/other/an_object/1"; "/other/static/path"; "/other/long/static/path/"];
  [%expect {|
    "/secret/978/path"               -> /secret/:id/path id="978"
    "/some_object/978"               -> /:object/:id object="some_object" id="978"
    "/secret/978"                    -> /:object/:id object="secret" id="978"
    "/super_secret/978/"             -> 404
    "/other/object/1/"               -> /other/:object/:id/ object="object" id="1"
    "/other/object/1/2"              -> 404
    "/other/an_object/1"             -> /other/an_object/:id id="1"
    "/other/static/path"             -> /other/static/path
    "/other/long/static/path/"       -> /other/long/static/path/ |}]
  (* Upstream (matchit): "/secret/978" goes to the static route "/secret/978",
     "/other/an_object/1" to "/other/an_object/:id", and "/other/static/path"
     to its static route. No action: Dream picks the first matching route, by
     design (see Dream.router). *)

(* Origin: matchit tests/match.rs, catchall_off_by_one (L294). *)
let%expect_test _ =
  let routes = [
    get "/foo/**" "foo/**";
    get "/bar" "bar";
    get "/bar/" "bar/";
    get "/bar/**" "bar/**";
  ] in
  List.iter (request routes) ["/foo"; "/foo/"; "/foo/x"; "/bar"; "/bar/";
                              "/bar/x"];
  [%expect {|
    "/foo"                           -> 404
    "/foo/"                          -> foo/** path="/"
    "/foo/x"                         -> foo/** path="/x"
    "/bar"                           -> bar
    "/bar/"                          -> bar/
    "/bar/x"                         -> bar/** path="/x" |}]
  (* Upstream (matchit): a catch-all needs a non-empty rest, so "/foo/" is not
     found. No action: in Dream, [**] also matches an empty rest, by design
     (see Dream.router). *)

(* Origin: matchit tests/match.rs, overlap (L310). *)
let%expect_test _ =
  let routes = [
    get "/foo" "foo";
    get "/bar" "bar";
    get "/**" "**";
    get "/baz" "baz";
    get "/baz/" "baz/";
    get "/baz/x" "baz/x";
    get "/baz/:xxx" "baz/:xxx" ~params:["xxx"];
    get "/" "/";
    get "/xxx/**" "xxx/**";
    get "/xxx/" "xxx/";
  ] in
  List.iter (request routes)
    ["/foo"; "/bar"; "/baz"; "/baz/"; "/baz/x"; "/???"; "/"; ""; "/xxx/y";
     "/xxx/"; "/xxx"];
  [%expect {|
    "/foo"                           -> foo
    "/bar"                           -> bar
    "/baz"                           -> ** path="/baz"
    "/baz/"                          -> ** path="/baz/"
    "/baz/x"                         -> ** path="/baz/x"
    "/???"                           -> ** path="/"
    "/"                              -> ** path="/"
    ""                               -> ** path="/"
    "/xxx/y"                         -> ** path="/xxx/y"
    "/xxx/"                          -> ** path="/xxx/"
    "/xxx"                           -> ** path="/xxx" |}]
  (* Upstream (matchit): each static route matches itself, "" is not found,
     and "/xxx/" goes to "/xxx/". In an HTTP request, "/???" is the path "/"
     with the query "??". No action: Dream picks the first matching route, by
     design (see Dream.router), and reads the empty path as "/". *)

(* Origin: matchit tests/match.rs, missing_trailing_slash_param (L342),
   extra_trailing_slash_param (L358), missing_trailing_slash_catch_all (L370)
   and extra_trailing_slash_catch_all (L386). *)
let%expect_test _ =
  let routes = [
    get "/foo/:object/:id" "foo/:object/:id" ~params:["object"; "id"];
    get "/foo/bar/baz" "foo/bar/baz";
    get "/foo/secret/978/" "foo/secret/978/";
  ] in
  List.iter (request routes) ["/foo/secret/978/"; "/foo/secret/978"];
  let routes = [
    get "/foo/:object/:id" "foo/:object/:id" ~params:["object"; "id"];
    get "/foo/bar/baz" "foo/bar/baz";
    get "/foo/secret/978" "foo/secret/978";
  ] in
  List.iter (request routes) ["/foo/secret/978/"; "/foo/secret/978"];
  let routes = [
    get "/foo/**" "foo/**";
    get "/foo/bar/baz" "foo/bar/baz";
    get "/foo/secret/978/" "foo/secret/978/";
  ] in
  List.iter (request routes) ["/foo/secret/978"; "/foo/secret/978/"];
  let routes = [
    get "/foo/**" "foo/**";
    get "/foo/bar/baz" "foo/bar/baz";
    get "/foo/secret/978" "foo/secret/978";
  ] in
  List.iter (request routes) ["/foo/secret/978/"; "/foo/secret/978"];
  [%expect {|
    "/foo/secret/978/"               -> foo/secret/978/
    "/foo/secret/978"                -> foo/:object/:id object="secret" id="978"
    "/foo/secret/978/"               -> 404
    "/foo/secret/978"                -> foo/:object/:id object="secret" id="978"
    "/foo/secret/978"                -> foo/** path="/secret/978"
    "/foo/secret/978/"               -> foo/** path="/secret/978/"
    "/foo/secret/978/"               -> foo/** path="/secret/978/"
    "/foo/secret/978"                -> foo/** path="/secret/978" |}]
  (* Upstream (matchit): in the second table "/foo/secret/978" goes to its
     static route, and in the last two each static route matches itself. No
     action: Dream picks the first matching route, by design (see
     Dream.router). *)

(* Origin: matchit tests/match.rs, empty_param (L607). The routes "/a/x{foo}"
   and "/b/{foo}x" are left out: Dream has no mid-segment parameters. *)
let%expect_test _ =
  let routes = [
    get "/y/:foo" "y/:foo" ~params:["foo"];
    get "/x/:foo/z" "x/:foo/z" ~params:["foo"];
    get "/z/**" "z/**";
  ] in
  List.iter (request routes) ["/y/"; "/x//z"; "/z/"];
  [%expect {|
    "/y/"                            -> 404
    "/x//z"                          -> 404
    "/z/"                            -> z/** path="/" |}]
  (* Upstream (matchit): all not found. No action: in Dream, [**] also
     matches an empty rest, by design (see Dream.router). *)

(* Origin: matchit tests/match.rs, trailing_slash (L450). *)
let%expect_test _ =
  let routes = List.map (fun pattern -> get pattern pattern) [
    "/hi"; "/b/"; "/search/:query"; "/cmd/:tool/"; "/src/**"; "/x"; "/x/y";
    "/y/"; "/y/z"; "/0/:id"; "/0/:id/1"; "/1/:id/"; "/1/:id/2"; "/aa"; "/a/";
    "/admin"; "/admin/static"; "/admin/:category"; "/admin/:category/:page";
    "/doc"; "/doc/rust_faq.html"; "/doc/rust1.26.html"; "/no/a"; "/no/b";
    "/no/a/b/**"; "/api/:page/:name"; "/api/hello/:name/bar/";
    "/api/bar/:name"; "/api/baz/foo"; "/api/baz/foo/bar"; "/foo/:p"] in
  List.iter (request routes)
    ["/hi/"; "/b"; "/search/rustacean/"; "/cmd/vet"; "/src"; "/src/"; "/x/";
     "/y"; "/0/rust/"; "/1/rust"; "/a"; "/admin/"; "/doc/"; "/admin/static/";
     "/admin/cfg/"; "/admin/cfg/users/"; "/api/hello/x/bar"; "/api/baz/foo/";
     "/api/baz/bax/"; "/api/bar/huh/"; "/api/baz/foo/bar/"; "/api/world/abc/";
     "/foo/pp/"; "/"; "/no"; "/no/"; "/no/a/b"; "/no/a/b/"; "/_"; "/_/";
     "/api"; "/api/"; "/api/hello/x/foo"; "/api/baz/foo/bad"; "/foo/p/p"];
  [%expect {|
    "/hi/"                           -> 404
    "/b"                             -> 404
    "/search/rustacean/"             -> 404
    "/cmd/vet"                       -> 404
    "/src"                           -> 404
    "/src/"                          -> /src/** path="/"
    "/x/"                            -> 404
    "/y"                             -> 404
    "/0/rust/"                       -> 404
    "/1/rust"                        -> 404
    "/a"                             -> 404
    "/admin/"                        -> 404
    "/doc/"                          -> 404
    "/admin/static/"                 -> 404
    "/admin/cfg/"                    -> 404
    "/admin/cfg/users/"              -> 404
    "/api/hello/x/bar"               -> 404
    "/api/baz/foo/"                  -> 404
    "/api/baz/bax/"                  -> 404
    "/api/bar/huh/"                  -> 404
    "/api/baz/foo/bar/"              -> 404
    "/api/world/abc/"                -> 404
    "/foo/pp/"                       -> 404
    "/"                              -> 404
    "/no"                            -> 404
    "/no/"                           -> 404
    "/no/a/b"                        -> 404
    "/no/a/b/"                       -> /no/a/b/** path="/"
    "/_"                             -> 404
    "/_/"                            -> 404
    "/api"                           -> 404
    "/api/"                          -> 404
    "/api/hello/x/foo"               -> 404
    "/api/baz/foo/bad"               -> 404
    "/foo/p/p"                       -> 404 |}]
  (* Upstream (matchit): all not found, including "/src/" and "/no/a/b/",
     since a catch-all needs a non-empty rest. No action: in Dream, [**] also
     matches an empty rest, by design (see Dream.router). *)

(* Origin: pillarjs/router test/router.js, "with caseSensitive option" (L181)
   and "with strict option" (L255). Express is case-insensitive and ignores a
   trailing slash by default. *)
let%expect_test _ =
  request [get "/foo/bar" "foo/bar"] "/FOO/bar";
  request [get "/foo" "foo"] "/foo/";
  [%expect {|
    "/FOO/bar"                       -> 404
    "/foo/"                          -> 404 |}]
  (* Upstream (Express defaults): both match. No action: Dream matches case
     and trailing slashes strictly, by design (see Dream.router). *)

(* Origin: pillarjs/router test/layer.js, L96-L106: a parameter that fails to
   percent-decode. *)
let%expect_test _ =
  request [get "/:param" ":param" ~params:["param"]] "/%Z";
  [%expect {| "/%Z"                            -> :param param="%Z" |}]
  (* Upstream (Express): 400, "Failed to decode param '%Z'". No action: as in
     Dream.from_percent_encoded, a malformed escape passes through. *)

(* Origin: pillarjs/path-to-regexp src/cases.spec.ts, path "/:test"
   (L457-L503). *)
let%expect_test _ =
  let routes = [get "/:test" ":test" ~params:["test"]] in
  List.iter (request routes)
    ["/route/"; "/route.json"; "/caf%C3%A9"; "/;,:@&=+$-_.!~*()";
     "/param%2523"];
  [%expect {|
    "/route/"                        -> 404
    "/route.json"                    -> :test test="route.json"
    "/caf%C3%A9"                     -> :test test="caf\195\169"
    "/;,:@&=+$-_.!~*()"              -> :test test=";,:@&=+$-_.!~*()"
    "/param%2523"                    -> :test test="param%23" |}]
  (* Upstream (path-to-regexp): "/route/" matches with test=route, since a
     trailing slash is allowed by default. No action: Dream matches trailing
     slashes strictly, by design (see Dream.router). *)
