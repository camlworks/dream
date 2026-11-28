(* This file is part of Dream, released under the MIT license. See LICENSE.md
   for details, or visit https://github.com/camlworks/dream.

   Copyright 2021 Anton Bachin *)



(* HTML escaping vectors adapted from the round-trip strings of Go's
   src/html/escape_test.go, TestUnescapeEscape (BSD-3-Clause):
   https://github.com/golang/go/blob/5e9534e62225b2f58f3b4b3d410e63f29f6566f5/src/html/escape_test.go
   Go escapes the same five characters, with different entities. Each test
   starts with an "Origin:" comment naming the upstream test and line it comes
   from, or saying that it was added for Dream. *)



let escape s =
  Printf.printf "%S\n" (Dream.html_escape s)

(* Origin: Go html/escape_test.go, TestUnescapeEscape (L101-L111). *)
let%expect_test _ =
  escape "";
  escape "abc def";
  escape "a & b";
  escape "a&amp;b";
  escape "a &amp b";
  escape "&quot;";
  escape "\"";
  escape "\"<&>\"";
  escape "&quot;&lt;&amp;&gt;&quot;";
  escape "3&5==1 && 0<1, \"0&lt;1\", a+acute=&aacute;";
  escape "The special characters are: <, >, &, ' and \"";
  [%expect {|
    ""
    "abc def"
    "a &amp; b"
    "a&amp;amp;b"
    "a &amp;amp b"
    "&amp;quot;"
    "&quot;"
    "&quot;&lt;&amp;&gt;&quot;"
    "&amp;quot;&amp;lt;&amp;amp;&amp;gt;&amp;quot;"
    "3&amp;5==1 &amp;&amp; 0&lt;1, &quot;0&amp;lt;1&quot;, a+acute=&amp;aacute;"
    "The special characters are: &lt;, &gt;, &amp;, &#x27; and &quot;" |}]

(* Origin: not from an upstream suite; added for Dream. The OWASP XSS
   prevention cheat sheet also suggests escaping '/'. *)
let%expect_test _ =
  escape "`/\000";
  [%expect {| "`/\000" |}]
