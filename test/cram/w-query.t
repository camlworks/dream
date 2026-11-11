  $ query &> /dev/null &
  $ curl_cmd /
  Use ?echo=foo to give a message to echo!
  $ curl_cmd "/?echo=Hello%2C%20world!"
  Hello, world!
  $ curl_cmd "/?echo=%3Cscript%3E"
  &lt;script&gt;
