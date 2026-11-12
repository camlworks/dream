  $ start_server template-logic
  $ curl_cmd /
  <html>
  <body>
        <p>Task <a href="/Write documentation">Write documentation</a>:
            complete!
        </p>
        <p>Task <a href="/Create examples">Create examples</a>:
            complete!
        </p>
        <p>Task <a href="/Publish website">Publish website</a>:
            complete!
        </p>
        <p>Task <a href="/Profit">Profit</a>:
            not complete.
        </p>
    </body>
  </html>
  
  $ curl_cmd /Profit
  <html>
  <body>
        <p>Task: Profit</p>
      <p>Complete: false</p>
    </body>
  </html>
  
  $ curl_cmd /Nope
  <html>
  <body>
        <p>Task not found!</p>
    </body>
  </html>
  

  $ server_log
                        Running at http://localhost:<omitted>
                        Type Ctrl+C to stop
     dream.logger  INFO REQ 1 GET / <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 1 200 in <omitted> μs
     dream.logger  INFO REQ 2 GET /Profit <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 2 200 in <omitted> μs
     dream.logger  INFO REQ 3 GET /Nope <client>:<omitted> fd <omitted>
     dream.logger  INFO REQ 3 200 in <omitted> μs
