mkdir -p build
pushd build > /dev/null
odin run ../src -out:odin-new -debug -strict-style -vet
popd > /dev/null
