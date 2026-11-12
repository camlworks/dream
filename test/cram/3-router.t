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

  $ server_log
                        Running at http://localhost:<omitted>
                        Type Ctrl+C to stop
     dream.logger  INFO REQ 1 GET /echo/hello-world <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 1 200 in <omitted> μs
     dream.logger  INFO REQ 2 GET //echo/hello-world <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 2 200 in <omitted> μs
     dream.logger  INFO REQ 3 GET http://localhost:<omitted>/echo/hello-world <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 3 200 in <omitted> μs
