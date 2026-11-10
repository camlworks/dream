  $ websocket &> /dev/null &
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
