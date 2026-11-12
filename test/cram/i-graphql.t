  $ start_server graphql
  $ curl_cmd /graphql -X POST -H "Content-Type: application/json" -H "Origin: http://localhost:$DREAM_PORT" -d '{"query": "{ users { id name } }"}'
  {"data":{"users":[{"id":1,"name":"alice"},{"id":2,"name":"bob"}]}}

  $ server_log
                        Running at http://localhost:<omitted>
                        Type Ctrl+C to stop
     dream.logger  INFO REQ 1 POST /graphql <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 1 200 in <omitted>
