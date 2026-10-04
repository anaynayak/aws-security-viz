# Vendored cose-base

Inlined into the self-contained `.html` output (see `Renderer::Html`) so the viewer needs no CDN and works from `file://`.

1. Library: cose-base (MIT, see `LICENSE`)
2. Version: 2.2.0
3. Source: https://registry.npmjs.org/cose-base/-/cose-base-2.2.0.tgz (`package/cose-base.js`, `package/LICENSE`)
4. sha256 of the tarball: `612ec91a30b7f2dc158cca4846eeea1b7f89a97fc672951da3c1932107de6da8`
5. sha256 of `cose-base.js`: `7cae9509bd36235a63a85e71c8d9fa2cd0bc1d0c1ecc5b5a737976f39d040ddf`
6. sha256 of `LICENSE`: `5fb3cf4a14c3c5af6e473a192df8bca10c77754e3a0c6492c79fb92a76a5478a`

Dependency of cytoscape-fcose (it requires cose-base ^2.2.0). Exposes the global `coseBase`.

To upgrade: download the new tarball, replace the two files, update the version and hashes above. A spec checks the
hash of `cose-base.js` against this file.
