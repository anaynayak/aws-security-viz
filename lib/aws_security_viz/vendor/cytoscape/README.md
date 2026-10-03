# Vendored Cytoscape.js

Inlined into the self-contained `.html` output (see `Renderer::Html`) so the viewer needs no CDN and works from `file://`.

1. Library: Cytoscape.js (MIT, see `LICENSE`)
2. Version: 3.34.3
3. Source: https://registry.npmjs.org/cytoscape/-/cytoscape-3.34.3.tgz (`package/dist/cytoscape.min.js`, `package/LICENSE`)
4. sha256 of the tarball: `5d9e479216ed58a5f1ac639e746fd7d9770c4393f8c355dd133abc90bcc9ff3f`
5. sha256 of `cytoscape.min.js`: `5f3b5b529546d5af1fc5628590af033b74511a5b6f789f5f4682845863228b91`
6. sha256 of `LICENSE`: `eb319c6e6f233607f71e8e2f450391751883cfc0eeb3ca7ef574c13d1d9c2203`

Layout uses Cytoscape's built-in `cose` layout (compound-node aware), so no layout extension is vendored.

To upgrade: download the new tarball, replace the two files, update the version and hashes above. A spec checks the
hash of `cytoscape.min.js` against this file.
