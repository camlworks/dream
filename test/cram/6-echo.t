  $ start_server echo-server
  $ curl_cmd /echo --data "Hello, world!"
  Hello, world!

Dream.run enforces a default 10 MiB request body limit. A body of exactly
10 MiB is accepted:

  $ head -c 10485760 /dev/zero > limit
  $ curl_cmd /echo --data-binary @limit -o /dev/null -w '%{http_code} %{size_download}\n'
  200 10485760

One byte more is rejected with 413, and the connection is closed so that the
client stops sending. With Content-Length, this happens before the handler
reads the body:

  $ head -c 10485761 /dev/zero > over
  $ curl_cmd /echo --data-binary @over -o /dev/null -w '%{http_code} %header{connection}\n'
  413 close

Without Content-Length, the limit is enforced as the handler reads the body:

  $ curl_cmd /echo -H 'Transfer-Encoding: chunked' --data-binary @over -o /dev/null -w '%{http_code} %header{connection}\n'
  413 close

  $ server_log
                        Running at http://localhost:<omitted>
                        Type Ctrl+C to stop
     dream.logger  INFO REQ 1 POST /echo <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 1 200 in <omitted> μs
     dream.logger  INFO REQ 2 POST /echo <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 2 200 in <omitted> μs
     dream.logger  INFO REQ 3 POST /echo <client>:<omitted> fd <omitted>
     dream.logger  WARN REQ 3 Aborted by: Dream__server__Body_size_limit.Payload_too_large
     dream.logger  WARN Raised at Dune__exe__Echo.(fun) in file "example/6-echo/echo.ml", line <omitted>, characters <omitted>
