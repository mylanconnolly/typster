# Contributing to Typster

Thank you for your interest in contributing to Typster! We welcome contributions from the community and appreciate your help in making this project better.

## Code of Conduct

This project adheres to the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report any unacceptable behavior to mylan@mylan.io.

## How to Contribute

### Reporting Bugs

If you find a bug, please open an issue on GitHub with:
- A clear description of the problem
- Steps to reproduce the issue
- Expected vs. actual behavior
- Your environment (Elixir version, OTP version, Rust version, OS)
- Any relevant error messages or logs

### Suggesting Features

We welcome feature suggestions! For complex or significant new features, please:
1. **Open an issue first** to discuss the feature before starting work
2. Describe the use case and why the feature would be valuable
3. Outline your proposed approach if you have one

This helps ensure we're aligned on the direction and avoids unnecessary work on features that might not fit the project's goals.

For smaller features or enhancements, feel free to open a pull request directly.

### Pull Requests

We gladly accept pull requests! Here's how to contribute code:

1. **Fork the repository** and create a new branch for your changes
2. **Make your changes** following the guidelines below
3. **Test your changes** thoroughly
4. **Submit a pull request** with a clear description of what you've changed and why

#### Guidelines for Pull Requests

**Testing**
- New functionality should include tests where possible
- All existing tests must continue to pass
- Run `mix test` to ensure all tests pass before submitting

**Code Formatting**
- Run `mix format` before committing your code
- Follow Elixir style conventions
- For Rust code, follow standard Rust formatting with `cargo fmt`

**Code Quality**
- Add documentation for new public functions
- Include typespecs for Elixir functions
- Keep functions focused and maintainable
- Follow the existing code style and patterns

**Commit Messages**
- Write clear, descriptive commit messages
- Reference related issues using `#issue-number`

## Development Setup

### Prerequisites

- Elixir ~> 1.18
- Erlang/OTP 27+
- Rust toolchain (install from [rustup.rs](https://rustup.rs/))

### Getting Started

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/typster.git
cd typster

# Install dependencies
mix deps.get

# Compile the project (includes Rust NIF)
mix compile

# Run tests
mix test

# Check code formatting
mix format --check-formatted

# Generate documentation
mix docs
```

### Project Structure

- `lib/` - Elixir source code
- `native/typster_nif/` - Rust NIF implementation
- `test/` - Test suite
- `examples/` - Example scripts

### Working with the Rust NIF

The project uses [Rustler](https://github.com/rusterlium/rustler) to interface with Rust code:

```bash
# Build the Rust NIF manually
cd native/typster_nif
cargo build --release

# Run Rust tests
cargo test

# Format Rust code
cargo fmt
```

## Running Tests

```bash
# Run all tests
mix test

# Run specific test file
mix test test/typster_test.exs

# Run tests with coverage
mix test --cover

# Run concurrent tests
mix test test/concurrent_test.exs
```

## Documentation

- Add documentation for all public functions using `@doc`
- Include usage examples in documentation
- Update the README if adding user-facing features
- Generate docs with `mix docs` to preview

## Questions?

If you have questions about contributing, feel free to:
- Open an issue for discussion
- Email mylan@mylan.io

We appreciate your contributions and look forward to working with you!
