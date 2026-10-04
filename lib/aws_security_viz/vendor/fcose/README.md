# Vendored cytoscape-fcose

Inlined into the self-contained `.html` output (see `Renderer::Html`) so the viewer needs no CDN and works from `file://`.

1. Library: cytoscape-fcose (MIT, see `LICENSE`)
2. Version: 2.2.0
3. Source: https://registry.npmjs.org/cytoscape-fcose/-/cytoscape-fcose-2.2.0.tgz (`package/cytoscape-fcose.js`, `package/LICENSE`)
4. sha256 of the tarball: `4e1f30e1821fdd4b66f21043c8ea40a8e2ad0ba75e4ccdd2c24d289cf5595432`
5. sha256 of `cytoscape-fcose.js`: `4b1cab218d74996aa59cd8473f9239cc6398b8c1774d84d7e59ad9a68959cb57`
6. sha256 of `LICENSE`: `2837634f403949215760fcdd2fa1ed0c64875d02099ecc8318c704b852f1421d`

Compound-aware fCoSE layout extension for Cytoscape.js, the viewer's default layout. Needs `cose-base`, which needs `layout-base`; all three are loaded before the viewer script and registered with `cytoscape.use`. The upstream file is the unminified UMD build.

To upgrade: download the new tarball, replace the two files, update the version and hashes above. A spec checks the
hash of `cytoscape-fcose.js` against this file.
