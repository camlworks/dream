<h1 align="center">Dream</h1>

<p align="center">
Easy-to-use, feature-complete Web framework without boilerplate.
</p>

<br>

```ocaml
let hello who =
  <html>
  <body>
    <h1>Hello, <%s who %>!</h1>
  </body>
  </html>

let () =
  Dream.run
  @@ Dream.logger
  @@ Dream.router [
    Dream.get "/" (fun _ -> Dream.html (hello "world"));
  ]
```

<p align="center">
  <a href="#quick-start">Quick Start</a> |
  <a href="https://github.com/camlworks/dream/tree/master/example#readme">
    Tutorial</a> |
  <a href="https://camlworks.github.io/dream/">Reference</a>
  &nbsp;&nbsp;
</p>

<br>
<br>

Dream is **one flat module** in **one package**, documented on
[**one page**][api-main], but with [**many examples**][tutorial]. It offers:

- [**WebSockets**][websocket] and [**GraphQL**][graphql] for your modern Web
  apps.
- [**HTML templates**][templates] with embedded OCaml or
  [Reason][reason-templates] &mdash; use existing skills!
- [**Sessions**][sessions] with pluggable storage [back ends][back-ends].
- Easy [**HTTPS** and **HTTP/2** support][https] &mdash; Dream runs without a
  proxy.
- Helpers for [**secure cookies**][cookies] and
  [**CSRF-safe forms**][forms].
- **Full-stack ML** with clients compiled by [**Melange**][melange] or
  [**js_of_ocaml**][jsoo].

<br>

...all without sacrificing ease of use &mdash; Dream has:

- A simple programming model &mdash; Web apps are [**just functions**][handler]!
- Composable [**middleware**][middleware] and [**routes**][routing].
- Unified, internationalization-friendly [**error handling**][errors].
- [**Cryptography**][crypto] helpers, key rotation, and a chosen cipher.
- A neat [**logger**][logging], and attention to configuring the OCaml runtime
  nicely.
- [**Deployment**][deploy] instructions for **Digital Ocean**, **Heroku**, and
  **Fly.io**, with sample CI scripts.

<br>

Every part of the API is arranged to be easy to understand, use, and remember.
Dream sticks to base OCaml types like `string` and `list`, introducing only a
few [types][types] of its own &mdash; and some of those are just abbreviations
for bare functions!

The neat interface is not a limitation. Everything is still configurable by a
large number of optional arguments, and very loose coupling. Where necessary,
Dream exposes the lower-level machinery that it is composed from. For example,
the basic body and WebSocket readers [return strings][basic-read], but you can
also do [zero-copy streaming][streaming].

You can even run Dream as a [quite bare abstraction][raw] over its [underlying
set of HTTP libraries][vendor], where it acts only as minimal glue code between
their slightly different interfaces.

And, even though Dream is presented as one package for ordinary usage, it is
internally factored into [several sub-libraries][libs], according to the
different dependencies of each, for fast porting to different environments.

Dream is a low-level and unopinionated framework, and you can swap out its
conveniences. For example, you can use TyXML with [server-side JSX][jsx]
instead of Dream's built-in templates. You can bundle assets into a [single
Dream binary][one-binary], or use Dream in a subcommand. Dream tries to be as
functional as possible, touching global runtime state only lazily, when called
into.

[https]: https://github.com/camlworks/dream/tree/master/example/l-https#folders-and-files
[websocket]: https://github.com/camlworks/dream/tree/master/example/k-websocket#folders-and-files
[graphql]: https://github.com/camlworks/dream/tree/master/example/w-graphql-subscription#folders-and-files
[templates]: https://github.com/camlworks/dream/tree/master/example/7-template#folders-and-files
[reason-templates]: https://github.com/camlworks/dream/tree/master/example/r-template#folders-and-files
[middleware]: https://github.com/camlworks/dream/tree/master/example/2-middleware#folders-and-files
[handler]: https://camlworks.github.io/dream/#type-handler
[routing]: https://github.com/camlworks/dream/tree/master/example/3-router#folders-and-files
[cookies]: https://camlworks.github.io/dream/#cookies
[forms]: https://camlworks.github.io/dream/#forms
[sessions]: https://github.com/camlworks/dream/tree/master/example/b-session#folders-and-files
[back-ends]: https://camlworks.github.io/dream/#back-ends
[errors]: https://github.com/camlworks/dream/tree/master/example/9-error#folders-and-files
[crypto]: https://camlworks.github.io/dream/#cryptography
[logging]: https://github.com/camlworks/dream/tree/master/example/2-middleware#folders-and-files
[melange]: https://github.com/camlworks/dream/tree/master/example/r-fullstack-melange#folders-and-files
[jsoo]: https://github.com/camlworks/dream/tree/master/example/w-fullstack-jsoo#folders-and-files
[types]: https://camlworks.github.io/dream/#types
[basic-read]: https://camlworks.github.io/dream/#val-body
[streaming]: https://camlworks.github.io/dream/#streaming
[raw]: https://camlworks.github.io/dream/#builtin
[alpn]: https://en.wikipedia.org/wiki/Application-Layer_Protocol_Negotiation
[libs]: https://github.com/camlworks/dream/tree/master/src
[deploy]: https://github.com/camlworks/dream/tree/master/example#deploying
[jsx]: https://github.com/camlworks/dream/tree/master/example/r-tyxml#folders-and-files
[one-binary]: https://github.com/camlworks/dream/tree/master/example/w-one-binary#folders-and-files

<br>

## Quick start

The easiest way to use Dream is via [opam](https://opam.ocaml.org).
Install it and create a switch if
you don't already have one. Then clone Dream and run the first
[tutorial][tutorial] example, [**`1-hello`**][1-hello]:

```
git clone https://github.com/camlworks/dream.git
cd dream/example/1-hello
opam install . --deps-only
dune exec --root . ./hello.exe
```

`--root .` makes the example directory the Dune project root, so dune builds
only the example against the `dream` package installed by opam, rather than the
Dream source in the surrounding checkout. If you're modifying Dream itself and
want to observe the changes in the examples drop the `--root .`.

## esy

Some examples, such as
[**`w-esy`**](https://github.com/camlworks/dream/tree/master/example/w-esy#folders-and-files),
show how to package a Dream application with [esy](https://esy.sh/).

<br>

## Documentation

- [**Tutorial**][tutorial] &mdash; Threads together the first several examples
  of Dream, touching all the basic topics, including security. See the full list
  and start wherever you like, or begin at [**`1-hello`**][1-hello], the Dream
  version of *Hello, world!*
- [**Reason syntax**][reason-examples] &mdash; Several of the examples are
  written in Reason. See [**`r-hello`**][r-hello].
- [**Full-stack**][fullstack] &mdash; See skeleton projects
  [**`r-fullstack-melange`**][melange] and [**`w-fullstack-jsoo`**][jsoo].
- [**Deploying**][deploying] &mdash; Quick start instructions for
  small-to-medium deployments.
- [**Examples**][examples] &mdash; These cover various HTTP scenarios.
- [**API reference**][api-main]
- [Watching][watch] and [live reloading][reload].

[tutorial]: https://github.com/camlworks/dream/tree/master/example#readme
[examples]: https://github.com/camlworks/dream/tree/master/example#examples
[1-hello]: https://github.com/camlworks/dream/tree/master/example/1-hello#folders-and-files
[r-hello]: https://github.com/camlworks/dream/tree/master/example/r-hello#folders-and-files
[reason-examples]: https://github.com/camlworks/dream/tree/master/example#reason
[deploying]: https://github.com/camlworks/dream/tree/master/example#deploying
[api-main]: https://camlworks.github.io/dream/#types
[fullstack]: https://github.com/camlworks/dream/tree/master/example#full-stack
[watch]: https://github.com/camlworks/dream/tree/master/example/w-watch#folders-and-files
[reload]: https://github.com/camlworks/dream/tree/master/example/w-live-reload#folders-and-files

<br>

## Recommended projects

- [`dream-cli`](https://github.com/tmattio/dream-cli) &nbsp;&mdash;&nbsp;
  command-line interface for Dream applications.
- [`dream-encoding`](https://github.com/tmattio/dream-encoding) &nbsp;&mdash;
  &nbsp; compression middleware.
- [`dream-livereload`](https://github.com/tmattio/dream-livereload)
  &nbsp;&mdash;&nbsp; live reloading.
- [`emile`](https://github.com/dinosaure/emile) &nbsp;&mdash;&nbsp; email
  address syntax validation.
- [`letters`](https://github.com/oxidizing/letters) &nbsp;&mdash;&nbsp; SMTP
  client.

<br>

## Example repositories

- [`dream-mail-example`](https://github.com/jsthomas/dream-email-example)
  &nbsp;&mdash;&nbsp; sends email using RabbitMQ and Mailgun
  [[blog post](https://jsthomas.github.io/ocaml-email.html),
  [discuss](https://discuss.ocaml.org/t/how-to-send-email-from-dream/8201)].
- [`dream-melange-tea-tailwind`](https://github.com/tcoopman/dream-melange-tea-tailwind)
  &nbsp;&mdash;&nbsp; The Elm Architecture with a Dream server, client compiled
  by Melange.

<br>

## Contact

Apart from the [issues](https://github.com/camlworks/dream/issues), good places
to discuss Dream are...

- #dream on the [Reason Discord](https://discord.gg/2JTYRq2rYh).
- #webdev on the [OCaml Discord](https://discord.gg/sx45hPkkWV).
- The [OCaml Discuss forum](https://discuss.ocaml.org/).
- The development stream on [Twitch](https://www.twitch.tv/antron_ML).

Highlight `@antron` to poke @aantron specifically.

<br>

## Contributing

All kinds of contributions are welcome, including examples, links to blogs,
related libraries, and, of course, PRs! See [CONTRIBUTING.md][contributing.md].

[contributing.md]: https://github.com/camlworks/dream/blob/master/docs/CONTRIBUTING.md

<br>

## Acknowledgements

Dream is based on work by the authors and contributors of its [**many
dependencies**][opamfile] and their transitive dependencies. There are, however,
several influences that cannot be discovered directly:

- Templates are inspired by [**ECaml**][ecaml] from [Alexander Markov][komar]
  and [**Embedded OCaml Templates**][eot] from [Emile Trotignon][trotignon].
- Dream's handler and middleware types are simplified from [**Opium**][opium] by
  [Rudi Grinberg][rgrinberg] and contributors.
- The lower-level HTTP and WebSocket servers use
  [Antonio Nuno Monteiro][anmonteiro]'s forks and original works, with credit
  also due to their contributors, and [Spiros Eliopoulos][seliopou] in
  particular, as the original author of the http/af family of projects.
- The API docs are instantiated by [**Soupault**][soupault] from
  [Daniil Baturin][dmbaturin].
- The name was inspired by [**Morph**][morph] from [Ulrik Strid][ulrikstrid],
  which was itself partially inspired by [Opium][opium].
- [Raphael Rafatpanah][persianturtle] and [El-Hassan Wanas][foocraft] provided
  important early feedback.

[ecaml]: http://komar.in/en/code/ecaml
[komar]: https://github.com/apsheronets
[eot]: https://github.com/EmileTrotignon/embedded_ocaml_templates
[trotignon]: https://github.com/EmileTrotignon
[opamfile]: https://github.com/camlworks/dream/blob/master/dream.opam
[opium]: https://github.com/rgrinberg/opium
[vendor]: https://github.com/camlworks/dream/tree/master/src/vendor
[rgrinberg]: https://github.com/rgrinberg
[anmonteiro]: https://github.com/anmonteiro
[soupault]: https://github.com/dmbaturin/soupault
[dmbaturin]: https://github.com/dmbaturin
[morph]: https://github.com/reason-native-web/morph
[ulrikstrid]: https://github.com/ulrikstrid
[seliopou]: https://github.com/seliopou
[persianturtle]: https://github.com/persianturtle
[foocraft]: https://github.com/foocraft
