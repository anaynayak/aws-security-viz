# Vendored dagre

Inlined into the self-contained `.html` output (see `Renderer::Html`) so the viewer needs no CDN and works from `file://`.

1. Library: dagre (MIT, see `LICENSE`)
2. Version: 0.8.5
3. Source: https://registry.npmjs.org/dagre/-/dagre-0.8.5.tgz (`package/dist/dagre.min.js`, `package/LICENSE`)
4. sha256 of the tarball: `ffaf576ea24546aed65aa2bed174d77fe4fbfe7985aa6c4a7cd0293c1994c4ed`
5. sha256 of `dagre.min.js`: `62eb9787ccfdbdf4148d4d99d31dbf9ee4770eafee81e637d759b52aac22cd51`
6. sha256 of `LICENSE` (dagre's, followed by the lodash notice, since `dagre.min.js` bundles lodash 4.17 and graphlib 2.1, both MIT; lodash from https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz `package/LICENSE`, sha256 `f71e8ed126b46346494aad5486874cd8f0aafe95092ed67d2e3cb6110f939abc`): `62b15090bd7cec87d2abd8395175407eee38ce04995415023f4cd9f215ef0abe`

Layered graph layout (it bundles graphlib). It backs the "Traffic flow" layout through `cytoscape-dagre`; the global `dagre` is loaded before the adapter.

To upgrade: download the new tarball, replace the two files, update the version and hashes above. A spec checks the
hash of `dagre.min.js` against this file.
