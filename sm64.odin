package SM64

/*

This project was made by lammmab!
libsm64 extracts the logic for the movement and control of Mario from the Super Mario
64 ROM providing a interface to implement your own Mario in your own 3D engine.

**Note:** You must provide your own copy of a Super Mario 64 (USA) ROM,
the correct ROM has a SHA1 hash of '9bef1128717f958171a4afac3ed78ee2bb4e86ce'.

*/

import "output"
import "core:os"
import "core:fmt"
import "core:crypto/legacy/sha1"
import "core:strings"
import "core:mem"
import "core:strconv"
import "core:encoding/hex"

VALID_HASH: string : "9bef1128717f958171a4afac3ed78ee2bb4e86ce"

SM64: Sm64Inner = Sm64Inner {
  texture_data = nil,
  rom_data = nil,
}


Sm64Inner :: struct {
  texture_data_ptr: ^u8,
  rom_data_ptr: ^u8,
  texture_data: []u8,
  rom_data: []u8,
}

Error :: enum {
  OS_Error,
  InvalidMarioPosition,
  InvalidRom,
  None,
}

error_to_string :: proc(err: Error) -> string {
    #partial switch err {
      case Error.OS_Error:
        return "IO error!"
      case Error.InvalidMarioPosition:
        return "Invalid mario position, ensure coordinates are above ground"
      case Error.InvalidRom:
        return "Invalid SM64 US rom!"
    }
    return "Unknown error"
} 

Sm64 :: struct {
  global: Sm64Inner,
}


compute_sha1 :: proc(filepath: string) -> (h: string, success: bool) {
    data, ok := os.read_entire_file(filepath)
    if !ok {
        return "", false
    }

    ctx: sha1.Context
    sha1.init(&ctx)
    sha1.update(&ctx, data)

    digest := [sha1.DIGEST_SIZE]u8{}
    sha1.final(&ctx, digest[:])

    hex_data := hex.encode(digest[:])
    hex_string := string(hex_data)

    return hex_string, true
}

validate_hash :: proc(filepath: string) -> bool {
    computed_hash, success := compute_sha1(filepath)
    if !success {
        return false
    }
    is_valid := (computed_hash == VALID_HASH)
    return is_valid
}


new_sm64 :: proc(filepath: string) -> (Sm64, Error) {
    if !validate_hash(filepath) {
        return Sm64{}, Error.InvalidRom
    }
    data, ok := os.read_entire_file(filepath, context.temp_allocator)
    if !ok {
        return Sm64{}, Error.OS_Error
    }

    SM64.texture_data = make_slice([]u8, output.SM64_TEXTURE_WIDTH * output.SM64_TEXTURE_HEIGHT * 4, context.temp_allocator)
    SM64.rom_data = data

    rom_ptr: ^u8
    if len(SM64.rom_data) > 0 {
        rom_ptr = &SM64.rom_data[0]
    } else {
        rom_ptr = nil
    }

    texture_ptr: ^u8
    if len(SM64.texture_data) > 0 {
        texture_ptr = &SM64.texture_data[0]
    } else {
        texture_ptr = nil
    }

    output.sm64_global_init(rom_ptr, texture_ptr)

    return Sm64{global=SM64}, Error.None
}

Texture :: struct {
  data: []u8,
  width: u32,
  height: u32,
}

sm64_mario_texture_atlas :: proc(sm64: Sm64) -> Texture {
  if len(sm64.global.texture_data) == 0 {
    return Texture{
      data = {},
      width = 0,
      height = 0,
    }
  }

  return Texture {
    data = sm64.global.texture_data,
    width = output.SM64_TEXTURE_WIDTH,
    height = output.SM64_TEXTURE_HEIGHT,
  }
}

Vec3 :: struct {
  x: f32,
  y: f32,
  z: f32,
}

Vec2 :: struct {
  x: f32,
  y: f32,
}

Color :: struct {
  r,g,b: f32,
}

LevelTriangle :: struct {
  kind: Surface,
  force: i16,
  terrain: Terrain,
  vertices: [3]Vec3,
}

load_static_surfaces :: proc(level_geometry: []LevelTriangle) {
    native_surfaces := convert_to_sm64_surfaces(level_geometry)
    output.sm64_static_surfaces_load(&native_surfaces[0], u32(len(native_surfaces)))
}

convert_to_sm64_surfaces :: proc(level_geometry: []LevelTriangle) -> []output.SM64Surface {
    count := len(level_geometry)
    native_surfaces := make([]output.SM64Surface, count, context.temp_allocator)

    i: int = 0
    for tri in level_geometry {
        native_surfaces[i] = output.SM64Surface{
            type = i16(tri.kind),
            force = tri.force,
            terrain = u16(tri.terrain),
            vertices = [3][3]i32{
              [3]i32{ i32(tri.vertices[0].x), i32(tri.vertices[0].y), i32(tri.vertices[0].z) },
              [3]i32{ i32(tri.vertices[1].x), i32(tri.vertices[1].y), i32(tri.vertices[1].z) },
              [3]i32{ i32(tri.vertices[2].x), i32(tri.vertices[2].y), i32(tri.vertices[2].z) },
          } 
        }
        i += 1
    }
    i = 0

    return native_surfaces
}

MarioInputs :: struct {
 camLookX, camLookZ:        f32,
 stickX, stickY:            f32,
 buttonA, buttonB, buttonZ: u8,
}

map_mario_inputs :: proc(inputs: MarioInputs) -> output.SM64MarioInputs {
  return output.SM64MarioInputs {
    camLookX = inputs.camLookX,
    camLookZ = inputs.camLookZ,
    stickX = inputs.stickX,
    stickY = inputs.stickY,
    buttonA = inputs.buttonA,
    buttonB = inputs.buttonB,
    buttonZ = inputs.buttonZ
  }
}

MarioGeometry :: struct { 
  position: []Vec3,
  normal: []Vec3,
  color: []Color,
  uv: []Vec2,
  num_triangles: u16,
}

new_mario_geometry :: proc() -> MarioGeometry {
    max_triangles := output.SM64_GEO_MAX_TRIANGLES

    positions := make([]Vec3, max_triangles * 3, context.temp_allocator)
    normals   := make([]Vec3, max_triangles * 3, context.temp_allocator)
    colors    := make([]Color, max_triangles * 3, context.temp_allocator)
    uvs       := make([]Vec2, max_triangles * 3, context.temp_allocator)

    for i := 0; i < len(positions); i += 1 {
      positions[i] = Vec3{0,0,0}
    }
    for i := 0; i < len(normals); i += 1 {
      normals[i] = Vec3{0,0,0}
    }

    return MarioGeometry{
        position = positions,
        normal = normals,
        color = colors,
        uv = uvs,
        num_triangles = 0,
    }
}

mario_geometry_vertices :: proc(geometry: ^MarioGeometry) -> []MarioVertex {
    count := geometry.num_triangles * 3
    result: []MarioVertex = make([]MarioVertex, count, context.temp_allocator)

    for i in 0 ..< count {
        result[i] = MarioVertex{
            position = geometry.position[i],
            normal   = geometry.normal[i],
            color    = geometry.color[i],
            uv       = geometry.uv[i],
        }
    }
    return result
}

Mario :: struct {
  id: i32,
  geometry: MarioGeometry,
}

create_mario :: proc(x: f32, y: f32, z: f32) -> (Mario, Error) {
    mario_id: i32 = output.sm64_mario_create(x, y, z)
    if mario_id < 0 {
        return Mario{}, Error.InvalidMarioPosition
    }
    return Mario {id=mario_id, geometry=new_mario_geometry()}, Error.None
}

SM64GeometryWrapper :: struct {
    positions: []f32,
    normals: []f32,
    colors: []f32,
    uvs: []f32,
    geom: output.SM64MarioGeometryBuffers,
}

new_sm64mariogeometrybuffers :: proc() -> ^SM64GeometryWrapper {
    max_triangles := output.SM64_GEO_MAX_TRIANGLES
    max_vertices := int(max_triangles) * 3
    floats_per_vertex := 3 

    wrapper := new(SM64GeometryWrapper, context.temp_allocator)
    wrapper.positions = make([]f32, max_vertices * floats_per_vertex, context.temp_allocator)
    wrapper.normals   = make([]f32, max_vertices * floats_per_vertex, context.temp_allocator)
    wrapper.colors    = make([]f32, max_vertices * floats_per_vertex, context.temp_allocator)
    wrapper.uvs       = make([]f32, max_vertices * 2, context.temp_allocator)

    wrapper.geom.position = &wrapper.positions[0]
    wrapper.geom.normal   = &wrapper.normals[0]
    wrapper.geom.color    = &wrapper.colors[0]
    wrapper.geom.uv       = &wrapper.uvs[0]
    wrapper.geom.numTrianglesUsed = 0

    return wrapper
}

tick :: proc(mario: ^Mario, input: MarioInputs) -> MarioState {
    input_mapped := map_mario_inputs(input)
    state: output.SM64MarioState = output.SM64MarioState{}
    geometry_wrapper := new_sm64mariogeometrybuffers()
    output.sm64_mario_tick(mario.id, &input_mapped, &state, &geometry_wrapper.geom)

    mario.geometry = sm64_geometry_buffers_to_geometry(geometry_wrapper.geom)
    result := map_mario_state(state)
    return result
}

drop_mario :: proc(mario: Mario) {
  output.sm64_mario_delete(mario.id)
}


DynamicSurface :: struct {
    id: u32,
}

new_dynamic_surface :: proc(id: u32) -> DynamicSurface {
  return DynamicSurface {
    id = id
  }
}

transform_dynamic_surface :: proc(dynamic_surface: DynamicSurface, transform: SurfaceTransform) {
  sm64_transform: output.SM64ObjectTransform = make_sm64_object_transform(transform)
  output.sm64_surface_object_move(dynamic_surface.id,&sm64_transform)
}

drop_dynamic_surface :: proc(dynamic_surface: DynamicSurface) {
  output.sm64_surface_object_delete(dynamic_surface.id)
}

SurfaceTransform :: struct {
    position: Vec3,
    rotation: Vec3,
}

make_sm64_object_transform :: proc(transform: SurfaceTransform) -> output.SM64ObjectTransform {
  position: [3]f32 = [3]f32{f32(transform.position.x), f32(transform.position.y), f32(transform.position.z)}
  rotation: [3]f32 = [3]f32{f32(transform.rotation.x), f32(transform.rotation.y), f32(transform.rotation.z)}
    return output.SM64ObjectTransform{
        position = position,
        eulerRotation = rotation,
    }
}

MarioState :: struct {
  position: Vec3,
  velocity: Vec3,
  face_angle: f32,
  health: i16,
  action: u32,
  flags: u32,
  particle_flags: u32,
  invincibility_timer: i16,
}

int_to_string :: proc(i: int, allocator: mem.Allocator) -> string {
    buf: [32]u8
    slice := strconv.append_int(buf[:], i64(i), 10)
    result, _ := strings.clone(slice, allocator)
    return result
}

format_pos :: proc(state: MarioState, allocator := context.temp_allocator) -> string {
    return fmt.aprintfln("Position: (%v, %v, %v)", state.position.x, state.position.y, state.position.z, allocator=allocator)
}

concat_many :: proc(parts: []string) -> string {
    result, err := strings.concatenate(parts, context.temp_allocator)
    if err != nil {
        panic("concat_many failed")
    }
    return result
}

format_state :: proc(state: MarioState) -> string {
    parts := []string{
        "Action: ", int_to_string(int(state.action), context.temp_allocator), "\n",
        "Health: ", int_to_string(int(state.health), context.temp_allocator), "\n",
        format_pos(state),
    }
    return concat_many(parts)
}

map_mario_state :: proc(state: output.SM64MarioState) -> MarioState {
  return MarioState{
    position = Vec3{
      x = state.position[0],
      y = state.position[1],
      z = state.position[2],
    },
    velocity = Vec3{
      x = state.velocity[0],
      y = state.velocity[1],
      z = state.velocity[2],
    },
    face_angle          = state.faceAngle,
    health              = state.health,
    action              = state.action,
    flags               = state.flags,
    particle_flags      = state.particleFlags,
    invincibility_timer = state.invincTimer,
  }
}

MarioVertex :: struct {
  position: Vec3,
  normal: Vec3,
  color: Color,
  uv: Vec2,
}

mario_vertex_triangles :: proc(geometry: ^MarioGeometry) -> [][3]MarioVertex {
    count := geometry.num_triangles
    result := make([][3]MarioVertex, count, context.temp_allocator)

    for i in 0 ..< count {
        base_idx := i * 3

        result[i][0] = MarioVertex{
            position = geometry.position[base_idx],
            normal   = geometry.normal[base_idx],
            color    = geometry.color[base_idx],
            uv       = geometry.uv[base_idx],
        }
        result[i][1] = MarioVertex{
            position = geometry.position[base_idx + 1],
            normal   = geometry.normal[base_idx + 1],
            color    = geometry.color[base_idx + 1],
            uv       = geometry.uv[base_idx + 1],
        }
        result[i][2] = MarioVertex{
            position = geometry.position[base_idx + 2],
            normal   = geometry.normal[base_idx + 2],
            color    = geometry.color[base_idx + 2],
            uv       = geometry.uv[base_idx + 2],
        }
    }

    return result
}

get_mario_vertice_positions :: proc(geometry: MarioGeometry) -> []Vec3 {
    count := int(geometry.num_triangles) * 3
    return geometry.position[:count]
}

get_mario_vertice_normals :: proc(geometry: MarioGeometry) -> []Vec3 {
    count := int(geometry.num_triangles) * 3
    return geometry.normal[:count]
}

get_mario_vertice_colors :: proc(geometry: MarioGeometry) -> []Color {
    count := int(geometry.num_triangles) * 3
    return geometry.color[:count]
}

get_mario_vertice_uvs :: proc(geometry: MarioGeometry) -> []Vec2 {
    count := int(geometry.num_triangles) * 3
    return geometry.uv[:count]
}

sm64_geometry_buffers_to_geometry :: proc(buffers: output.SM64MarioGeometryBuffers) -> MarioGeometry {
    triangle_count := int(buffers.numTrianglesUsed)
    vertex_count := triangle_count * 3
    positions := make([]Vec3, vertex_count, context.temp_allocator)
    normals   := make([]Vec3, vertex_count, context.temp_allocator)
    colors    := make([]Color, vertex_count, context.temp_allocator)
    uvs       := make([]Vec2, vertex_count, context.temp_allocator)

    mem.copy(&positions[0], buffers.position, vertex_count * size_of(Vec3))
    mem.copy(&normals[0],   buffers.normal,   vertex_count * size_of(Vec3))
    mem.copy(&colors[0],    buffers.color,    vertex_count * size_of(Color))
    mem.copy(&uvs[0],       buffers.uv,       vertex_count * size_of(Vec2))

    return MarioGeometry{
        position      = positions,
        normal        = normals,
        color         = colors,
        uv            = uvs,
        num_triangles = buffers.numTrianglesUsed,
    }
}


Terrain :: enum u16 {
    Grass  = 0x0000,
    Stone  = 0x0001,
    Snow   = 0x0002,
    Sand   = 0x0003,
    Spooky = 0x0004,
    Water  = 0x0005,
    Slide  = 0x0006,
    Mask   = 0x0007,
}

Surface :: enum u16 {
    Default             = 0x0000,
    Burning             = 0x0001,
    _0004               = 0x0004,
    Hangable            = 0x0005,
    Slow                = 0x0009,
    DeathPlane          = 0x000A,
    CloseCamera         = 0x000B,
    Water               = 0x000D,
    FlowingWater        = 0x000E,
    Intangible          = 0x0012,
    VerySlippery        = 0x0013,
    Slippery            = 0x0014,
    NotSlippery         = 0x0015,
    TtmVines            = 0x0016,
    MgrMusic            = 0x001A,
    InstantWarp1b       = 0x001B,
    InstantWarp1c       = 0x001C,
    InstantWarp1d       = 0x001D,
    InstantWarp1e       = 0x001E,
    ShallowQuicksand    = 0x0021,
    DeepQuicksand       = 0x0022,
    InstantQuicksand    = 0x0023,
    DeepMovingQuicksand = 0x0024,
    ShallowMovingQuicksand = 0x0025,
    Quicksand           = 0x0026,
    MovingQuicksand     = 0x0027,
    WallMisc            = 0x0028,
    NoiseDefault        = 0x0029,
    NoiseSlippery       = 0x002A,
    HorizontalWind      = 0x002C,
    InstantMovingQuicksand = 0x002D,
    Ice                 = 0x002E,
    LookUpWarp          = 0x002F,
    Hard                = 0x0030,
    Warp                = 0x0032,
    TimerStart          = 0x0033,
    TimerEnd            = 0x0034,
    HardSlippery        = 0x0035,
    HardVerySlippery    = 0x0036,
    HardNotSlippery     = 0x0037,
    VerticalWind        = 0x0038,
    BossFightCamera     = 0x0065,
    CameraFreeRoam      = 0x0066,
    Thi3Wallkick        = 0x0068,
    CameraPlatform      = 0x0069,
    CameraMiddle        = 0x006E,
    CameraRotateRight   = 0x006F,
    CameraRotateLeft    = 0x0070,
    CameraBoundary      = 0x0072,
    NoiseVerySlippery73 = 0x0073,
    NoiseVerySlippery74 = 0x0074,
    NoiseVerySlippery   = 0x0075,
    NoCamCollision      = 0x0076,
    NoCamCollision77    = 0x0077,
    NoCamColVerySlippery= 0x0078,
    NoCamColSlippery    = 0x0079,
    Switch              = 0x007A,
    VanishCapWalls      = 0x007B,
    PaintingWobbleA6    = 0x00A6,
    PaintingWobbleA7    = 0x00A7,
    PaintingWobbleA8    = 0x00A8,
    PaintingWobbleA9    = 0x00A9,
    PaintingWobbleAA    = 0x00AA,
    PaintingWobbleAB    = 0x00AB,
    PaintingWobbleAC    = 0x00AC,
    PaintingWobbleAD    = 0x00AD,
    PaintingWobbleAE    = 0x00AE,
    PaintingWobbleAF    = 0x00AF,
    PaintingWobbleB0    = 0x00B0,
    PaintingWobbleB1    = 0x00B1,
    PaintingWobbleB2    = 0x00B2,
    PaintingWobbleB3    = 0x00B3,
    PaintingWobbleB4    = 0x00B4,
    PaintingWobbleB5    = 0x00B5,
    PaintingWobbleB6    = 0x00B6,
    PaintingWobbleB7    = 0x00B7,
    PaintingWobbleB8    = 0x00B8,
    PaintingWobbleB9    = 0x00B9,
    PaintingWobbleBA    = 0x00BA,
    PaintingWobbleBB    = 0x00BB,
    PaintingWobbleBC    = 0x00BC,
    PaintingWobbleBD    = 0x00BD,
    PaintingWobbleBE    = 0x00BE,
    PaintingWobbleBF    = 0x00BF,
    PaintingWobbleC0    = 0x00C0,
    PaintingWobbleC1    = 0x00C1,
    PaintingWobbleC2    = 0x00C2,
    PaintingWobbleC3    = 0x00C3,
    PaintingWobbleC4    = 0x00C4,
    PaintingWobbleC5    = 0x00C5,
    PaintingWobbleC6    = 0x00C6,
    PaintingWobbleC7    = 0x00C7,
    PaintingWobbleC8    = 0x00C8,
    PaintingWobbleC9    = 0x00C9,
    PaintingWobbleCA    = 0x00CA,
    PaintingWobbleCB    = 0x00CB,
    PaintingWobbleCC    = 0x00CC,
    PaintingWobbleCD    = 0x00CD,
    PaintingWobbleCE    = 0x00CE,
    PaintingWobbleCF    = 0x00CF,
    PaintingWobbleD0    = 0x00D0,
    PaintingWobbleD1    = 0x00D1,
    PaintingWobbleD2    = 0x00D2,
    PaintingWarpD3      = 0x00D3,
    PaintingWarpD4      = 0x00D4,
    PaintingWarpD5      = 0x00D5,
    PaintingWarpD6      = 0x00D6,
    PaintingWarpD7      = 0x00D7,
    PaintingWarpD8      = 0x00D8,
    PaintingWarpD9      = 0x00D9,
    PaintingWarpDA      = 0x00DA,
    PaintingWarpDB      = 0x00DB,
    PaintingWarpDC      = 0x00DC,
    PaintingWarpDD      = 0x00DD,
    PaintingWarpDE      = 0x00DE,
    PaintingWarpDF      = 0x00DF,
    PaintingWarpE0      = 0x00E0,
    PaintingWarpE1      = 0x00E1,
    PaintingWarpE2      = 0x00E2,
    PaintingWarpE3      = 0x00E3,
    PaintingWarpE4      = 0x00E4,
    PaintingWarpE5      = 0x00E5,
    PaintingWarpE6      = 0x00E6,
    PaintingWarpE7      = 0x00E7,
    PaintingWarpE8      = 0x00E8,
    PaintingWarpE9      = 0x00E9,
    PaintingWarpEA      = 0x00EA,
    PaintingWarpEB      = 0x00EB,
    PaintingWarpEC      = 0x00EC,
    PaintingWarpED      = 0x00ED,
    PaintingWarpEE      = 0x00EE,
    PaintingWarpEF      = 0x00EF,
    PaintingWarpF0      = 0x00F0,
    PaintingWarpF1      = 0x00F1,
    PaintingWarpF2      = 0x00F2,
    PaintingWarpF3      = 0x00F3,
    TtcPainting1        = 0x00F4,
    TtcPainting2        = 0x00F5,
    TtcPainting3        = 0x00F6,
    PaintingWarpF7      = 0x00F7,
    PaintingWarpF8      = 0x00F8,
    PaintingWarpF9      = 0x00F9,
    PaintingWarpFA      = 0x00FA,
    PaintingWarpFB      = 0x00FB,
    PaintingWarpFC      = 0x00FC,
    WobblingWarp        = 0x00FD,
    Trapdoor            = 0x00FF,
}

