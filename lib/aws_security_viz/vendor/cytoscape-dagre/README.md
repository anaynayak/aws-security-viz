# Vendored cytoscape-dagre

Inlined into the self-contained `.html` output (see `Renderer::Html`) so the viewer needs no CDN and works from `file://`.

1. Library: cytoscape-dagre (MIT, see `LICENSE`)
2. Version: 2.5.0
3. Source: https://registry.npmjs.org/cytoscape-dagre/-/cytoscape-dagre-2.5.0.tgz (`package/cytoscape-dagre.js`, `package/LICENSE`)
4. sha256 of the tarball: `cbb58d8e719b0c0ed891a140ab050af8aac35a11b0b51f0b4ec46238fce47577`
5. sha256 of `cytoscape-dagre.js`: `bf70fe402991dcbff33e05a7e4a5271c78020bb75e85d1c80ab7538e4157112e`
6. sha256 of `LICENSE`: `fccef1f60ab551f032291912d77bb9e8cd98b99bd1cffe185062ac7216a36d5e`

Cytoscape adapter for dagre, registered with `cytoscape.use` after dagre is loaded. Powers the "Traffic flow" layout.

To upgrade: download the new tarball, replace the two files, update the version and hashes above. A spec checks the
hash of `cytoscape-dagre.js` against this file.
