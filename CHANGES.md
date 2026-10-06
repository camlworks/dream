# 1.0.0

This release brings support for OCaml 5.5 and marks the completed transition to the camlworks organization and, with it, more active maintenance. 1.0.0 does not mean that Dream is feature complete or bug free, only that we use semantic versioning from now on. Stay tuned for more regular releases in the future!

Additions and improvements:
- Require an initialization call for `Dream.memory_sessions`. Fix `Dream.memory_sessions` when combined with `Dream.scope` (@boechat107, #385)
- Shut down server on SIGTERM/SIGINT even when running in docker (@yawaramin, #406)
- Clean up socket file before binding to it if started as Unix socket server (@yawaramin, #407)
- Add `post_connect` option to `sql_pool` (@gahr, #422)
- Suppress EML template detection inside OCaml comments (@MavenRain, #431)

Miscellaneous:
- Move project to new camlworks organization (#417)
- Update dependencies and support OCaml 5.5 (@lthms, @bensmrs, #381, #415, #434, #439)
- Support latest Mirage version (@boechat107, @hannesm, #383, #393, #395)
- Improve documentation (@aantron, @sabine, @yawaramin, @funwithcthulhu, @blendux, #372, #391, #403, #404, #423, #433)
- Improve examples (@asymmetric, @mostafatouny, @yotamN, @yawaramin, #366, #370, #379, #380, #386, #405)
- CI fixes (#416, #418, #435)
