# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.2] - 2025-10-06

This release has no new features or changes. I accidentally retired version 0.3.1 on hex.pm. This is functionally identical to 0.3.1.

## [0.3.1] - 2025-10-06

### Fixed
- Restricted usage_rules dependency to development only

## [0.3.0] - 2025-10-06

### Added
- `usage-rules.md` file with comprehensive LLM usage documentation for when Typster is used as a dependency
- `CLAUDE.md` for project-specific LLM instructions
- `AGENTS.md` for agent-specific documentation
- Precompiled NIF binaries support via `rustler_precompiled`
- Precompiled binaries for macOS (ARM64 and x86_64) and Linux (ARM64 and x86_64)
- GitHub Actions workflow for automated NIF builds on releases
- Environment variable `TYPSTER_BUILD` to force local compilation when needed

### Changed
- Updated `comemo` dependency to v0.5
- Made `rustler` dependency optional (only needed when building from source)
- Switched from `use Rustler` to `use RustlerPrecompiled` in Native module
- Updated installation instructions in README to reflect precompiled binary availability

## [0.2.0] - 2025-10-06

### Fixed
- Fixed NIF compilation in CI/CD environments by adding `mode: :release` to Rustler configuration
- GitHub Actions tests now properly compile the Rust NIF library before running tests

## [0.1.0] - 2025-10-06

### Added
- Initial release of Typster - Elixir NIF wrapper for Typst document compiler
- Core rendering functions for PDF, SVG, and PNG output formats
- Variable binding support with automatic type conversion (maps, lists, strings, numbers, booleans)
- Date and time support: Elixir `Date`, `DateTime`, and `NaiveDateTime` structs automatically convert to Typst `datetime` type with full formatting support
- PDF metadata embedding (title, author, keywords, creation date)
- Support for Typst packages from local paths and package registry
- Thread-safe concurrent rendering with mutex-protected package downloads
- Embedded font support via typst-assets (17 fonts included)
- Comprehensive test suite with 70 tests (42 unit, 9 property-based, 9 concurrency, 7 package, 12 datetime)
- Example scripts demonstrating invoice generation, multi-page reports, and QR codes
- Full API documentation generated with ExDoc
- Rust NIF implementation using Rustler 0.37.1
- Support for Typst 0.13.1
- Automatic package downloads from Typst registry with local caching
- Package download tests covering imports, caching, and error handling

### API
- `Typster.render_pdf/3` - Render templates to PDF with variables and options
- `Typster.render_svg/3` - Render templates to SVG (returns list of pages)
- `Typster.render_png/3` - Render templates to PNG with configurable resolution
- `Typster.Native` module with low-level NIF functions

### Performance
- Successfully tested with 100 concurrent renders completing in ~22-70ms total
- Average render time: <1ms per document for simple templates
- Thread-safe operations across multiple Elixir processes

### Documentation
- Complete README with installation instructions, usage examples, and features
- ExDoc-generated HTML and EPUB documentation
- Inline documentation for all public functions
- Example scripts in `examples/` directory:
  - `invoice.exs` - Professional invoice with calculations
  - `report.exs` - Multi-page report with multiple output formats
  - `qrcode.exs` - Business cards and labels with QR codes

### Dependencies
- Elixir ~> 1.18
- Erlang/OTP 27
- Rust toolchain (for compilation)
- Typst 0.13.1
- Rustler 0.37.1

[0.3.2]: https://github.com/mylanconnolly/typster/releases/tag/v0.3.2
[0.3.1]: https://github.com/mylanconnolly/typster/releases/tag/v0.3.1
[0.3.0]: https://github.com/mylanconnolly/typster/releases/tag/v0.3.0
[0.2.0]: https://github.com/mylanconnolly/typster/releases/tag/v0.2.0
[0.1.0]: https://github.com/mylanconnolly/typster/releases/tag/v0.1.0
