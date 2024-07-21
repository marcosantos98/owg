package main

import gl "vendor:wasm/WebGL"

import "../owg"

batch: owg.Batch
test_texture: ^owg.Texture

main :: proc() {
	owg.init(1024, 576, "game")

	batch = owg.batch_init()
	test_texture = owg.load_texture("./noise.png")
}

@(export)
step :: proc(dt: f32) -> (keep_going := true) {

	gl.Clear(gl.COLOR_BUFFER_BIT)
	gl.ClearColor(0, .2, .3, 1)

	owg.batch_begin(&batch)
	{
		owg.batch_draw_texture(&batch, test_texture.id, 0, 0, f32(test_texture.w), f32(test_texture.h), 1, 1, 1, 1)
	}
	owg.batch_end(&batch)

	return
}
