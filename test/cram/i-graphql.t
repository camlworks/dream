  $ graphql &> /dev/null &
  $ curl_cmd /graphql -X POST -H "Content-Type: application/json" -H "Origin: http://localhost:$DREAM_PORT" -d '{"query": "{ users { id name } }"}'
  {"data":{"users":[{"id":1,"name":"alice"},{"id":2,"name":"bob"}]}}
