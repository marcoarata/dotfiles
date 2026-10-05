# Pack Rust

Rust via mise (`rustup`/`cargo-binstall` backend depending on plugin) or direct rustup.

## Version
`rust-toolchain.toml` or `./mise.toml`:
```toml
[tools]
rust = "stable"
```

## Usage
```sh
mise install        # or: rustup update stable
cargo build
cargo test
cargo clippy -- -D warnings
cargo fmt --check
```

Note: when using rustup outside mise, do not pin `rust` in mise to avoid duplicate shims.
