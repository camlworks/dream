  $ start_server session
  $ curl_cmd / -c cookie
  You weren't logged in; but now you are!
  $ curl_cmd / -b cookie
  Welcome back, alice!
