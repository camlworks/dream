  $ start_server one_binary
  $ curl_cmd /assets/README.md
  The [camel](camel.jpeg) image is taken from [pixabay.com][source]. The license
  states:
  
  > Free for commercial use
  >
  > No attribution required
  
  [source]: https://pixabay.com/photos/morocco-camel-desert-sand-sahara-5271734/
  $ curl_cmd /assets/camel.jpeg -o camel.jpeg
  $ wc -c < camel.jpeg | tr -d '[:space:]'
  61962
  $ curl_cmd /assets/not-a-file -o /dev/null -w '%{http_code}\n'
  404

  $ server_log
                        Running at http://localhost:<omitted>
                        Type Ctrl+C to stop
     dream.logger  INFO REQ 1 GET /assets/README.md <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 1 200 in <omitted> μs
     dream.logger  INFO REQ 2 GET /assets/camel.jpeg <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 2 200 in <omitted> μs
     dream.logger  INFO REQ 3 GET /assets/not-a-file <client>:<omitted> fd <omitted>
     dream.logger  WARN REQ 3 404 in <omitted> μs
