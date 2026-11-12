  $ start_server upload_stream
  $ echo "Hello, world!" > file.txt
Save the session cookie and scrape the CSRF token from the form
  $ token=$(curl_cmd / -c cookies | sed -n 's/.*value="\([^"]*\)".*/\1/p')
  $ curl_cmd / -b cookies -F "dream.csrf=$token" -F "files=@file.txt"
  <html>
  <body>
        <p>None, 108 bytes</p>
        <p>file.txt, 14 bytes</p>
    </body>
  </html>
  

  $ server_log
                        Running at http://localhost:<omitted>
                        Type Ctrl+C to stop
     dream.logger  INFO REQ 1 GET / <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 1 200 in <omitted>
     dream.logger  INFO REQ 2 POST / <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 2 200 in <omitted>
