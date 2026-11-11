let home =
  <html>
  <body>
    <img src="/blocked.png">
  </body>
  </html>

let () =
  Dream.run
  @@ Dream.logger
  @@ Dream.router [

    Dream.get "/" (fun _ ->
      Dream.html
        ~headers:[
          "Content-Security-Policy",
            "img-src 'none'; " ^
            "report-to csp-endpoint";
          "Reporting-Endpoints", "csp-endpoint=\"/violation\""]
        home);

    Dream.get "/blocked.png" (fun _ ->
        Dream.html
          "You should not be able to see this!");

    Dream.post "/violation" (fun request ->
      let%lwt report = Dream.body request in
      Dream.error (fun log -> log "%s" report);
      Dream.empty `OK);

  ]
