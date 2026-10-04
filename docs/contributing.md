---
description: Set up a development environment for aws-security-viz, run the tests and linter, build the docs, and open a pull request.
---

# Contributing

Bug reports, fixes and documentation improvements are welcome. Report suspected vulnerabilities privately; see
[Security](security.md). Everyone taking part follows the
[Code of Conduct](https://github.com/anaynayak/aws-security-viz/blob/main/CODE_OF_CONDUCT.md).

## Development setup

```
git clone https://github.com/anaynayak/aws-security-viz
cd aws-security-viz
bundle install
```

1. Tests: `bundle exec rspec`. The integration specs need the Graphviz `dot` binary.
2. Lint: `bundle exec standardrb`. Both commands must pass before a pull request.
3. Browser specs: `spec/html_renderer_spec.rb` drives the HTML viewer in headless Chromium. Install it once with
   `uv run --group browser playwright install chromium` (add `--with-deps` on Linux); the specs are pending, with a reason, while `uv` or
   Chromium is missing. CI sets `BROWSER_SPECS=required`, so a missing install fails there.
4. Run from the checkout: `bundle exec exe/aws_security_viz -o spec/integration/dummy.json -f /tmp/out.svg`.

Supported Ruby versions are 3.3, 3.4 and 4.0.

## Code layout

| Path | Contents |
| --- | --- |
| `lib/aws_security_viz/cli.rb`, `cli_guard.rb` | Option parsing, exit codes and error messages. |
| `lib/aws_security_viz/provider/` | Where security groups come from: the EC2 API or a JSON file. |
| `lib/aws_security_viz/ec2/`, `model.rb` | Security group model and traffic derivation. |
| `lib/aws_security_viz/graph.rb`, `graph_filter.rb` | The graph, source and target filters, risk counting. |
| `lib/aws_security_viz/risk.rb` | The risky ingress rule. |
| `lib/aws_security_viz/renderer/` | One renderer per output family: html, json, mermaid, graphviz. |
| `lib/aws_security_viz/export/html/` | The HTML viewer template. |
| `spec/` | Specs; fixtures in `spec/fixtures` and `spec/integration`. |

## Adding a renderer

1. Add a class under `lib/aws_security_viz/renderer/` with `initialize(file_name, config)`, `add_node(name, opts)`,
   `add_edge(from, to, opts)` and `output`.
2. Register it in `renderer/all.rb`: the `ALL` table and, for extension inference, `EXTENSIONS`.
3. Add specs and document the format on the [Outputs](outputs.md) page.

## Pull requests

1. Keep commits small and single-purpose. Every behaviour change or bug fix comes with a spec that fails before the
   change and passes after.
2. Keep the suite and `standardrb` green at every commit.
3. Update `CHANGELOG.md` under `[Unreleased]` for user-visible changes.
4. Write prose in plain ASCII and without working notes.

## Building the documentation

The site is MkDocs Material. Its dependencies are locked with uv in `pyproject.toml` and `uv.lock`.

```
uv run --group docs mkdocs serve
uv run --locked --group docs mkdocs build --strict
```

Pages live in `docs/`. The changelog and security pages include `CHANGELOG.md` and `SECURITY.md`, so edit those files,
not the pages. The viewer screenshots and the social card are generated from `spec/integration/dummy.json` by
`script/docs-screenshots` (needs `uv` and headless Chromium installed through Playwright). A spec checks that every
command line option appears on the [Configuration](configuration.md) page.

## Releases

Releases are cut by the maintainer from a version tag. The process is in
[RELEASING.md](https://github.com/anaynayak/aws-security-viz/blob/main/RELEASING.md).
