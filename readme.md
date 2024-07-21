# OWG - Odin Web Graphics

> [!IMPORTANT]
> OWG is a working in progress and bugs and bad code are expected. Feel free to submit your PRs
>


OWG is basicly a simple render framework written in Odin using the `vendor:wasm` modules.

## Current features:
- Single batching system with support for `Rectangle` drawing and `Texture` drawing
- Texture loading
- Orthogonal Camera similar to `Camera2D` in raylib

## Basic Example:

This example is present in [here](./example/basic.odin).


```odin
package main

import "owg"
import gl "vendor:wasm"

batch : owg.Batch

main :: proc() {
    owg.init(1024, 576, "game")

    batch = owg.batch_init()
}

@(export)
step :: proc(dt: f32) -> (keep_going := true) {

    gl.Clear(gl.COLOR_BUFFER_BIT)
	gl.ClearColor(0, 0.2, 0.3, 1)

	owg.batch_begin(&batch)
	{
		owg.batch_draw_rect(&batch, 0, 0, 10, 10, 0, 1, 0, 1)
	}
	owg.batch_end(&batch)


    return
}
```

## Examples:

You can try the examples with `./build.ps1`. (Currently only windows, or linux if you install powershell)

```sh
> ./build.ps1 <name_of_example> # ./build.ps1 basic <-> ./build.ps1 examples/basic.odin
> cd example/public && python -m http.server
```

Check the `build.ps1` script for info.

## How it works:

Obscure things about the implementation of some features:
- [Textures](./docs/textures.md)

## License:

This project uses a modified version of `runtime.js` provided by odin. This file has his project [license](https://github.com/odin-lang/Odin/blob/master/LICENSE).