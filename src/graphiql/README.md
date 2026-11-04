# GraphiQL bundle

Dream serves a vendored build of
[GraphiQL](https://github.com/graphql/graphiql) from `Dream.graphiql`. The
front-end dependencies are pinned in [`package.json`](package.json), and the
resulting single-file page is checked in as [`index.bundle.html`](index.bundle.html).
This is later compiled into `dream__graphiql.ml` by `dune`.

`index.js` is the entry point. It reads the `%%ENDPOINT%%` and `%%DEFAULT_QUERY%%`
placeholders substituted by `src/graphql/graphql.ml`.

## Updating

Change the versions in `package.json` (or run `npm install --save-exact
package@version`). To update the lockfile and rebuild `index.bundle.html` run:

```sh
make update
```
