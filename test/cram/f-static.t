  $ mkdir testdata
  $ echo "Hello" > hello
  $ echo "World" > testdata/world
  $ static &> /dev/null &
  $ curl_cmd /static/hello
  Hello
  $ curl_cmd /static/testdata/world
  World

The response carries cache validators: a content-derived ETag and a
Last-Modified date (normalized here, since it reflects the file's mtime).
  $ curl_cmd /static/hello -D - -o /dev/null \
  >   | grep -iE '^(etag|last-modified):' \
  >   | sed -E 's/(last-modified:) .*/\1 <date>/I'
  ETag: "1d229271928d3f9e2bb0375bd6ce5db6c6d348d9"
  Last-Modified: <date>

A conditional request whose If-None-Match matches the current ETag is answered
with 304 Not Modified and no body.
  $ curl_cmd /static/hello \
  >   -H 'If-None-Match: "1d229271928d3f9e2bb0375bd6ce5db6c6d348d9"' \
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
