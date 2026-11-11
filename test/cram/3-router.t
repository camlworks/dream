  $ router &> /dev/null &
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
