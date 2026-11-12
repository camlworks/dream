  $ start_server error
  $ curl_cmd /bad
  <html>
  <body>
    <h1>404 Not Found</h1>
    <pre>404 Not Found
  
  From: Application
  Blame: Client
  Severity: Warning
  
  Client: <client>:<omitted>
  
  GET /bad
  Host: localhost:<omitted>
  User-Agent: <omitted>
  Accept: */*
  
  dream.client: <client>:<omitted>
  dream.tls: false
  dream.request_id: <omitted>
  dream.fd: <omitted></pre>
  </body>
  </html>
  $ curl_cmd /fail
  <html>
  <body>
    <h1>404 Not Found</h1>
    <pre>404 Not Found
  
  From: Application
  Blame: Client
  Severity: Warning
  
  Client: <client>:<omitted>
  
  GET /fail
  Host: localhost:<omitted>
  User-Agent: <omitted>
  Accept: */*
  
  dream.client: <client>:<omitted>
  dream.tls: false
  dream.request_id: <omitted>
  dream.fd: <omitted></pre>
  </body>
  </html>

  $ server_log
                        Running at http://localhost:<omitted>
                        Type Ctrl+C to stop
     dream.logger  INFO REQ 1 GET /bad <client>:<omitted> fd <omitted>
     dream.logger  WARN REQ 1 404 in <omitted> μs
     dream.logger  INFO REQ 2 GET /fail <client>:<omitted> fd <omitted>
     dream.logger  WARN REQ 2 404 in <omitted> μs
