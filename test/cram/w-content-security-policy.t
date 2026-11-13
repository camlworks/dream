  $ start_server content_security_policy
  $ curl_cmd / -i
  HTTP/1.1 200 OK
  Content-Security-Policy: img-src 'none'; report-to csp-endpoint
  Reporting-Endpoints: csp-endpoint="/violation"
  Content-Type: text/html; charset=utf-8
  Content-Length: 58
  
  <html>
  <body>
    <img src="/blocked.png">
  </body>
  </html>
  

  $ server_log
                        Running at http://localhost:<omitted>
                        Type Ctrl+C to stop
     dream.logger  INFO REQ 1 GET / <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 1 200 in <omitted> μs
