# Cram tests guidelines
* Make the example available via the dune file: add the executable to the `(binaries ...)` list of the `(env ...)` stanza, aliasing it with `as` if the basename is not unique, e.g. `(../../example/6-echo/echo.exe as echo-server)`. 
* Add a matching `%{bin:...}` entry to the `(deps ...)` list of the `(cram ...)` stanza.
* Use `curl_cmd` from `common.sh` instead of plain `curl`: it retries until the server is up and normalizes the output.
* Start the server with `start_server <server>` from `common.sh`. This captures
  its output in `server.log` instead of discarding it.
* Assert on the server output with `server_log`, also from `common.sh`. It
  removes timestamps and normalizes other values that vary between runs, such
  as client ports, file descriptors, elapsed times, and user agents. If some
  output is still nondeterministic, filter it in the test itself as in
  `l-https.t`.
