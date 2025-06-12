package example

import SM64 "../../"
import "core:fmt"
import "core:time"

rompath: string : "./baserom.z64"

main :: proc() {
  sm64,sm64_err := SM64.new_sm64(rompath)
  if sm64_err != SM64.Error.None {
    fmt.println(SM64.error_to_string(sm64_err))
    for true {} 
    return
  }

  level_geometry := create_level_geometry()
  SM64.load_static_surfaces(level_geometry)

  mario, mario_err := SM64.create_mario(50, 10, 50)

  
  if mario_err != SM64.Error.None {
    fmt.println(SM64.error_to_string(mario_err))
    for true {}
    return
  }

  input := SM64.MarioInputs {
    stickY = 1,
  }

  for true {
    state := SM64.tick(&mario, input)
    fmt.println(SM64.format_state(state))
    free_all(context.temp_allocator) // free temp strings after printing each state
    time.sleep(16 * time.Millisecond)
  }

  fmt.println("Simulation ended. Press Ctrl+C to exit.")
  for true {}
  SM64.drop_mario(mario)
  // for &triangle in SM64.mario_vertex_triangles(&mario.geometry) {
    // draw_triangle(&triangle, SM64.sm64_mario_texture_atlas(sm64)) -- use a renderer to draw mario
  // }
}

// you'll likely want to get this automatically from a map file or something
create_level_geometry :: proc() -> []SM64.LevelTriangle {
    tris := make([]SM64.LevelTriangle, 2, context.allocator)

    tris[0] = SM64.LevelTriangle{
        kind = SM64.Surface.Default,
        force = 0,
        terrain = SM64.Terrain.Grass,
        vertices = [3]SM64.Vec3{
            SM64.Vec3{ x=0, y=0, z=0 },
            SM64.Vec3{ x=0, y=0, z=100 },
            SM64.Vec3{ x=100, y=0, z=0 },
        },
    }

    tris[1] = SM64.LevelTriangle{
        kind = SM64.Surface.Default,
        force = 0,
        terrain = SM64.Terrain.Grass,
        vertices = [3]SM64.Vec3{
            SM64.Vec3{ x=100, y=0, z=0 },
            SM64.Vec3{ x=0, y=0, z=100 },
            SM64.Vec3{ x=100, y=0, z=100 },
        },
    }

    return tris
}
