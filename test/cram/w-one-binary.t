  $ one_binary &> /dev/null &
  $ curl_cmd /assets/README.md
  The [camel](camel.jpeg) image is taken from [pixabay.com][source]. The license
  states:
  
  > Free for commercial use
  >
  > No attribution required
  
  [source]: https://pixabay.com/photos/morocco-camel-desert-sand-sahara-5271734/
  $ curl_cmd /assets/camel.jpeg -o camel.jpeg
  $ wc -c < camel.jpeg
  61962
  $ curl_cmd /assets/not-a-file -o /dev/null -w '%{http_code}\n'
  404
