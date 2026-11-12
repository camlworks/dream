  $ start_server session
  $ curl_cmd / -c cookie
  You weren't logged in; but now you are!
  $ curl_cmd / -b cookie
  Welcome back, alice!

  $ server_log
                        Running at http://localhost:<omitted>
                        Type Ctrl+C to stop
     dream.logger  INFO REQ 1 GET / <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 1 200 in <omitted>
     dream.logger  INFO REQ 2 GET / <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 2 200 in <omitted>
