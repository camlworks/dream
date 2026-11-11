  $ content_security_policy &> /dev/null &
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
  
