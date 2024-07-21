package owg

import "core:fmt"
import "core:math/linalg"
import "core:mem"
import "core:os"
import gl "vendor:wasm/WebGL"
import "vendor:wasm/js"

foreign import "owg"

// note(marco): i'm not typing that bro
v2 :: linalg.Vector2f32

mv2 :: proc(x := f32(0), y := f32(0)) -> v2 {
	return {x, y}
}

@(private = "file")
i_width, i_height: i32
@(private = "file")
i_canvas_id: string

init :: proc(width, height: i32, canvas_id: string) {
	i_width = width
	i_height = height
	i_canvas_id = canvas_id

	@(default_calling_convention = "contextless")
	foreign owg {
		set_element_size :: proc(id: string, w, h: i32) ---
	}

	set_element_size(canvas_id, width, height)

	gl.SetCurrentContextById(i_canvas_id)
	gl.PixelStorei(gl.UNPACK_FLIP_Y_WEBGL, 1)
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA)
}

// note(marco): since this is over inspired by raylib,
// the camera works basicly the same way
Camera2D :: struct {
	target:   v2,
	offset:   v2,
	zoom:     f32,
	// note(marco): since we define the proj as well we need
	// 			to know the size of the canvas for the ortho
	size:     v2,
	// in degrees
	rotation: f32,
}

cam_get_view_mat :: proc(cam: Camera2D) -> matrix[4, 4]f32 {
	proj := linalg.matrix_ortho3d_f32(0, cam.size.x, 0, cam.size.y, -1, 100)

	view := linalg.identity(matrix[4, 4]f32)
	view *= linalg.matrix4_translate_f32({-cam.target.x, -cam.target.y, 0})
	view *= linalg.matrix4_rotate_f32(linalg.to_radians(cam.rotation), {0, 0, 1})
	view *= linalg.matrix4_scale_f32({cam.zoom, cam.zoom, 1})
	view *= linalg.matrix4_translate_f32({cam.offset.x, cam.offset.y, 0})

	return proj * view
}

Shader :: struct {
	program:       gl.Program,
	vertexPosAttr: i32,
	colorAttr:     i32,
	uvAttr:        i32,
	projUniform:   i32,
}

Batch :: struct {
	shader:      Shader,
	vao:         gl.VertexArrayObject,
	vbo, ebo:    gl.Buffer,
	vIdx:        i32,
	verticies:   [1000]f32,
	iIdx:        i32,
	indices:     [1000]i32,
	lastIndice:  i32,
	cam:         Camera2D,
	shapeTex:    gl.Texture,
	lastTexture: gl.Texture,
}

batch_init :: proc() -> Batch {
	batch := Batch{}

	batch.cam = {
		target = mv2(),
		size   = {f32(i_width), f32(i_height)},
		offset = mv2(),
		zoom   = 1,
	}

	vsSource := `#version 300 es
precision mediump float;

in vec2 a_pos;
in vec4 a_color;
in vec2 a_texUV;

uniform mat4 u_proj;

out vec4 f_color;
out vec2 f_texUV;

void main() {
    gl_Position = u_proj * vec4(a_pos.x, a_pos.y, 0, 1);
    f_color = a_color;
	f_texUV = a_texUV;
}`

	fsSource := `#version 300 es

precision mediump float;

in vec4 f_color;
in vec2 f_texUV;

out vec4 finalColor;

uniform sampler2D u_texture;

void main() {
    finalColor = texture(u_texture, f_texUV) * f_color;
}
`

	program, _ := gl.CreateProgramFromStrings({vsSource}, {fsSource})

	batch.shader.program = program
	batch.shader.vertexPosAttr = gl.GetAttribLocation(batch.shader.program, "a_pos")
	batch.shader.colorAttr = gl.GetAttribLocation(batch.shader.program, "a_color")
	batch.shader.uvAttr = gl.GetAttribLocation(batch.shader.program, "a_texUV")
	batch.shader.projUniform = gl.GetUniformLocation(batch.shader.program, "u_proj")

	batch.vao = gl.CreateVertexArray()
	gl.BindVertexArray(batch.vao)

	batch.vbo = gl.CreateBuffer()
	gl.BindBuffer(gl.ARRAY_BUFFER, batch.vbo)
	gl.BufferData(gl.ARRAY_BUFFER, 1000 * size_of(f32), nil, gl.STATIC_DRAW) // for some odd reason DYNAMIC throws "not enought memory in buffer"

	batch.ebo = gl.CreateBuffer()
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, batch.ebo)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, 1000 * size_of(i32), nil, gl.STATIC_DRAW)

	gl.VertexAttribPointer(batch.shader.vertexPosAttr, 2, gl.FLOAT, false, 8 * 4, 0)
	gl.EnableVertexAttribArray(batch.shader.vertexPosAttr)
	gl.VertexAttribPointer(batch.shader.colorAttr, 4, gl.FLOAT, false, 8 * 4, 2 * 4)
	gl.EnableVertexAttribArray(batch.shader.colorAttr)
	gl.VertexAttribPointer(batch.shader.uvAttr, 2, gl.FLOAT, false, 8 * 4, 6 * 4)
	gl.EnableVertexAttribArray(batch.shader.uvAttr)


	batch.shapeTex = gl.CreateTexture()
	gl.BindTexture(gl.TEXTURE_2D, batch.shapeTex)

	data := [4]u8{255, 255, 255, 255}
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, 4, raw_data(data[:]))

	gl.BindTexture(gl.TEXTURE_2D, 0)

	gl.BindVertexArray(0)
	return batch
}

batch_set_cam :: proc(batch: ^Batch, cam: Camera2D) {
	batch.cam = cam
}

batch_begin :: proc(batch: ^Batch) {
	gl.UseProgram(batch.shader.program)
}

batch_draw_rect :: proc(batch: ^Batch, x, y, w, h, r, g, b, a: f32) {
	batch_draw_texture(batch, batch.shapeTex, x, y, w, h, r, g, b, a)
}

batch_draw_texture :: proc(batch: ^Batch, texture: gl.Texture, x, y, w, h, r, g, b, a: f32) {
	if texture != batch.lastTexture {
		batch_flush(batch)
		batch.lastTexture = texture
	}
	batch_push_vertex(batch, x + w, y + h, r, g, b, a, 1, 1)
	batch_push_vertex(batch, x + w, y, r, g, b, a, 1, 0)
	batch_push_vertex(batch, x, y, r, g, b, a, 0, 0)
	batch_push_vertex(batch, x, y + h, r, g, b, a, 0, 1)
}

batch_push_vertex :: proc(batch: ^Batch, x, y, r, g, b, a, u, v: f32) {
	if batch.vIdx + 8 >= 1000 {
		batch_flush(batch)
	}
	batch.verticies[batch.vIdx] = x
	batch.vIdx += 1
	batch.verticies[batch.vIdx] = y
	batch.vIdx += 1
	batch.verticies[batch.vIdx] = r
	batch.vIdx += 1
	batch.verticies[batch.vIdx] = g
	batch.vIdx += 1
	batch.verticies[batch.vIdx] = b
	batch.vIdx += 1
	batch.verticies[batch.vIdx] = a
	batch.vIdx += 1
	batch.verticies[batch.vIdx] = u
	batch.vIdx += 1
	batch.verticies[batch.vIdx] = v
	batch.vIdx += 1


	batch.indices[batch.iIdx] = batch.lastIndice
	batch.iIdx += 1
	batch.indices[batch.iIdx] = batch.lastIndice + 1
	batch.iIdx += 1
	batch.indices[batch.iIdx] = batch.lastIndice + 3
	batch.iIdx += 1
	batch.indices[batch.iIdx] = batch.lastIndice + 1
	batch.iIdx += 1
	batch.indices[batch.iIdx] = batch.lastIndice + 2
	batch.iIdx += 1
	batch.indices[batch.iIdx] = batch.lastIndice + 3
	batch.iIdx += 1
	batch.lastIndice = batch.indices[batch.iIdx - 1] + 1

}

batch_flush :: proc(batch: ^Batch) {
	if batch.vIdx > 0 {
		gl.BindTexture(gl.TEXTURE_2D, batch.lastTexture)
		gl.BindVertexArray(batch.vao)
		gl.BufferSubDataSlice(gl.ARRAY_BUFFER, 0, batch.verticies[:])
		gl.BufferSubDataSlice(gl.ELEMENT_ARRAY_BUFFER, 0, batch.indices[:])

		gl.UniformMatrix4fv(batch.shader.projUniform, cam_get_view_mat(batch.cam))

		gl.DrawElements(gl.TRIANGLES, int(batch.iIdx), gl.UNSIGNED_INT, rawptr(nil))

		batch.iIdx = 0
		batch.vIdx = 0
		batch.lastIndice = 0
		mem.zero(&batch.verticies, size_of(f32) * 1000)
		mem.zero(&batch.indices, size_of(i32) * 1000)
	}
}

batch_end :: proc(batch: ^Batch) {
	batch_flush(batch)
}

Texture :: struct {
	w, h: i32,
	id:   gl.Texture,
	tag:  string,
}


load_texture :: proc(path: string) -> ^Texture {
	@(default_calling_convention = "contextless")
	foreign owg {
		load_image_data :: proc(path: string, textureId: gl.Texture) ---
		get_image_size :: proc(id: string, w, h: ^i32) ---
	}

	t := new(Texture)
	texture := gl.CreateTexture()
	t.id = texture

	s := fmt.tprintf("img_{}", texture)
	load_image_data(path, texture)
	t.tag = s
	js.add_event_listener(s, .Load, t, proc(e: js.Event) {
		tex := cast(^Texture)e.user_data
		gl.BindTexture(gl.TEXTURE_2D, tex.id)
		get_image_size(tex.tag, &tex.w, &tex.h)
	})

	return t
}
