#!/usr/bin/env bash

set -e
ARGV_DIRECTORY="$1"
set -u

[[ "${DEBUG}" == "false" ]] || set -x

pushd $ARGV_DIRECTORY

# Report versions for different tools
rustup toolchain list
rustc --version
cargo clippy -- --version
cargo fmt -- --version

################################################################################
#
# following section checks formatting, run linters & tests
#
# ----> Applies to both types `rust-public-crate` & `rust-public-crate-wasm`
#
echo "Checking Rust crate formatting..."
cargo fmt -- --check

echo "Linting Rust crate..."
cargo clippy --all-targets --all-features -- -D warnings

echo "Testing Rust crate..."
cargo test

echo "Trying to package Rust crate..."
# We need allow-dirty at this step because VB has already ran and updated version files
cargo package --allow-dirty
