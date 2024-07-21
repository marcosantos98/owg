package main

import "../owg"
import gl "vendor:wasm/WebGL"

batch: owg.Batch

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
