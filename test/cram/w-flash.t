  $ start_server flash
  $ token=$(curl_cmd / -c cookies | sed -n 's/.*value="\([^"]*\)".*/\1/p')
  $ curl_cmd / -b cookies -c cookies --data "dream.csrf=$token&text=Hello!" -o /dev/null
  $ curl_cmd /result -b cookies
  <html>
  <body>
  
        <p>Info: Hello!</p>
  
  </body>
  </html>
  

  $ server_log
                        Running at http://localhost:<omitted>
                        Type Ctrl+C to stop
     dream.logger  INFO REQ 1 GET / <client>:<omitted> fd <omitted>
      dream.flash DEBUG REQ 1 No flash messages.
     dream.logger  INFO REQ 1 200 in <omitted>
     dream.logger  INFO REQ 2 POST / <client>:<omitted> fd <omitted>
      dream.flash DEBUG REQ 2 No flash messages.
     dream.logger  INFO REQ 2 303 /result in <omitted>
     dream.logger  INFO REQ 3 GET /result <client>:<omitted> fd <omitted>
      dream.flash DEBUG REQ 3 Flash messages: Info: Hello!
     dream.logger  INFO REQ 3 200 in <omitted>
