#!/bin/sh

set -eu

# Build tests without running
cargo test --no-run --all-features > /tmp/bundler-build.log 2>&1

test_bin=""
test_candidates=$(find target/debug/deps -maxdepth 1 -type f -perm -111 -name 'lightningcss-*' -exec ls -t {} + 2>/dev/null || true)
for candidate in $test_candidates; do
	if "$candidate" --list >/dev/null 2>&1; then
		test_bin="$candidate"
		break
	fi
done

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

iterations=200
ok_single=true
for i in $(seq 1 "$iterations"); do
	if ! RAYON_NUM_THREADS="1" "$test_bin" --exact bundler::tests::test_bundle --test-threads=1 > /tmp/bundler-test.log 2>&1; then
		echo "bundler::tests::test_bundle (RAYON_NUM_THREADS=1) failed on iteration $i"
		cat /tmp/bundler-test.log
		ok_single=false
		break
	fi
done

ok_multi=true
for i in $(seq 1 "$iterations"); do
	if ! RAYON_NUM_THREADS="$threads" "$test_bin" --exact bundler::tests::test_bundle --test-threads=1 > /tmp/bundler-test.log 2>&1; then
		echo "bundler::tests::test_bundle (RAYON_NUM_THREADS=$threads) failed on iteration $i"
		cat /tmp/bundler-test.log
		ok_multi=false
		break
	fi
done

if [ "$ok_single" = true ] && [ "$ok_multi" = true ]; then
	echo "passed $iterations iterations"
	exit 0
else
	echo "failed within $iterations iterations"
	exit 1
fi
