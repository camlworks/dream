  $ start_server form
  $ curl_cmd / -c cookies -b cookies | sed 's/value=.*/value=<omitted>/'
  <html>
  <body>
  
  
    <form method="POST" action="/">
      <input name="dream.csrf" type="hidden" value=<omitted>
  
      <input name="message" autofocus>
    </form>
  
  </body>
  </html>
  
  $ curl_cmd / -X POST
  $ curl_cmd / -c cookies -b cookies | sed 's/value=.*/value=<omitted>/'
  <html>
  <body>
  
  
    <form method="POST" action="/">
      <input name="dream.csrf" type="hidden" value=<omitted>
  
      <input name="message" autofocus>
    </form>
  
  </body>
  </html>
  

  $ server_log
                        Running at http://localhost:<omitted>
                        Type Ctrl+C to stop
     dream.logger  INFO REQ 1 GET / <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 1 200 in <omitted>
     dream.logger  INFO REQ 2 POST / <client>:<omitted> fd <omitted>
       dream.form  WARN REQ 2 Content-Type not 'application/x-www-form-urlencoded'
     dream.logger  WARN REQ 2 400 in <omitted>
     dream.logger  INFO REQ 3 GET / <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 3 200 in <omitted>
