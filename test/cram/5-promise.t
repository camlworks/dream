  $ promise &> /dev/null &
  $ curl_cmd /
    0 request(s) successful<br>  0 request(s) failed
  $ curl --no-progress-meter localhost:8080/fail
  $ curl_cmd /
    1 request(s) successful<br>  1 request(s) failed
