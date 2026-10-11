# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Bumped the `ameba` dev dependency from `~> 1.6.0` to `~> 1.7.0`.
- Refreshed the `hpdf` dev dependency against the latest `threez/hpdf.cr`
  (still `1.0.0`, satisfying `~> 1.0`); no public API changes, and the full
  spec suite (including the Mustang-based `spec-integration` PDF/A-3b
  embedding tests) continues to pass against it.
- Restructured `.github/workflows/ci.yml` from the previous
  `verify-linux` / `verify-macos` jobs into a `lint` job (format check, ameba
  lint, compile check, all on Ubuntu with Crystal pinned to 1.20.2) and a
  `test` job (`needs: lint`, matrix of Ubuntu and macOS running
  `crystal spec --order=random`, plus `make spec-integration` on macOS where
  libharu >= 2.4 is available), with shard caching and an explicit
  `shards build ameba` step added to the `lint` job.
- Dropped `ubuntu-latest` from the `test` job's matrix: `src/zugpferd/pdf.cr`
  calls PDF/A functions (`HPDF_SetPDFAConformance`,
  `HPDF_AppendOutputIntents`, `HPDF_EmbeddedFile_*`, etc.) that require
  libharu >= 2.4, but apt's `libhpdf-dev` package predates that, so
  `crystal spec` failed to link on Ubuntu entirely. The `lint` job's
  Ubuntu compile check still passes since it uses `--no-codegen` and
  doesn't link; `crystal spec` and `make spec-integration` now run on
  macOS only, where Homebrew's libharu is current enough.
- Updated the `Makefile`'s `lib/ameba/bin/ameba` rule to explicitly run
  `shards build ameba` after `shards install`, since ameba 1.7.0 no longer
  ships a `postinstall` build hook.

### Fixed

- Resolved all ameba 1.7.0 lint findings:
  - `spec/zugpferd/compliance_spec.cr` and `spec/zugpferd/mustang_spec.cr`:
    missing spaces around macro expressions (`Lint/WhitespaceAroundMacroExpression`).
  - `spec/zugpferd/compliance_spec.cr` and `spec/zugpferd/generator_spec.cr`:
    `%`-literals not delimited by `(` and `)` (`Style/PercentLiteralDelimiters`).
  - `src/zugpferd/reader.cr`: several redundant `nil` in control expressions
    (`Style/RedundantNilInControlExpression`).
  - `src/zugpferd/reader.cr`: `parse_trade_party` exceeded the cyclomatic
    complexity threshold (`Metrics/CyclomaticComplexity`, 13/12); split into
    `parse_trade_party_global_id`, `parse_trade_party_tax_registrations`,
    `parse_trade_party_electronic_address`, and `parse_trade_party_contact`
    helper methods with no behavior change.
