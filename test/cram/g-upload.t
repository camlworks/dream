  $ start_server upload
  $ echo "Hello, world!" > file.txt
Save the cross-site request forgery cookie and set it for the next request
  $ token=$(curl_cmd / -c cookies | sed -n 's/.*value="\([^"]*\)".*/\1/p')
  $ curl_cmd / -b cookies -F "dream.csrf=$token" -F "files=@file.txt"
  <html>
  <body>
        <p>file.txt, 14 bytes</p>
    </body>
  </html>
  

  $ server_log
                        Running at http://localhost:<omitted>
                        Type Ctrl+C to stop
     dream.logger  INFO REQ 1 GET / <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 1 200 in <omitted> μs
     dream.logger  INFO REQ 2 POST / <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 2 200 in <omitted> μs
