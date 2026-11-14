  $ start_server websocket
  $ curl_cmd /
  <html>
  <body>
    <script>
  
    var socket = new WebSocket("ws://" + window.location.host + "/websocket");
  
    socket.onopen = function () {
      socket.send("Hello?");
    };
  
    socket.onmessage = function (e) {
      alert(e.data);
    };
  
    </script>
  </body>
  </html>
  
  $ node websocket_client.js
  Good-bye!

A HEAD request to a WebSocket route is rejected rather than upgraded.
  $ curl_cmd /websocket --head -o /dev/null -w 'HTTP %{http_code}\n'
  HTTP 400

  $ wait_for_log ' 101 in '
  $ server_log
                        Running at http://localhost:<omitted>
                        Type Ctrl+C to stop
     dream.logger  INFO REQ 1 GET / <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 1 200 in <omitted> μs
     dream.logger  INFO REQ 2 GET /websocket <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 2 101 in <omitted> μs
     dream.logger  INFO REQ 3 HEAD /websocket <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 3 101 in <omitted> μs
       dream.http  WARN REQ 3 WebSocket (<client>:<omitted>): Didn't pass scrutiny
