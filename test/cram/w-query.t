  $ start_server query
  $ curl_cmd /
  Use ?echo=foo to give a message to echo!
  $ curl_cmd "/?echo=Hello%2C%20world!"
  Hello, world!
  $ curl_cmd "/?echo=%3Cscript%3E"
  &lt;script&gt;

  $ server_log
                        Running at http://localhost:<omitted>
                        Type Ctrl+C to stop
