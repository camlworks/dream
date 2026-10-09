  $ json &> /dev/null &
  $ curl_cmd / -X POST -H "Content-Type: application/json" -H "Origin: http://localhost:$DREAM_PORT" -d '{"message": "Hello"}'
  "Hello"
