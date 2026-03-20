  $ mkdir testdata
  $ echo "Hello" > hello
  $ echo "World" > testdata/world
  $ static &> /dev/null &
  $ curl_cmd /static/hello
  Hello
  $ curl_cmd /static/testdata/world
  World
