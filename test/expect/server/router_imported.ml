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
   "/r" are redirected to "/r/". The 405 is a decision recorded in
   src/server/router.ml. The redirects need no action: Dream treats "/r" and
   "/r/" as different routes (see Dream.router), and Dream.trailing_slash
   offers redirects. *)
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

(* Origin: httprouter router_test.go, TestRouterNotFound (L409-L430).
   Upstream: each request but "/nope" is redirected (301): trailing slash,
   case, or path cleaning. Trailing slashes and case need no action: Dream
   matches both strictly, by design (see Dream.router). Path cleaning is a
   decision recorded in src/server/router.ml. *)
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

(* Origin: pillarjs/router test/route.js, L694-L712. *)
let%expect_test _ =
  request [get "/:foo" ":foo" ~params:["foo"]] "/bar/bar";
  request [get "/:foo/:bar" ":foo/:bar" ~params:["foo"; "bar"]] "/fizz/buzz";
  [%expect {|
    "/bar/bar"                       -> 404
    "/fizz/buzz"                     -> :foo/:bar foo="fizz" bar="buzz" |}]

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
