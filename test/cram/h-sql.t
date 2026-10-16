  $ sql &> /dev/null &
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
  
