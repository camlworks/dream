  $ https &> /dev/null &
  $ curl --silent --retry 2 --retry-connrefused "https://localhost:$DREAM_PORT/" -k
  Good morning, world!
  $ curl --silent --retry 2 --retry-connrefused "https://localhost:$DREAM_PORT/" -w '%{http_code}' -o /dev/null
  000
  [60]
