  $ upload_stream &> /dev/null &
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
  
