  $ multipart_dump &> /dev/null &
  $ curl_cmd / | sed 's/value=.*/value=<omitted>/'
  <html>
  <body>
    <form method="POST" action="/" enctype="multipart/form-data">
      <input name="dream.csrf" type="hidden" value=<omitted>
  
      <input name="text"><br>
      <input name="files" type="file" multiple><br>
      <button>Submit!</button>
    </form>
  </body>
  </html>
  
curl picks a random boundary, so replace it with <boundary omitted> and strip the CRLF line endings:
  $ curl_cmd / -F 'field=field-value' | sed -E 's/^-{2,}[A-Za-z0-9]+/--<boundary omitted>/; s/\r$//'
  --<boundary omitted>
  Content-Disposition: form-data; name="field"
  
  field-value
  --<boundary omitted>--
  $ printf 'file-content' > file.txt
  $ curl_cmd / -F 'file=@file.txt' | sed -E 's/^-{2,}[A-Za-z0-9]+/--<boundary omitted>/; s/\r$//'
  --<boundary omitted>
  Content-Disposition: form-data; name="file"; filename="file.txt"
  Content-Type: text/plain
  
  file-content
  --<boundary omitted>--
