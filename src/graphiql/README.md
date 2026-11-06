# GraphiQL page

Dream serves [GraphiQL](https://github.com/graphql/graphiql) from
`Dream.graphiql` using a small HTML shell. GraphiQL, React, and their
dependencies are loaded from [esm.sh](https://esm.sh) at runtime. The import map
in [`index.html`](index.html) pins exact versions and includes Subresource
Integrity hashes for every module and stylesheet.

`index.html` contains the `%%ENDPOINT%%` and `%%DEFAULT_QUERY%%` placeholders
substituted by `src/graphql/graphql.ml`.

## Updating

Update the URLs and integrity hashes together. The import map follows the
[upstream GraphiQL CDN example](https://github.com/graphql/graphiql/tree/main/examples/graphiql-cdn).
Changing a URL without changing its SRI hash makes the browser reject the
module.
