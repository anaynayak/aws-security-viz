# Vendored layout-base

Inlined into the self-contained `.html` output (see `Renderer::Html`) so the viewer needs no CDN and works from `file://`.

1. Library: layout-base (MIT, see `LICENSE`)
2. Version: 2.0.1
3. Source: https://registry.npmjs.org/layout-base/-/layout-base-2.0.1.tgz (`package/layout-base.js`, `package/LICENSE`)
4. sha256 of the tarball: `34165e46d8c4b9d719a592e39a60fa5f7324c21a3edd02733e1116b17013defd`
5. sha256 of `layout-base.js`: `ec15ab5df9af3f20708f4faab994accf91cda71848cd5bb10a23432cc50b6745`
6. sha256 of `LICENSE`: `eabb762d8a95109a39c9be3247325529a5239a7aca327d909c3ccdc41f3a06bf`

Dependency of cose-base (it requires layout-base ^2.0.0). Exposes the global `layoutBase`.

To upgrade: download the new tarball, replace the two files, update the version and hashes above. A spec checks the
hash of `layout-base.js` against this file.
