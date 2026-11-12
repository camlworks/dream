  $ start_server https
  $ curl --silent --retry 2 --retry-connrefused "https://localhost:$DREAM_PORT/" -k
  Good morning, world!
  $ curl --silent --retry 2 --retry-connrefused "https://localhost:$DREAM_PORT/" -w '%{http_code}' -o /dev/null
  000
  [60]

Over HTTP/2, a body over the default 10 MiB limit gets a complete 413 response,
not a stream error, so curl exits successfully:

  $ head -c 10485761 /dev/zero > over
  $ curl --silent --show-error --http2 -k "https://localhost:$DREAM_PORT/" --data-binary @over -o /dev/null -w '%{http_code} %{http_version}\n'
  413 2

  $ server_log | grep -v dream.http
                        Running at https://localhost:<omitted>
                        Type Ctrl+C to stop
     dream.logger  INFO REQ 1 GET / <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 1 200 in <omitted>
