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

   - Go net/http ServeMux: routing_tree_test.go, pattern_test.go,
     server_test.go, serve_test.go, request_test.go (BSD-3-Clause)
     https://github.com/golang/go/tree/5e9534e62225b2f58f3b4b3d410e63f29f6566f5/src/net/http
   - julienschmidt/httprouter: tree_test.go, router_test.go (BSD-3-Clause)
     https://github.com/julienschmidt/httprouter/tree/484018016424d215c0b87c42f4c9b57d980fbd00
   - ibraheemdev/matchit (axum's router): tests/match.rs (MIT)
     https://github.com/ibraheemdev/matchit/blob/4b5a2c356022f544187d6e67325d8e98dd7f11ca/tests/match.rs
   - pillarjs/router (Express 5): test/route.js, test/router.js,
     test/layer.js (MIT)
     https://github.com/pillarjs/router/tree/d4f4d863778a4db895b71c55aa8c26d45f61cf03/test
   - pillarjs/path-to-regexp: src/cases.spec.ts (MIT)
     https://github.com/pillarjs/path-to-regexp/blob/c439054f178ae93a09e30f902c3976ee5a2434a5/src/cases.spec.ts
   - Phoenix: test/phoenix/router/routing_test.exs (MIT)
     https://github.com/phoenixframework/phoenix/blob/ce22e791c589a04c2812ea14c1e39da2646027b7/test/phoenix/router/routing_test.exs
   - anuragsoni/routes: test/routing_test.ml (BSD-3-Clause)
     https://github.com/anuragsoni/routes/blob/9e9aa89af0dc6c3cbebd964d89c48379808e6607/test/routing_test.ml *)



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

let registers pattern =
  try
    ignore (Dream.get pattern (fun _ -> Dream.respond ""));
    Printf.printf "%-20S accepted\n" pattern
  with Failure message ->
    Printf.printf "%-20S %s\n" pattern message



(* Origin: Go routing_tree_test.go, TestRoutingNodeMatch (L103-L130), on the
   tree from getTestTree (L46). Go picks the most specific pattern; the routes
   are reordered most-specific-first here. "{$}" becomes a trailing slash and
   "{x...}" becomes "**". *)
let%expect_test _ =
  let routes = [
    get "/a" "a";
    get "/a/b" "a/b";
    get "/a/b/" "a/b/";
    get "/g/h/i" "g/h/i";
    get "/a/:x" "a/:x" ~params:["x"];
    get "/g/:x/j" "g/:x/j" ~params:["x"];
    get "/a/b/:y" "a/b/:y" ~params:["y"];
    get "/a/b/**" "a/b/**";
  ] in
  List.iter (request routes)
    ["/a"; "/b"; "/a/b"; "/a/c"; "/a/b/"; "/a/b/c"; "/a/b/c/d"; "/g/h/i";
     "/g/h/j"];
  [%expect {|
    "/a"                             -> a
    "/b"                             -> 404
    "/a/b"                           -> a/b
    "/a/c"                           -> a/:x x="c"
    "/a/b/"                          -> a/b/
    "/a/b/c"                         -> a/b/:y y="c"
    "/a/b/c/d"                       -> a/b/** path="/c/d"
    "/g/h/i"                         -> g/h/i
    "/g/h/j"                         -> g/:x/j x="h" |}]

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
  (* Upstream (Go): "/item/jba/new" goes to "/item/{user}/new". *)

(* Origin: Go routing_tree_test.go, TestRoutingNodeMatch (L179-L210): a
   trailing slash, a single wildcard, and a multi wildcard. *)
let%expect_test _ =
  List.iter (request [get "/a/b/" "a/b/"])
    ["/a/b"; "/a/b/"; "/a/b/c"; "/a/b/c/d"];
  List.iter (request [get "/a/b/:w" "a/b/:w" ~params:["w"]])
    ["/a/b"; "/a/b/"; "/a/b/c"; "/a/b/c/d"];
  List.iter (request [get "/a/b/**" "a/b/**"])
    ["/a/b"; "/a/b/"; "/a/b/c"; "/a/b/c/d"];
  [%expect {|
    "/a/b"                           -> 404
    "/a/b/"                          -> a/b/
    "/a/b/c"                         -> 404
    "/a/b/c/d"                       -> 404
    "/a/b"                           -> 404
    "/a/b/"                          -> 404
    "/a/b/c"                         -> a/b/:w w="c"
    "/a/b/c/d"                       -> 404
    "/a/b"                           -> 404
    "/a/b/"                          -> a/b/** path="/"
    "/a/b/c"                         -> a/b/** path="/c"
    "/a/b/c/d"                       -> a/b/** path="/c/d" |}]

(* Origin: Go request_test.go, TestStatus (L1639-L1666). Upstream: a method
   mismatch gives 405 Method Not Allowed, with an Allow header; "/r" and PUT
   "/r" are redirected to "/r/". *)
let%expect_test _ =
  let routes = [
    get "/g" "GET g";
    route Dream.post "/p" "POST p";
    route Dream.patch "/p" "PATCH p";
    route Dream.put "/r" "PUT r";
    get "/r/" "GET r/";
  ] in
  request routes "/g";
  request routes ~method_:`HEAD "/g";
  request routes ~method_:`POST "/g";
  request routes "/x";
  request routes "/p";
  request routes "/./p";
  request routes "/r/";
  request routes "/r";
  request routes ~method_:`HEAD "/r/";
  request routes ~method_:`HEAD "/r";
  request routes ~method_:`PUT "/r/";
  request routes ~method_:`PUT "/r";
  [%expect {|
    "/g"                             -> GET g
    "HEAD /g"                        -> GET g (no body)
    "POST /g"                        -> 404
    "/x"                             -> 404
    "/p"                             -> 404
    "/./p"                           -> 404
    "/r/"                            -> GET r/
    "/r"                             -> 404
    "HEAD /r/"                       -> GET r/ (no body)
    "HEAD /r"                        -> 404
    "PUT /r/"                        -> 404
    "PUT /r"                         -> PUT r |}]
  (* Upstream (Go): POST /g is 405 "GET, HEAD"; GET /p and /./p are 405
     "PATCH, POST"; PUT /r/ is 405 "GET, HEAD". *)

(* Origin: Go server_test.go, TestEscapedPathsAndPatterns (L192-L216): paths
   matching each pattern since Go 1.22, then those that matched in Go 1.21. *)
let%expect_test _ =
  let routes = [
    get "/a" "/a";
    get "/%62" "/%62";
    get "/%7B/%7D" "/%7B/%7D";
    get "/%x" "/%x";
  ] in
  List.iter (request routes)
    ["/a"; "/%61"; "/b"; "/%62"; "/{/}"; "/%7b/}"; "/{/%7d"; "/%7B/%7D";
     "/%25x"];
  List.iter (request routes) ["/%2562"; "/%257B/%257D"];
  [%expect {|
    "/a"                             -> /a
    "/%61"                           -> /a
    "/b"                             -> 404
    "/%62"                           -> 404
    "/{/}"                           -> 404
    "/%7b/}"                         -> 404
    "/{/%7d"                         -> 404
    "/%7B/%7D"                       -> 404
    "/%25x"                          -> /%x
    "/%2562"                         -> /%62
    "/%257B/%257D"                   -> /%7B/%7D |}]
  (* Upstream (Go 1.22+): the first group matches its patterns, and the second
     does not. In Go 1.21, patterns were not unescaped. *)

(* Origin: Go request_test.go, TestPathValueAndPattern (L1550-L1588). *)
let%expect_test _ =
  let routes = [
    get "/names/:name/**" "names" ~params:["name"];
    get "/:a/is/:b/**" "is" ~params:["a"; "b"];
  ] in
  List.iter (request routes)
    ["/now/is/the/time/for/all"; "/names/%2fjohn/address";
     "/names/john%2Fdoe/there/is%2F/more"; "/names/n/*"];
  [%expect {|
    "/now/is/the/time/for/all"       -> is a="now" b="the" path="/time/for/all"
    "/names/%2fjohn/address"         -> names name="/john" path="/address"
    "/names/john%2Fdoe/there/is%2F/more" -> names name="john/doe" path="/there/is//more"
    "/names/n/*"                     -> names name="n" path="/*" |}]

(* Origin: Go server_test.go, TestFindHandler (L73-L98). Go's subtree
   patterns "/foo/" and "/bar/" become "/foo/**" and "/bar/**". *)
let%expect_test _ =
  let routes = [
    get "/" "/";
    get "/foo/**" "foo/**";
    get "/foo" "foo";
    get "/bar/**" "bar/**";
    get "//foo" "//foo";
  ] in
  List.iter (request routes)
    ["/"; "//"; "/foo/../bar/./..//baz"; "/foo"; "/foo/x"; "/bar/x"; "/bar"];
  [%expect {|
    "/"                              -> /
    "//"                             -> /
    "/foo/../bar/./..//baz"          -> foo/** path="/../bar/./../baz"
    "/foo"                           -> foo
    "/foo/x"                         -> foo/** path="/x"
    "/bar/x"                         -> bar/** path="/x"
    "/bar"                           -> 404 |}]
  (* Upstream (Go): "//" and "/foo/../bar/./..//baz" are redirected (307) to
     their cleaned paths, "/" and "/baz"; "/bar" to "/bar/". *)

(* Origin: Go serve_test.go, serveMuxTests (L334-L362), GET on google.com. The
   relevant serveMuxRegister patterns are "/dir/" and "/search". *)
let%expect_test _ =
  let routes = [get "/dir/**" "dir/**"; get "/search" "search"] in
  List.iter (request routes)
    ["/"; "/dir"; "/dir/"; "/dir/file"; "/search"; "/search/"; "/search/foo";
     "/../search"; "/dir/.."; "/dir/./file"];
  [%expect {|
    "/"                              -> 404
    "/dir"                           -> 404
    "/dir/"                          -> dir/** path="/"
    "/dir/file"                      -> dir/** path="/file"
    "/search"                        -> search
    "/search/"                       -> 404
    "/search/foo"                    -> 404
    "/../search"                     -> 404
    "/dir/.."                        -> dir/** path="/.."
    "/dir/./file"                    -> dir/** path="/./file" |}]
  (* Upstream (Go): "/dir", "/../search", "/dir/.." and "/dir/./file" are
     redirected (307). *)

(* Origin: Go serve_test.go, TestMuxRedirectLeadingSlashes (L510). Upstream
   registers no routes and expects a redirect to "/foo.txt". *)
let%expect_test _ =
  List.iter (request [get "/foo.txt" "foo.txt"])
    ["//foo.txt"; "///foo.txt"; "/../../foo.txt"];
  [%expect {|
    "//foo.txt"                      -> foo.txt
    "///foo.txt"                     -> foo.txt
    "/../../foo.txt"                 -> 404 |}]

(* Origin: not from an upstream suite; added for Dream. Dot-segments and NUL
   bytes reach parameters and wildcards. *)
let%expect_test _ =
  let routes = [
    get "/a/:x/c" "a/:x/c" ~params:["x"];
    get "/static/**" "static/**";
    get "/:x" ":x" ~params:["x"];
  ] in
  List.iter (request routes)
    ["/a/../c"; "/a/%2e%2e/c"; "/static/../etc/passwd";
     "/static/%2e%2e/etc/passwd"; "/a%00b"];
  [%expect {|
    "/a/../c"                        -> a/:x/c x=".."
    "/a/%2e%2e/c"                    -> a/:x/c x=".."
    "/static/../etc/passwd"          -> static/** path="/../etc/passwd"
    "/static/%2e%2e/etc/passwd"      -> static/** path="/../etc/passwd"
    "/a%00b"                         -> :x x="a\000b" |}]

(* Origin: httprouter tree_test.go, TestEmptyWildcardName (L300) and
   TestTreeDoubleWildcard (L345); "/src/*filepath" from TestTreeWildcard
   (L150) and "/src/*filepath/x" from TestTreeCatchAllConflict (L320). *)
let%expect_test _ =
  List.iter registers
    ["/user:"; "/user:/"; "/cmd/:/"; "/src/*"; "/:foo:bar"; "/:foo:bar/";
     "/:foo*bar"; "/src/*filepath"; "/src/*filepath/x"];
  [%expect {|
    "/user:"             accepted
    "/user:/"            accepted
    "/cmd/:/"            Empty path parameter name in '/cmd/:/'
    "/src/*"             accepted
    "/:foo:bar"          accepted
    "/:foo:bar/"         accepted
    "/:foo*bar"          accepted
    "/src/*filepath"     Path wildcard must be just '**'
    "/src/*filepath/x"   Path wildcard must be just '**' |}]
  (* Upstream (httprouter): every pattern here except "/src/*filepath" is
     rejected. *)

(* Origin: Go pattern_test.go, L150: duplicate wildcard names are rejected
   ("/a/{x}/b/{x...}"). *)
let%expect_test _ =
  registers "/a/:x/b/:x";
  request [get "/a/:x/b/:x" "a/:x/b/:x" ~params:["x"]] "/a/1/b/2";
  [%expect {|
    "/a/:x/b/:x"         accepted
    "/a/1/b/2"                       -> a/:x/b/:x x="2" |}]

(* Origin: not from an upstream suite; added for Dream. *)
let%expect_test _ =
  List.iter registers ["/a//b"; "a/b"; "/src/**/x"];
  request [get "/a" "first"; get "/a" "second"] "/a";
  request [get "/:foo:bar" ":foo:bar" ~params:["foo:bar"]] "/x";
  request [get "/a//b" "a//b"] "/a/b";
  request [get "a/b" "a/b"] "/a/b";
  [%expect {|
    "/a//b"              accepted
    "a/b"                accepted
    "/src/**/x"          Path wildcard must be last
    "/a"                             -> first
    "/x"                             -> :foo:bar foo:bar="x"
    "/a/b"                           -> a//b
    "/a/b"                           -> a/b |}]

(* Origin: httprouter tree_test.go, TestTreeAddAndGet (L105-L139). *)
let%expect_test _ =
  let literals =
    ["/hi"; "/contact"; "/co"; "/c"; "/a"; "/ab"; "/doc/"; "/doc/go_faq.html";
     "/doc/go1.html"; "/\xce\xb1"; "/\xce\xb2"] in
  let routes = List.map (fun l -> get l l) literals in
  List.iter (request routes)
    ["/a"; "/"; "/hi"; "/contact"; "/co"; "/con"; "/cona"; "/no"; "/ab";
     "/\xce\xb1"; "/\xce\xb2"];
  [%expect {|
    "/a"                             -> /a
    "/"                              -> 404
    "/hi"                            -> /hi
    "/contact"                       -> /contact
    "/co"                            -> /co
    "/con"                           -> 404
    "/cona"                          -> 404
    "/no"                            -> 404
    "/ab"                            -> /ab
    "/\206\177"                      -> /α
    "/\206\178"                      -> /β |}]

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
     name=gopher; Dream has no mid-segment parameters. *)

(* Origin: httprouter router_test.go, TestRouterNotFound (L409-L430).
   Upstream: each request but "/nope" is redirected (301): trailing slash,
   case, or path cleaning. *)
let%expect_test _ =
  let routes = [get "/path" "path"; get "/dir/" "dir/"; get "/" "/"] in
  List.iter (request routes)
    ["/path/"; "/dir"; ""; "/PATH"; "/DIR/"; "/PATH/"; "/DIR"; "/../path";
     "/nope"];
  [%expect {|
    "/path/"                         -> 404
    "/dir"                           -> 404
    ""                               -> /
    "/PATH"                          -> 404
    "/DIR/"                          -> 404
    "/PATH/"                         -> 404
    "/DIR"                           -> 404
    "/../path"                       -> 404
    "/nope"                          -> 404 |}]

(* Origin: httprouter tree_test.go, TestTreeTrailingSlashRedirect
   (L367-L431). None of these requests match a route; httprouter suggests a
   redirect for the first fifteen. The route "/vendor/:x/*y" is left out:
   Dream rejects "*y". *)
let%expect_test _ =
  let routes = List.map (fun pattern -> get pattern pattern) [
    "/hi"; "/b/"; "/search/:query"; "/cmd/:tool/"; "/src/**"; "/x"; "/x/y";
    "/y/"; "/y/z"; "/0/:id"; "/0/:id/1"; "/1/:id/"; "/1/:id/2"; "/aa"; "/a/";
    "/admin"; "/admin/:category"; "/admin/:category/:page"; "/doc";
    "/doc/go_faq.html"; "/doc/go1.html"; "/no/a"; "/no/b"; "/api/hello/:name"]
  in
  List.iter (request routes)
    ["/hi/"; "/b"; "/search/gopher/"; "/cmd/vet"; "/src"; "/x/"; "/y";
     "/0/go/"; "/1/go"; "/a"; "/admin/"; "/admin/config/";
     "/admin/config/permissions/"; "/doc/"; "/vendor/x";
     "/"; "/no"; "/no/"; "/_"; "/_/"; "/api/world/abc"];
  [%expect {|
    "/hi/"                           -> 404
    "/b"                             -> 404
    "/search/gopher/"                -> 404
    "/cmd/vet"                       -> 404
    "/src"                           -> 404
    "/x/"                            -> 404
    "/y"                             -> 404
    "/0/go/"                         -> 404
    "/1/go"                          -> 404
    "/a"                             -> 404
    "/admin/"                        -> 404
    "/admin/config/"                 -> 404
    "/admin/config/permissions/"     -> 404
    "/doc/"                          -> 404
    "/vendor/x"                      -> 404
    "/"                              -> 404
    "/no"                            -> 404
    "/no/"                           -> 404
    "/_"                             -> 404
    "/_/"                            -> 404
    "/api/world/abc"                 -> 404 |}]

(* Origin: matchit tests/match.rs, partial_overlap (L5) and wildcard_overlap
   (L19). "{*rest}" becomes "**". Routes are registered in matchit's order;
   matchit prefers static segments over parameters, and parameters over
   catch-alls, whatever the order. *)
let%expect_test _ =
  request [get "/foo_bar" "foo_bar"; get "/foo/bar" "foo/bar"] "/foo/";
  request [get "/foo" "foo"; get "/foo/bar" "foo/bar"] "/foo/";
  let routes = [get "/path/foo" "path/foo"; get "/path/**" "path/**"] in
  List.iter (request routes) ["/path/foo"; "/path/bar"; "/path/foo/"];
  let routes = [
    get "/path/foo/:arg" "path/foo/:arg" ~params:["arg"];
    get "/path/**" "path/**";
  ] in
  List.iter (request routes)
    ["/path/foo/myarg"; "/path/foo/myarg/"; "/path/foo/myarg/bar/baz"];
  [%expect {|
    "/foo/"                          -> 404
    "/foo/"                          -> 404
    "/path/foo"                      -> path/foo
    "/path/bar"                      -> path/** path="/bar"
    "/path/foo/"                     -> path/** path="/foo/"
    "/path/foo/myarg"                -> path/foo/:arg arg="myarg"
    "/path/foo/myarg/"               -> path/** path="/foo/myarg/"
    "/path/foo/myarg/bar/baz"        -> path/** path="/foo/myarg/bar/baz" |}]

(* Origin: matchit tests/match.rs, overlapping_param_backtracking (L45). *)
let%expect_test _ =
  let routes = [
    get "/:object/:id" "/:object/:id" ~params:["object"; "id"];
    get "/secret/:id/path" "/secret/:id/path" ~params:["id"];
  ] in
  List.iter (request routes) ["/secret/978/path"; "/something/978"; "/secret/978"];
  [%expect {|
    "/secret/978/path"               -> /secret/:id/path id="978"
    "/something/978"                 -> /:object/:id object="something" id="978"
    "/secret/978"                    -> /:object/:id object="secret" id="978" |}]

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
     to its static route. *)

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
     found. *)

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
     with the query "??". *)

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
     static route, and in the last two each static route matches itself. *)

(* Origin: matchit tests/match.rs, trailing_slash_overlap (L437),
   backtracking_trailing_slash (L527) and root_trailing_slash (L536). *)
let%expect_test _ =
  let routes = [
    get "/foo/:x/baz/" "foo/:x/baz/" ~params:["x"];
    get "/foo/:x/baz" "foo/:x/baz" ~params:["x"];
    get "/foo/bar/bar" "foo/bar/bar";
  ] in
  List.iter (request routes) ["/foo/x/baz/"; "/foo/x/baz"; "/foo/bar/bar"];
  request [get "/a/:b/:c" "a/:b/:c" ~params:["b"; "c"];
           get "/a/b/:c/d/" "a/b/:c/d/" ~params:["c"]] "/a/b/c/d";
  request [get "/foo" "foo"; get "/bar" "bar";
           get "/:baz" ":baz" ~params:["baz"]] "/";
  [%expect {|
    "/foo/x/baz/"                    -> foo/:x/baz/ x="x"
    "/foo/x/baz"                     -> foo/:x/baz x="x"
    "/foo/bar/bar"                   -> foo/bar/bar
    "/a/b/c/d"                       -> 404
    "/"                              -> 404 |}]

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
  (* Upstream (matchit): all not found. *)

(* Origin: matchit tests/match.rs, basic (L705). *)
let%expect_test _ =
  let literals =
    ["/hi"; "/contact"; "/co"; "/c"; "/a"; "/ab"; "/doc/"; "/doc/rust_faq.html";
     "/doc/rust1.26.html"; "/\xca\xaf"; "/\xce\xb2"; "/sd!here"; "/sd$here";
     "/sd&here"; "/sd'here"; "/sd(here"; "/sd)here"; "/sd+here"; "/sd,here";
     "/sd;here"; "/sd=here"] in
  let routes = List.map (fun l -> get l l) literals in
  List.iter (request routes)
    ["/a"; ""; "/hi"; "/contact"; "/co"; "/ab"; "/\xca\xaf"; "/\xce\xb2";
     "/sd!here"; "/sd$here"; "/sd&here"; "/sd'here"; "/sd(here"; "/sd)here";
     "/sd+here"; "/sd,here"; "/sd;here"; "/sd=here"];
  [%expect {|
    "/a"                             -> /a
    ""                               -> 404
    "/hi"                            -> /hi
    "/contact"                       -> /contact
    "/co"                            -> /co
    "/ab"                            -> /ab
    "/\202\175"                      -> /ʯ
    "/\206\178"                      -> /β
    "/sd!here"                       -> /sd!here
    "/sd$here"                       -> /sd$here
    "/sd&here"                       -> /sd&here
    "/sd'here"                       -> /sd'here
    "/sd(here"                       -> /sd(here
    "/sd)here"                       -> /sd)here
    "/sd+here"                       -> /sd+here
    "/sd,here"                       -> /sd,here
    "/sd;here"                       -> /sd;here
    "/sd=here"                       -> /sd=here |}]

(* Origin: not from an upstream suite; added for Dream. A percent-encoded
   request for a non-ASCII literal route. *)
let%expect_test _ =
  request [get "/\xca\xaf" "/\xca\xaf"] "/%CA%AF";
  [%expect {| "/%CA%AF"                        -> /ʯ |}]

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
     since a catch-all needs a non-empty rest. *)

(* Origin: pillarjs/router test/route.js, L694-L712. *)
let%expect_test _ =
  request [get "/:foo" ":foo" ~params:["foo"]] "/bar/bar";
  request [get "/:foo/:bar" ":foo/:bar" ~params:["foo"; "bar"]] "/fizz/buzz";
  [%expect {|
    "/bar/bar"                       -> 404
    "/fizz/buzz"                     -> :foo/:bar foo="fizz" bar="buzz" |}]

(* Origin: pillarjs/router test/router.js, "with caseSensitive option" (L181)
   and "with strict option" (L255). Express is case-insensitive and ignores a
   trailing slash by default. *)
let%expect_test _ =
  request [get "/foo/bar" "foo/bar"] "/FOO/bar";
  request [get "/foo" "foo"] "/foo/";
  [%expect {|
    "/FOO/bar"                       -> 404
    "/foo/"                          -> 404 |}]
  (* Upstream (Express defaults): both match. *)

(* Origin: pillarjs/router test/layer.js, L96-L106: a parameter that fails to
   percent-decode. *)
let%expect_test _ =
  request [get "/:param" ":param" ~params:["param"]] "/%Z";
  [%expect {| "/%Z"                            -> :param param="%Z" |}]
  (* Upstream (Express): 400, "Failed to decode param '%Z'". *)

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
     trailing slash is allowed by default. *)

(* Origin: pillarjs/path-to-regexp src/cases.spec.ts, path "/test/" (L445-L453)
   and path "/café" with encodePath (L1293-L1300). *)
let%expect_test _ =
  List.iter (request [get "/test/" "test/"]) ["/test/"; "/test"; "/test//"];
  request [get "/caf\xc3\xa9" "caf\xc3\xa9"] "/caf%C3%A9";
  [%expect {|
    "/test/"                         -> test/
    "/test"                          -> 404
    "/test//"                        -> test/
    "/caf%C3%A9"                     -> café |}]
  (* Upstream (path-to-regexp): "/test//" does not match "/test/". *)

(* Origin: Phoenix test/phoenix/router/routing_test.exs. The routes are those
   of the test router (L44-L80), in its order, as far as Dream can express
   them; the requests are from L101, L148, L151, L160, L165, L189, L214, L221
   and L240. *)
let%expect_test _ =
  let routes = [
    get "/" "/";
    get "/users/top" "users/top";
    get "/users/:id" "users/:id" ~params:["id"];
    route Dream.any "/users/fallback" "any users/fallback";
    get "/spaced users/:id" "spaced users/:id" ~params:["id"];
    get "/files/:user_name/**" "files/:user_name/**" ~params:["user_name"];
    get "/backups/**" "backups/**";
    route Dream.any "/move" "any move";
    get "/**" "**";
  ] in
  List.iter (request routes)
    ["/users/75f6306d-a090-46f9-8b80-80fd57ec9a41"; "/users/hello%20matey";
     "/spaced%20users/hello%20matey"; "/backups/a%20b/c%20d"; "/users/top";
     "/files/elixir/Users/home/file.txt"; "/foo/bar/baz"];
  request routes ~method_:(`Method "MOVE") "/move";
  request routes ~method_:`POST "/users/fallback";
  [%expect {|
    "/users/75f6306d-a090-46f9-8b80-80fd57ec9a41" -> users/:id id="75f6306d-a090-46f9-8b80-80fd57ec9a41"
    "/users/hello%20matey"           -> users/:id id="hello matey"
    "/spaced%20users/hello%20matey"  -> spaced users/:id id="hello matey"
    "/backups/a%20b/c%20d"           -> backups/** path="/a b/c d"
    "/users/top"                     -> users/top
    "/files/elixir/Users/home/file.txt" -> files/:user_name/** user_name="elixir" path="/Users/home/file.txt"
    "/foo/bar/baz"                   -> ** path="/foo/bar/baz"
    "MOVE /move"                     -> any move
    "POST /users/fallback"           -> any users/fallback |}]

(* Origin: anuragsoni/routes test/routing_test.ml, "verify that first parsed
   route matches" (L180) and "route matcher discards query params" (L316). *)
let%expect_test _ =
  request [get "/foo/:x" "foo/:x" ~params:["x"];
           get "/foo/:y" "foo/:y" ~params:["y"]] "/foo/bar";
  let routes = [get "/foo/:x" "foo/:x" ~params:["x"]; get "/" "/"] in
  List.iter (request routes) ["/foo/hello?baz=bar"; "?baz=bar"];
  [%expect {|
    "/foo/bar"                       -> foo/:x x="bar"
    "/foo/hello?baz=bar"             -> foo/:x x="hello"
    "?baz=bar"                       -> / |}]
