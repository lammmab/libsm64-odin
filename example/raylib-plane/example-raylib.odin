package main

import SM64 "../../"
import rl   "vendor:raylib"
import "core:fmt"
import "core:time"
import "core:strings"
import "core:math"

rom_path :: "./baserom.z64"

SCREEN_WIDTH  :: 800
SCREEN_HEIGHT :: 600

sm64_color_to_rl_color :: proc(c: SM64.Color) -> rl.Color {
    color: rl.Color
    color[0] = u8(c.r * 255)
    color[1] = u8(c.g * 255)
    color[2] = u8(c.b * 255)
    color[3] = 255
    return color
}

yaw   : f32 = 0.0
pitch : f32 = 15.0
distance : f32 = 400.0
target_y_offset : f32 = 40.0



draw_mario :: proc(mario: ^SM64.Mario) {
    triangles := SM64.mario_vertex_triangles(&mario.geometry)

    for tri, i in triangles {
        a := tri[0].position
        b := tri[1].position
        c := tri[2].position
        color := tri[0].color

        rl.DrawTriangle3D(
            [3]f32{a.x, a.y, a.z},
            [3]f32{b.x, b.y, b.z},
            [3]f32{c.x, c.y, c.z},
            sm64_color_to_rl_color(color),
        )
    }
}

deg_to_rad :: proc(deg: f32) -> f32 {
    return deg * (3.14159265 / 180.0)
}


draw_level :: proc(triangles: []SM64.LevelTriangle) {
    for tri in triangles {
        a := tri.vertices[0]
        b := tri.vertices[1]
        c := tri.vertices[2]

        color := rl.Color{50,200,50,255}

        rl.DrawTriangle3D(
            [3]f32{a.x, a.y, a.z},
            [3]f32{b.x, b.y, b.z},
            [3]f32{c.x, c.y, c.z},
            color,
        )
    }
}

sm64_vec3_to_rl_vec3 :: proc(v: SM64.Vec3) -> rl.Vector3 {
    return rl.Vector3{v.x, v.y, v.z}
}

update_mario_camera :: proc(camera: ^rl.Camera3D, mario_pos: SM64.Vec3, mouse_delta: rl.Vector2) {
    yaw += mouse_delta.x * 0.15
    pitch += mouse_delta.y * 0.15

    if pitch > 89.0 {
        pitch = 89.0
    }
    if pitch < -89.0 {
        pitch = -89.0
    }

    pitch_rad := deg_to_rad(pitch)
    yaw_rad := deg_to_rad(yaw)

    cam_x := distance * math.cos(pitch_rad) * math.cos(yaw_rad)
    cam_y := distance * math.sin(pitch_rad)
    cam_z := distance * math.cos(pitch_rad) * math.sin(yaw_rad)

    camera.position = rl.Vector3{mario_pos.x + cam_x, mario_pos.y + cam_y + 20, mario_pos.z + cam_z}
    camera.target = rl.Vector3{mario_pos.x, mario_pos.y + target_y_offset, mario_pos.z}
    camera.up = rl.Vector3{0, 1, 0}

    rl.UpdateCamera(camera, rl.CameraMode.CUSTOM)
}

input :: proc() -> SM64.MarioInputs {
    inputs: SM64.MarioInputs = SM64.MarioInputs{}

    rawX, rawY := 0.0, 0.0

    if rl.IsKeyDown(rl.KeyboardKey.W) || rl.IsKeyDown(rl.KeyboardKey.UP) {
        rawX = 1.0
    } else if rl.IsKeyDown(rl.KeyboardKey.S) || rl.IsKeyDown(rl.KeyboardKey.DOWN) {
        rawX = -1.0
    }

    if rl.IsKeyDown(rl.KeyboardKey.D) || rl.IsKeyDown(rl.KeyboardKey.RIGHT) {
        rawY = 1.0
    } else if rl.IsKeyDown(rl.KeyboardKey.A) || rl.IsKeyDown(rl.KeyboardKey.LEFT) {
        rawY = -1.0
    }

    yawRad := deg_to_rad(yaw)
    rotatedX := rawX * f64(math.cos(yawRad)) - rawY * f64(math.sin(yawRad))
    rotatedY := rawX * f64(math.sin(yawRad)) + rawY * f64(math.cos(yawRad))

    inputs.stickX = f32(rotatedX)
    inputs.stickY = f32(rotatedY)

    inputs.buttonA = u8(rl.IsKeyDown(rl.KeyboardKey.SPACE))
    inputs.buttonB = u8(rl.IsKeyDown(rl.KeyboardKey.LEFT_SHIFT))
    inputs.buttonZ = u8(rl.IsKeyDown(rl.KeyboardKey.LEFT_CONTROL))

    inputs.camLookX = 0.0
    inputs.camLookZ = 0.0

    return inputs
}




main :: proc() {
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "SM64 + Raylib")
    defer rl.CloseWindow()

    rl.SetTargetFPS(60)
    rl.HideCursor()

    camera := rl.Camera3D{
        position = rl.Vector3{200, 200, 200},
        target = rl.Vector3{0, 0, 0},
        up = rl.Vector3{0, 1, 0},
        fovy = 45.0,
        projection = rl.CameraProjection.PERSPECTIVE,
    }

    sm64, err := SM64.new_sm64(rom_path)
    if err != SM64.Error.None {
        fmt.println("Failed to load SM64: ", SM64.error_to_string(err))
        wait_forever()
        return
    }

    level_geometry := create_level_geometry()
    SM64.load_static_surfaces(level_geometry)

    mario, err2 := SM64.create_mario(50, 10, 50)
    if err2 != SM64.Error.None {
        fmt.println("Failed to create Mario: ", SM64.error_to_string(err2))
        wait_forever()
        return
    }


    rl.SetMousePosition(rl.GetScreenWidth()/2, rl.GetScreenHeight()/2)

    for frame := 0; !rl.WindowShouldClose(); {
        frame += 1

        mouse_delta := rl.GetMouseDelta()

        state := SM64.tick(&mario, input())

        update_mario_camera(&camera, state.position, mouse_delta)

        rl.SetMousePosition(rl.GetScreenWidth()/2, rl.GetScreenHeight()/2)

        rl.BeginDrawing()
        rl.ClearBackground(rl.SKYBLUE)

        rl.BeginMode3D(camera)
        draw_mario(&mario)
        draw_level(level_geometry)
        rl.EndMode3D()

        rl.DrawText("SM64 + Raylib", 10, 10, 20, rl.DARKGRAY)
        rl.DrawText(strings.unsafe_string_to_cstring(SM64.format_state(state)), 10, 40, 10, rl.GRAY)

        rl.EndDrawing()
        free_all(context.allocator)
        free_all(context.temp_allocator)
    }

    SM64.drop_mario(mario)
    fmt.println("Simulation ended. Press Ctrl+C to exit.")
    wait_forever()
}

wait_forever :: proc() {
	for true {}
}

create_level_geometry :: proc() -> []SM64.LevelTriangle {
	fmt.println("Creating level geometry...")
	tris := make([]SM64.LevelTriangle, 2, context.allocator)

	tris[0] = SM64.LevelTriangle{
		kind     = SM64.Surface.Default,
		force    = 0,
		terrain  = SM64.Terrain.Grass,
		vertices = [3]SM64.Vec3{
			{ x = 0,   y = 0, z = 0 },
			{ x = 0,   y = 0, z = 1000 },
			{ x = 1000, y = 0, z = 0 },
		},
	}

	tris[1] = SM64.LevelTriangle{
		kind     = SM64.Surface.Default,
		force    = 0,
		terrain  = SM64.Terrain.Grass,
		vertices = [3]SM64.Vec3{
			{ x = 1000, y = 0, z = 0 },
			{ x = 0,   y = 0, z = 1000 },
			{ x = 1000, y = 0, z = 1000 },
		},
	}

	return tris
}
