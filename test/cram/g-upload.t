  $ upload &> /dev/null &
  $ echo "Hello, world!" > file.txt
Save the cross-site request forgery cookie and set it for the next request
  $ token=$(curl_cmd / -c cookies | sed -n 's/.*value="\([^"]*\)".*/\1/p')
  $ curl_cmd / -b cookies -F "dream.csrf=$token" -F "files=@file.txt"
  <html>
  <body>
        <p>file.txt, 14 bytes</p>
    </body>
  </html>
  
