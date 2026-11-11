  $ template_stream &> /dev/null &
  $ until [ -n "$(curl --silent --max-time 1 --retry 0 "localhost:$DREAM_PORT/" 2>/dev/null)" ]; do sleep 0.1; done
  $ curl_cmd / --max-time 2.5 --retry 0 || true
  <html>
  <body>
  
        <p>0</p>
        <p>1</p>
        <p>2</p>
