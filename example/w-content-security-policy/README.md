# `w-content-security-policy`

<br>

The [`Content-Security-Policy`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy)
(CSP) header controls what content your pages are allowed to load. This example
uses [`img-src 'none'`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy/img-src)
to forbid images, and has the browser report each violation back to the server:

```ocaml
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
```

<pre><code><b>$ cd example/w-content-security-policy</b>
<b>$ opam install --deps-only --yes .</b>
<b>$ dune exec --root . ./content_security_policy.exe</b></code></pre>

<br>

Visit [http://localhost:8080](http://localhost:8080) which contains a
single `<img>` pointing at `/blocked.png`. Due to `img-src 'none'`, the browser refuses to load it and posts a violation report to `/violation`. The server log will show
something like

```
ERROR REQ 2 [
 {
  "age": 6,
  "type": "csp-violation",
  "url": "http://localhost:8080/",
  "user_agent": "Mozilla/5.0 (X11; Linux x86_64; rv:157.0) Gecko/20100101 Firefox/157.0",
  "body": {
 "documentURL": "http://localhost:8080/",
 "blockedURL": "http://localhost:8080/blocked.png",
 "referrer": null,
 "effectiveDirective": "img-src",
 "originalPolicy": "img-src 'none'; report-to csp-endpoint",
 "sourceFile": null,
 "sample": null,
 "disposition": "enforce",
 "statusCode": 200,
 "lineNumber": null,
 "columnNumber": null
}
 }
]
```

<br>

You can use CSP to limit which resources can be loaded by the pages you serve,
forbid execution of JavaScript `eval`, and so on. You may want to apply CSP by
writing a wrapper around
[`Dream.html`](https://camlworks.github.io/dream/#val-html), or in a middleware.
Note that static file loaders such as
[`Dream.from_filesystem`](https://camlworks.github.io/dream/#val-from_filesystem)
can also serve HTML pages, so if you choose not to use a middleware and have
static HTML pages, be sure to write a custom static loader as well.

Dream does not offer a default CSP, because it will inevitably interfere with
development, depending on what each Web app is using. Also, it is possible not
to use CSP at all &mdash; CSP is only a defense-in-depth technique. However, it
is highly recommended to eventually look through the CSP directives as your Web
app develops. When enabling CSP, also consider
[`Strict-Transport-Security`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Strict-Transport-Security).

<br>

**See:**

- [`Content-Security-Policy`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy) on MDN
- [`Strict-Transport-Security`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Strict-Transport-Security) on MDN
- [`Report-To` / Reporting API](https://developer.mozilla.org/en-US/docs/Web/API/Reporting_API) on MDN
- OWASP [*Content Security Policy Cheat Sheet*](https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html)
- OWASP [*Clickjacking Defense Cheat Sheet*](https://cheatsheetseries.owasp.org/cheatsheets/Clickjacking_Defense_Cheat_Sheet.html)
- OWASP [*HTTP Strict Transport Security Cheat Sheet*](https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Strict_Transport_Security_Cheat_Sheet.html)

<br>

[Up to the example index](../#examples)
