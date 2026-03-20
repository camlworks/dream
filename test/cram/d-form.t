  $ form &> /dev/null &
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
  [1]
  $ curl_cmd / -c cookies -b cookies | sed 's/value=.*/value=<omitted>/'
  <html>
  <body>
  
  
    <form method="POST" action="/">
      <input name="dream.csrf" type="hidden" value=<omitted>
  
      <input name="message" autofocus>
    </form>
  
  </body>
  </html>
  
