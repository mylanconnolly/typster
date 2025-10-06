# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-10-03

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

[0.1.0]: https://github.com/mylanconnolly/typster/releases/tag/v0.1.0
