  $ start_server counter
  $ curl_cmd /
  Responding to the 1. request!
  $ curl_cmd /
  Responding to the 2. request!

  $ server_log
                        Running at http://localhost:<omitted>
                        Type Ctrl+C to stop
     dream.logger  INFO REQ 1 GET / <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 1 200 in <omitted>
     dream.logger  INFO REQ 2 GET / <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 2 200 in <omitted>
