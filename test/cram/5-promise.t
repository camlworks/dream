  $ start_server promise
  $ curl_cmd /
    0 request(s) successful<br>  0 request(s) failed
  $ curl --no-progress-meter localhost:$DREAM_PORT/fail
  $ curl_cmd /
    1 request(s) successful<br>  1 request(s) failed

  $ server_log
                        Running at http://localhost:<omitted>
                        Type Ctrl+C to stop
     dream.logger  INFO REQ 1 GET / <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 1 200 in <omitted> μs
     dream.logger  INFO REQ 2 GET /fail <client>:<omitted> fd <omitted>
     dream.logger  WARN REQ 2 Aborted by: Failure("The Web app failed!")
     dream.logger  WARN Raised at Dune__exe__Promise.count_requests.(fun) in file "example/5-promise/promise.ml", line <omitted>, characters <omitted>
     dream.logger  WARN Called from Lwt.Sequence_associated_storage.with_value in file "src/core/lwt.ml", line <omitted>, characters <omitted>
     dream.logger  WARN Re-raised at Lwt.Sequence_associated_storage.with_value in file "src/core/lwt.ml", line <omitted>, characters <omitted>
     dream.logger  WARN Called from Lwt.Sequential_composition.try_bind in file "src/core/lwt.ml", line <omitted>, characters <omitted>
       dream.http ERROR REQ 2 Failure("The Web app failed!")
       dream.http ERROR REQ 2 Raised at Stdlib__Map.Make.find in file "map.ml", line <omitted>, characters <omitted>
       dream.http ERROR REQ 2 Called from Logs.Tag.find in file "src/logs.ml", line <omitted>, characters <omitted>
     dream.logger  INFO REQ 3 GET / <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 3 200 in <omitted> μs
