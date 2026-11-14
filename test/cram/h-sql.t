  $ start_server sql
Get the CSRF-token first
  $ token=$(curl_cmd / -c cookies | sed -n 's/.*value="\([^"]*\)".*/\1/p')
  $ curl_cmd / -b cookies -c cookies --data "dream.csrf=$token&text=Hello from the first test" -o /dev/null
  $ curl_cmd / -b cookies -c cookies --data "dream.csrf=$token&text=Hello from the second test" -o /dev/null
  $ curl_cmd / -b cookies | sed 's/value=.*/value=<omitted>/'
  <html>
  <body>
  
        <p>Hello from the first test</p>
        <p>Hello from the second test</p>
  
    <form method="POST" action="/">
      <input name="dream.csrf" type="hidden" value=<omitted>
  
      <input name="text" autofocus>
    </form>
  
  </body>
  </html>
  

  $ server_log
                        Running at http://localhost:<omitted>
                        Type Ctrl+C to stop
     dream.logger  INFO REQ 1 GET / <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 1 200 in <omitted> μs
     dream.logger  INFO REQ 2 POST / <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 2 303 / in <omitted> μs
     dream.logger  INFO REQ 3 POST / <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 3 303 / in <omitted> μs
     dream.logger  INFO REQ 4 GET / <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 4 200 in <omitted> μs
