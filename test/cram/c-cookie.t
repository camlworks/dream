  $ start_server cookie
The cookie is encrypted so we cannot have set it ourselves
  $ curl_cmd / -c cookie
  Set language preference; come again!
  $ curl_cmd / -b cookie
  Your preferred language is ut-OP!

  $ server_log
                        Running at http://localhost:<omitted>
                        Type Ctrl+C to stop
     dream.logger  INFO REQ 1 GET / <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 1 200 in <omitted>
     dream.logger  INFO REQ 2 GET / <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 2 200 in <omitted>
