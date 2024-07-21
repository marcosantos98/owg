package main

import "core:fmt"
import "core:math/rand"
import "core:time"
import gl "vendor:wasm/WebGL"

import "../owg"

v2 :: owg.v2

// :global
batch: owg.Batch
cam: owg.Camera2D

Object :: struct {
	pos, size: v2,
	r, g, b:   f32,
}

noise: ^owg.Texture
objects := [10]Object{}

main :: proc() {

	// :init	
	owg.init(1024, 576, "game")

	cam = {}

	cam.offset = owg.mv2(1024 / 2, 576 / 2)
	cam.zoom = 1
	cam.size = owg.mv2(1024, 576)

	batch = owg.batch_init()
	batch.cam = cam

	noise = owg.load_texture("noise.png")

	s := rand.create(u64(time.time_to_unix(time.now())))
	context.random_generator = rand.default_random_generator(&s)

	sizes := [?]v2{{10, 10}, {20, 20}, {40, 40}, {80, 80}}

	for i in 0 ..< 10 {
		objects[i] = {
			pos  = owg.mv2(rand.float32_range(-100, 100), rand.float32_range(-100, 100)),
			size = rand.choice(sizes[:]),
			r    = rand.float32(),
			g    = rand.float32(),
			b    = rand.float32(),
		}
	}
}

@(export)
step :: proc(dt: f32) -> (keep_going := true) {

	gl.Clear(gl.COLOR_BUFFER_BIT)
	gl.ClearColor(0.2, 0.2, 0.2, 1)

	batch.cam = cam
	owg.batch_begin(&batch)
	{
		for i in 0 ..< 10 {
			owg.batch_draw_texture(&batch, noise.id, objects[i].pos.x, objects[i].pos.y, objects[i].size.x, objects[i].size.y, objects[i].r, objects[i].g, objects[i].b, 1)
		}
	}
	owg.batch_end(&batch)

	return
}
