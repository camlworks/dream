  $ flash &> /dev/null &
  $ token=$(curl_cmd / -c cookies | sed -n 's/.*value="\([^"]*\)".*/\1/p')
  $ curl_cmd / -b cookies -c cookies --data "dream.csrf=$token&text=Hello!" -o /dev/null
  $ curl_cmd /result -b cookies
  <html>
  <body>
  
        <p>Info: Hello!</p>
  
  </body>
  </html>
  
