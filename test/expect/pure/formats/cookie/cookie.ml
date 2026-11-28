(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2021 Anton Bachin *)



let parse string =
  string
  |> Dream.from_cookie
  |> List.map (fun (name, value) -> Printf.sprintf "%S=%S" name value)
  |> String.concat "; "
  |> Printf.printf "[%s]\n"

let%expect_test _ =
  parse "";
  parse "a";
  parse " a ";
  parse "a=b";
  parse " a = b ";
  parse "a=\"b\""; (* TODO This appears to parse incorrectly w.r.t RFC. *)
  parse "a=b;c=d";
  parse "a=b; c=d";
  parse "a=b ; c=d";
  parse "a=b;c";
  parse "a;c=d";
  [%expect {|
    []
    []
    []
    ["a"="b"]
    ["a"="b"]
    ["a"="\"b\""]
    ["c"="d"; "a"="b"]
    ["c"="d"; "a"="b"]
    ["c"="d"; "a"="b"]
    ["a"="b"]
    ["c"="d"] |}]

let show =
  Printf.printf "%S\n"

let%expect_test _ =
  show @@ Dream.to_set_cookie "a" "b";
  show @@ Dream.to_set_cookie "" "";
  show @@ Dream.to_set_cookie "a" "";
  show @@ Dream.to_set_cookie "" "b";
  show @@ Dream.to_set_cookie "=" "=";
  show @@ Dream.to_set_cookie ";" ";";
  [%expect {|
    "a=b"
    "="
    "a="
    "=b"
    "==="
    ";=;" |}]

let day = 60. *. 60. *. 24.
let month = day *. 30.

let%expect_test _ =
  show @@ Dream.to_set_cookie "a" "b" ~expires:1616431310.;
  show @@ Dream.to_set_cookie "a" "b" ~expires:(1616431310. -. day);
  show @@ Dream.to_set_cookie "a" "b" ~expires:(1616431310. +. day);
  show @@ Dream.to_set_cookie "a" "b" ~expires:(1616431310. +. 2. *. day);
  show @@ Dream.to_set_cookie "a" "b" ~expires:(1616431310. +. 3. *. day);
  show @@ Dream.to_set_cookie "a" "b" ~expires:(1616431310. +. 4. *. day);
  show @@ Dream.to_set_cookie "a" "b" ~expires:(1616431310. +. 5. *. day);
  show @@ Dream.to_set_cookie "a" "b" ~expires:(1616431310. +. 6. *. day);
  show @@ Dream.to_set_cookie "a" "b" ~expires:(1616431310. -. month);
  show @@ Dream.to_set_cookie "a" "b" ~expires:(1616431310. -. 2. *. month);
  show @@ Dream.to_set_cookie "a" "b" ~expires:(1616431310. +. month);
  show @@ Dream.to_set_cookie "a" "b" ~expires:(1616431310. +. 2. *. month);
  show @@ Dream.to_set_cookie "a" "b" ~expires:(1616431310. +. 3. *. month);
  show @@ Dream.to_set_cookie "a" "b" ~expires:(1616431310. +. 4. *. month);
  show @@ Dream.to_set_cookie "a" "b" ~expires:(1616431310. +. 5. *. month);
  show @@ Dream.to_set_cookie "a" "b" ~expires:(1616431310. +. 6. *. month);
  show @@ Dream.to_set_cookie "a" "b" ~expires:(1616431310. +. 7. *. month);
  show @@ Dream.to_set_cookie "a" "b" ~expires:(1616431310. +. 8. *. month);
  show @@ Dream.to_set_cookie "a" "b" ~expires:(1616431310. +. 9. *. month);
  [%expect {|
    "a=b; Expires=Mon, 22 Mar 2021 16:41:50 GMT"
    "a=b; Expires=Sun, 21 Mar 2021 16:41:50 GMT"
    "a=b; Expires=Tue, 23 Mar 2021 16:41:50 GMT"
    "a=b; Expires=Wed, 24 Mar 2021 16:41:50 GMT"
    "a=b; Expires=Thu, 25 Mar 2021 16:41:50 GMT"
    "a=b; Expires=Fri, 26 Mar 2021 16:41:50 GMT"
    "a=b; Expires=Sat, 27 Mar 2021 16:41:50 GMT"
    "a=b; Expires=Sun, 28 Mar 2021 16:41:50 GMT"
    "a=b; Expires=Sat, 20 Feb 2021 16:41:50 GMT"
    "a=b; Expires=Thu, 21 Jan 2021 16:41:50 GMT"
    "a=b; Expires=Wed, 21 Apr 2021 16:41:50 GMT"
    "a=b; Expires=Fri, 21 May 2021 16:41:50 GMT"
    "a=b; Expires=Sun, 20 Jun 2021 16:41:50 GMT"
    "a=b; Expires=Tue, 20 Jul 2021 16:41:50 GMT"
    "a=b; Expires=Thu, 19 Aug 2021 16:41:50 GMT"
    "a=b; Expires=Sat, 18 Sep 2021 16:41:50 GMT"
    "a=b; Expires=Mon, 18 Oct 2021 16:41:50 GMT"
    "a=b; Expires=Wed, 17 Nov 2021 16:41:50 GMT"
    "a=b; Expires=Fri, 17 Dec 2021 16:41:50 GMT" |}]

let%expect_test _ =
  show @@ Dream.to_set_cookie "a" "b" ~max_age:1.;
  show @@ Dream.to_set_cookie "a" "b" ~max_age:42.;
  show @@ Dream.to_set_cookie "a" "b" ~max_age:(-1.);
  show @@ Dream.to_set_cookie "a" "b" ~max_age:0.;
  show @@ Dream.to_set_cookie "a" "b" ~max_age:1.4;
  show @@ Dream.to_set_cookie "a" "b" ~max_age:1.6;
  show @@ Dream.to_set_cookie "a" "b" ~max_age:(-1.4);
  show @@ Dream.to_set_cookie "a" "b" ~max_age:(-1.6);
  [%expect {|
    "a=b; Max-Age=1"
    "a=b; Max-Age=42"
    "a=b; Max-Age=-1"
    "a=b; Max-Age=0"
    "a=b; Max-Age=1"
    "a=b; Max-Age=1"
    "a=b; Max-Age=-2"
    "a=b; Max-Age=-2" |}]

let%expect_test _ =
  show @@ Dream.to_set_cookie "a" "b" ~domain:"abc";
  show @@ Dream.to_set_cookie "a" "b" ~domain:"";
  [%expect {|
    "a=b; Domain=abc"
    "a=b; Domain=" |}]

let%expect_test _ =
  show @@ Dream.to_set_cookie "a" "b" ~path:"abc";
  show @@ Dream.to_set_cookie "a" "b" ~path:"";
  [%expect {|
    "a=b; Path=abc"
    "a=b; Path=" |}]

let%expect_test _ =
  show @@ Dream.to_set_cookie "a" "b" ~secure:true;
  show @@ Dream.to_set_cookie "a" "b" ~http_only:true;
  [%expect {|
    "a=b; Secure"
    "a=b; HttpOnly" |}]

let%expect_test _ =
  show @@ Dream.to_set_cookie "a" "b" ~same_site:`Strict;
  show @@ Dream.to_set_cookie "a" "b" ~same_site:`Lax;
  show @@ Dream.to_set_cookie "a" "b" ~same_site:`None;
  [%expect {|
    "a=b; SameSite=Strict"
    "a=b; SameSite=Lax"
    "a=b; SameSite=None" |}]



(* Cookies are returned in header order, so Dream.cookie returns the first of
   duplicate names, as its documentation says. *)

(* What Dream.cookie returns for [name] when the request carries [header]. *)
let lookup header name =
  let request = Dream.request ~headers:["Cookie", header] "" in
  match Dream.cookie ~decrypt:false request name with
  | None -> print_endline "None"
  | Some value -> Printf.printf "Some %S\n" value

(* Origin: jshttp/cookie src/parse-cookie.spec.ts, "should ignore duplicate
   cookies" (L77-L90), at
   https://github.com/jshttp/cookie/blob/a437ef03993af559900010f62c294647589c29db/src/parse-cookie.spec.ts#L77 *)
let%expect_test _ =
  lookup "foo=%1;bar=bar;foo=boo" "foo";
  lookup "foo=false;bar=bar;foo=true" "foo";
  lookup "foo=;bar=bar;foo=boo" "foo";
  [%expect {|
    Some "boo"
    Some "true"
    Some "boo" |}]
  (* Expected: the first occurrence wins: "%1", "false", "". *)

(* Origin: Werkzeug tests/test_http.py, test_bad_cookies (L410), at
   https://github.com/pallets/werkzeug/blob/0f43c6ebd426039e4b99ec22535c2c8a2ec2f69f/tests/test_http.py#L410 *)
let%expect_test _ =
  parse "first=IamTheFirst ; a=1; oops ; a=2 ;second = andMeTwo;";
  parse "spam=ham; duck=mallard; ; ";
  [%expect {|
    ["second"="andMeTwo"; "a"="2"; "a"="1"; "first"="IamTheFirst"]
    ["duck"="mallard"; "spam"="ham"] |}]
  (* Expected: the pairs in header order. *)
