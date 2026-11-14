  $ start_server template
  $ curl_cmd /hello-world
  <html>
  <body>
    <h1>The URL parameter was hello-world!</h1>
  </body>
  </html>
  

  $ server_log
                        Running at http://localhost:<omitted>
                        Type Ctrl+C to stop
     dream.logger  INFO REQ 1 GET /hello-world <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 1 200 in <omitted> μs
