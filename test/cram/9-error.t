  $ error &> /dev/null &
  $ curl_cmd /bad | sed 's/::1:.*/::1:<omitted>/' | sed 's/dream.request_id: [^<]*/dream.request_id: <omitted>/'
  <html>
  <body>
    <h1>404 Not Found</h1>
    <pre>404 Not Found
  
  From: Application
  Blame: Client
  Severity: Warning
  
  Client: ::1:<omitted>
  
  GET /bad
  Host: localhost:8080
  Accept: */*
  
  dream.client: ::1:<omitted>
  dream.tls: false
  dream.request_id: <omitted>
  dream.fd: 6</pre>
  </body>
  </html>
  $ curl_cmd /fail | sed 's/::1:.*/::1:<omitted>/' | sed 's/dream.request_id: [^<]*/dream.request_id: <omitted>/'
  <html>
  <body>
    <h1>404 Not Found</h1>
    <pre>404 Not Found
  
  From: Application
  Blame: Client
  Severity: Warning
  
  Client: ::1:<omitted>
  
  GET /fail
  Host: localhost:8080
  Accept: */*
  
  dream.client: ::1:<omitted>
  dream.tls: false
  dream.request_id: <omitted>
  dream.fd: 6</pre>
  </body>
  </html>
