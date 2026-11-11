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
