# GraphiQL page

Dream serves [GraphiQL](https://github.com/graphql/graphiql) from
`Dream.graphiql` using a small HTML shell adapted from the
[upstream GraphiQL CDN example](https://github.com/graphql/graphiql/tree/main/examples/graphiql-cdn).
GraphiQL, React, and their dependencies are loaded from
[esm.sh](https://esm.sh) at runtime.

The import map follows the upstream generator's package layout and current
versions, with these Dream-specific changes:

- `graphql-ws` is added for subscriptions.
- `scheduler` is pinned explicitly for `react-dom`.
- Monaco workers are imported directly at exact `monaco-editor` and
  `monaco-graphql` versions instead of using `graphiql/setup-workers/esm.sh`.

The import map pins exact versions for the top-level modules and includes
Subresource Integrity hashes for esm.sh's entry stubs and the stylesheet. Those
hashes do **not** cover the modules that the stubs import: esm.sh resolves and
serves the transitive dependency graph at load time, and some dependencies are
selected using version ranges. Serving GraphiQL therefore trusts esm.sh to
provide the expected front end.

The Monaco worker entry points are imported directly from exact
`monaco-editor` and `monaco-graphql` versions, but they and the worker scripts
they load are not covered by the import-map SRI hashes either.

`index.html` contains the `%%ENDPOINT%%`, `%%DEFAULT_QUERY%%`, and
`%%SERVER_ID%%` placeholders substituted by `src/graphql/graphql.ml`.

## Updating

Update the URLs, worker versions, and integrity hashes together. Keep the import
map aligned with the upstream CDN example and its generator, preserving the
Dream-specific changes listed above. When changing the stylesheet URL, update
its SRI hash as well.
