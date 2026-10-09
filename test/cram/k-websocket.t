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
  
  $ printf 'Hello?' | curl --silent --no-progress-meter --max-time 2 -N -T - ws://localhost:$DREAM_PORT/websocket | tr -cd '[:print:]'; echo
  Good-bye!
