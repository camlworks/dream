  $ start_server json
  $ curl_cmd / -X POST -H "Content-Type: application/json" -H "Origin: http://localhost:$DREAM_PORT" -d '{"message": "Hello"}'
  "Hello"

  $ server_log
                        Running at http://localhost:<omitted>
                        Type Ctrl+C to stop
     dream.logger  INFO REQ 1 POST / <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 1 200 in <omitted>
