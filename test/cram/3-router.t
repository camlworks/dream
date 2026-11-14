  $ start_server router
  $ curl_cmd /echo/hello-world
  hello-world

A target starting with // is origin-form: the // belongs to the path, not to
an authority. This routes as /echo/hello-world.
  $ curl_cmd /echo/hello-world --request-target '//echo/hello-world' -w '\nHTTP %{http_code}\n'
  hello-world
  HTTP 200

Absolute-form request targets are valid for HTTP/1.1 origin servers and must
route like their origin-form equivalents.
  $ curl_cmd /echo/hello-world --request-target "http://localhost:$DREAM_PORT/echo/hello-world" -w '\nHTTP %{http_code}\n'
  hello-world
  HTTP 200

A HEAD request with no HEAD route is answered by the matching GET route: same
status and Content-Length (11, the length of "hello-world"), but no body.
  $ curl_cmd /echo/hello-world --head -o /dev/null -w 'HTTP %{http_code} body=%{size_download} content-length=%header{content-length}\n'
  HTTP 200 body=0 content-length=11

  $ server_log
                        Running at http://localhost:<omitted>
                        Type Ctrl+C to stop
     dream.logger  INFO REQ 1 GET /echo/hello-world <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 1 200 in <omitted> μs
     dream.logger  INFO REQ 2 GET //echo/hello-world <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 2 200 in <omitted> μs
     dream.logger  INFO REQ 3 GET http://localhost:<omitted>/echo/hello-world <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 3 200 in <omitted> μs
     dream.logger  INFO REQ 4 HEAD /echo/hello-world <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 4 200 in <omitted> μs
