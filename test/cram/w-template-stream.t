  $ start_server template_stream
  $ until [ -n "$(curl --silent --max-time 1 --retry 0 "localhost:$DREAM_PORT/" 2>/dev/null)" ]; do sleep 0.1; done
  $ curl_cmd / --max-time 2.5 --retry 0 || true
  <html>
  <body>
  
        <p>0</p>
        <p>1</p>
        <p>2</p>

  $ wait_for_log ' 200 in ' 2
  $ server_log
                        Running at http://localhost:<omitted>
                        Type Ctrl+C to stop
     dream.logger  INFO REQ 1 GET / <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 1 200 in <omitted>
     dream.logger  INFO REQ 2 GET / <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 2 200 in <omitted>
