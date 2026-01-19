#!/bin/sh

set -eu

# Build tests without running
cargo test --no-run --all-features > /tmp/bundler-build.log 2>&1

test_bin=$(find target/debug/deps -maxdepth 1 -type f -perm -111 -name 'lightningcss-*' -exec ls -t {} + 2>/dev/null | head -n 1)

if [ -z "$test_bin" ]; then
	echo "Could not find test binary in target/debug/deps"
	exit 1
fi

file "$test_bin"

threads=""
if command -v nproc >/dev/null 2>&1; then
	# Linux
	threads=$(nproc)
else
	# freebsd and macOS
	threads=$(sysctl -n hw.ncpu 2>/dev/null || true)
fi
if [ -z "$threads" ]; then
	threads=1
fi

ok=true
for i in $(seq 1 200); do
	if ! RAYON_NUM_THREADS="1" "$test_bin" --exact bundler::tests::test_bundle --test-threads=1 > /tmp/bundler-test.log 2>&1; then
		echo "bundler::tests::test_bundle (RAYON_NUM_THREADS=1) failed on iteration $i"
		ok=false
		break
	fi
done

ok=true
for i in $(seq 1 200); do
	if ! RAYON_NUM_THREADS="$threads" "$test_bin" --exact bundler::tests::test_bundle --test-threads=1 > /tmp/bundler-test.log 2>&1; then
		echo "bundler::tests::test_bundle (RAYON_NUM_THREADS=$threads) failed on iteration $i"
		ok=false
		break
	fi
done

if [ "$ok" = true ]; then
	echo "bundler::tests::test_bundle passed 200 iterations"
fi
