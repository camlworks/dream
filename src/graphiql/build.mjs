// Builds the single-file GraphiQL page vendored by Dream. The page embeds
// GraphiQL, React, and the Monaco workers, so Dream does not have to serve
// any additional assets. Run `npm run build` after changing index.js or a
// dependency.

import {mkdtemp, readFile, rm, writeFile} from "node:fs/promises";
import {fileURLToPath} from "node:url";
import {tmpdir} from "node:os";
import path from "node:path";
import {build} from "esbuild";
import {inlineSource} from "inline-source";

const directory = path.dirname(fileURLToPath(import.meta.url));
const workerEntries = {
  editor: "monaco-editor/editor/editor.worker.js",
  json: "monaco-editor/language/json/json.worker.js",
  graphql: "monaco-graphql/esm/graphql.worker",
};

const common = {
  absWorkingDir: directory,
  bundle: true,
  minify: true,
  format: "iife",
  platform: "browser",
  target: ["es2020"],
  legalComments: "eof",
  logLevel: "warning",
};

const emit = async options => {
  const result = await build({...common, ...options, write: false});
  return Object.fromEntries(
    result.outputFiles.map(output => [path.extname(output.path), output.text])
  );
};

const main = await emit({
  entryPoints: ["index.js"],
  outdir: ".",
  entryNames: "index.bundle",
  loader: {
    ".ttf": "dataurl",
    ".woff": "dataurl",
    ".woff2": "dataurl",
    ".svg": "dataurl",
  },
  define: {"process.env.NODE_ENV": '"production"'},
});

if (!main[".js"] || !main[".css"]) {
  throw new Error("esbuild did not produce the GraphiQL script and styles");
}

const workers = {};

for (const [name, entryPoint] of Object.entries(workerEntries)) {
  const output = await emit({entryPoints: [entryPoint], outfile: `${name}.worker.js`});
  if (!output[".js"]) throw new Error(`esbuild did not produce ${name}`);
  workers[name] = output[".js"];
}

const workerSetup = `(${function setupMonacoWorkers(sources) {
  const urls = {};
  for (const [name, source] of Object.entries(sources)) {
    const blob = new Blob([source], {type: "text/javascript"});
    urls[name] = URL.createObjectURL(blob);
  }
  globalThis.MonacoEnvironment = {
    getWorker(_workerId, label) {
      return new Worker(urls[label] || urls.editor);
    },
  };
}.toString()})(${JSON.stringify(workers).replace(/</g, "\\u003c")});`;

const buildDirectory = await mkdtemp(path.join(tmpdir(), "dream-graphiql-"));

try {
  await writeFile(`${buildDirectory}/index.bundle.js`, `${workerSetup}\n${main[".js"]}`);
  await writeFile(`${buildDirectory}/index.bundle.css`, main[".css"]);

  const html = await readFile(path.join(directory, "index.html"), "utf8");
  const bundle = await inlineSource(html, {
    compress: false,
    rootpath: buildDirectory,
  });

  await writeFile(path.join(directory, "index.bundle.html"), bundle);
} finally {
  await rm(buildDirectory, {recursive: true, force: true});
}
