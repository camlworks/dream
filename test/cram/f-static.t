  $ mkdir testdata
  $ echo "Hello" > hello
  $ echo "World" > testdata/world
  $ start_server static
  $ curl_cmd /static/hello
  Hello
  $ curl_cmd /static/testdata/world
  World

The response carries cache validators: a content-derived ETag and a
Last-Modified date (normalized here, since it reflects the file's mtime).
  $ curl_cmd /static/hello -D - -o /dev/null \
  >   | grep -iE '^(etag|last-modified):' \
  >   | sed -E 's/(last-modified:) .*/\1 <date>/I'
  ETag: "66a045b452102c59d840ec097d59d9467e13a3f34f6494e539ffd32c1bb35f18"
  Last-Modified: <date>

A conditional request whose If-None-Match matches the current ETag is answered
with 304 Not Modified and no body.
  $ curl_cmd /static/hello \
  >   -H 'If-None-Match: "66a045b452102c59d840ec097d59d9467e13a3f34f6494e539ffd32c1bb35f18"' \
  >   -w 'HTTP %{http_code}\n'
  HTTP 304

A stale If-None-Match still gets the full 200 response with the body.
  $ curl_cmd /static/hello -H 'If-None-Match: "stale"' -w 'HTTP %{http_code}\n'
  Hello
  HTTP 200

With no If-None-Match, an If-Modified-Since equal to the file's Last-Modified is
answered 304 (date captured from the response, as it reflects the file's mtime).
  $ LM=$(curl_cmd /static/hello -D - -o /dev/null \
  >   | grep -i '^last-modified:' | sed 's/^[Ll]ast-[Mm]odified: //' | tr -d '\r')
  $ curl_cmd /static/hello -H "If-Modified-Since: $LM" -w 'HTTP %{http_code}\n'
  HTTP 304

An older If-Modified-Since serves the full 200 response.
  $ curl_cmd /static/hello \
  >   -H 'If-Modified-Since: Wed, 01 Jan 2020 00:00:00 GMT' -w 'HTTP %{http_code}\n'
  Hello
  HTTP 200

  $ server_log
                        Running at http://localhost:<omitted>
                        Type Ctrl+C to stop
     dream.logger  INFO REQ 1 GET /static/hello <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 1 200 in <omitted> μs
     dream.logger  INFO REQ 2 GET /static/testdata/world <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 2 200 in <omitted> μs
     dream.logger  INFO REQ 3 GET /static/hello <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 3 200 in <omitted> μs
     dream.logger  INFO REQ 4 GET /static/hello <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 4 304 in <omitted> μs
     dream.logger  INFO REQ 5 GET /static/hello <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 5 200 in <omitted> μs
     dream.logger  INFO REQ 6 GET /static/hello <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 6 200 in <omitted> μs
     dream.logger  INFO REQ 7 GET /static/hello <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 7 304 in <omitted> μs
     dream.logger  INFO REQ 8 GET /static/hello <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 8 200 in <omitted> μs
