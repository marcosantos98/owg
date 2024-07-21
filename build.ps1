if($args[0] -eq "web") {
    cd web
    odin build main.odin -file -target:js_wasm32 -out:odin.wasm
    cp ../example/public/runtime.js .
    cp ../example/public/index.html .
    cd ..
} else {
    cd example
    odin build "$args.odin" -file -target:js_wasm32 -out:odin.wasm
    mv -Force odin.wasm ./public
    cd ..
}