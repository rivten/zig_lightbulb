CODE_PATH="$(dirname "$0")"

mkdir -p "$CODE_PATH/../build"
pushd "$CODE_PATH/../build"

zig build-exe ../code/lightbulb.zig

popd
