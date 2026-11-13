  $ start_server log
  $ curl_cmd /
  Good morning, world!
  $ curl_cmd /fail

  $ server_log
                        Running at http://localhost:<omitted>
                        Type Ctrl+C to stop
     dream.logger  INFO REQ 1 GET / <client>:<omitted> fd <omitted>
                        REQ 1 Sending greeting to <client>:<omitted>!
     dream.logger  INFO REQ 1 200 in <omitted> μs
     dream.logger  INFO REQ 2 GET /fail <client>:<omitted> fd <omitted>
                   WARN REQ 2 Raising an exception!
     dream.logger  WARN REQ 2 Aborted by: Failure("The Web app failed!")
     dream.logger  WARN Raised at Dune__exe__Log.(fun) in file "example/a-log/log.ml", line <omitted>, characters <omitted>
     dream.logger  WARN Called from Lwt.Sequence_associated_storage.with_value in file "src/core/lwt.ml", line <omitted>, characters <omitted>
     dream.logger  WARN Re-raised at Lwt.Sequence_associated_storage.with_value in file "src/core/lwt.ml", line <omitted>, characters <omitted>
     dream.logger  WARN Called from Lwt.Sequential_composition.try_bind in file "src/core/lwt.ml", line <omitted>, characters <omitted>
       dream.http ERROR REQ 2 Failure("The Web app failed!")
       dream.http ERROR REQ 2 Raised at Stdlib__Map.Make.find in file "map.ml", line <omitted>, characters <omitted>
       dream.http ERROR REQ 2 Called from Logs.Tag.find in file "src/logs.ml", line <omitted>, characters <omitted>
