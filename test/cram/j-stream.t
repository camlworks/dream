  $ start_server stream
  $ curl_cmd /echo --data "Hello, world!"
  Hello, world!

  $ server_log
                        Running at http://localhost:<omitted>
                        Type Ctrl+C to stop
     dream.logger  INFO REQ 1 POST /echo <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 1 200 in <omitted> μs
