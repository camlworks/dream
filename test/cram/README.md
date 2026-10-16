# Cram tests guidelines
* Make the example available via the dune file: add the executable to the `(binaries ...)` list of the `(env ...)` stanza, aliasing it with `as` if the basename is not unique, e.g. `(../../example/6-echo/echo.exe as echo-server)`. 
* Add a matching `%{bin:...}` entry to the `(deps ...)` list of the `(cram ...)` stanza.
* Use `curl_cmd` from `common.sh` instead of plain `curl`: it retries until the server is up and normalizes the output.
* Pipe the output of the server to `/dev/null` (`server &> /dev/null &`) as it includes timestamps.
