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
