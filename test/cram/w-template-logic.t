  $ template-logic &> /dev/null &
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
  
