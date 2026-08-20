---
name: dragonruby-3d
description: 3D graphics techniques in DragonRuby GTK — raycasting, Mode7 floor projection, matrix transformations, wireframe rendering, sprite-based 3D, VR patterns. Use when the user asks about 3D visuals or pseudo-3D effects.
---

DragonRuby is a 2D engine but supports several pseudo-3D and true 3D techniques.

## Sprite-Based 3D (VR / Cube Style)

Build 3D objects from six 2D sprites with x/y/z positioning and angle_x/angle_y rotation:

```ruby
def cube(x:, y:, z:, size:, sprite:)
  half = size / 2
  [
    { x: x,    y: y,    z: z,        w: size, h: size, **sprite },         # front
    { x: x,    y: y,    z: z + size, w: size, h: size, **sprite },         # back
    { x: x,    y: y + half, z: z + half, w: size, h: size, angle_x: 90, **sprite },  # top
    { x: x,    y: y - half, z: z + half, w: size, h: size, angle_x: 90, **sprite },  # bottom
    { x: x - half, y: y, z: z + half, w: size, h: size, angle_y: 90, **sprite },    # left
    { x: x + half, y: y, z: z + half, w: size, h: size, angle_y: 90, **sprite }     # right
  ]
end

sprite_base = { path: 'sprites/square/white.png', r: 200, g: 200, b: 200 }
args.outputs.sprites << cube(x: 0, y: 0, z: 100, size: 64, sprite: sprite_base)
```

Z-layer ordering for depth:
```ruby
args.outputs.sprites << args.state.cubes
  .sort_by { |c| -c[:z] }   # far-to-near for correct overdraw
  .flat_map { |c| cube(**c) }
```

## Matrix Math

### 4×4 matrix helpers

```ruby
def mat4(*values)
  values.each_slice(4).to_a
end

def translate(dx, dy, dz)
  mat4  1, 0, 0, dx,
        0, 1, 0, dy,
        0, 0, 1, dz,
        0, 0, 0,  1
end

def scale(sx, sy, sz)
  mat4 sx,  0,  0, 0,
        0, sy,  0, 0,
        0,  0, sz, 0,
        0,  0,  0, 1
end

def rotate_x(deg)
  c = Math.cos(deg.to_radians); s = Math.sin(deg.to_radians)
  mat4  1,  0,  0, 0,
        0,  c, -s, 0,
        0,  s,  c, 0,
        0,  0,  0, 1
end

def rotate_y(deg)
  c = Math.cos(deg.to_radians); s = Math.sin(deg.to_radians)
  mat4  c,  0, s, 0,
        0,  1, 0, 0,
       -s,  0, c, 0,
        0,  0, 0, 1
end

def rotate_z(deg)
  c = Math.cos(deg.to_radians); s = Math.sin(deg.to_radians)
  mat4 c, -s, 0, 0,
       s,  c, 0, 0,
       0,  0, 1, 0,
       0,  0, 0, 1
end

def mul_mat4(a, b)
  (0..3).map { |i| (0..3).map { |j| (0..3).sum { |k| a[i][k] * b[k][j] } } }
end

def mul_vec4(m, v)
  (0..3).map { |i| (0..3).sum { |k| m[i][k] * v[k] } }
end
```

### Transform a mesh

```ruby
def mul_triangles(triangles, *matrices)
  transform = matrices.reduce { |a, b| mul_mat4(a, b) }
  triangles.map { |verts| verts.map { |v| mul_vec4(transform, v) } }
end

# Yaw-pitch-roll camera:
model_mat = mul_mat4(rotate_y(yaw), mul_mat4(rotate_x(pitch), rotate_z(roll)))
transformed = mul_triangles(mesh, model_mat)
```

### Triangle rendering
```ruby
# Project a triangle vertex to screen space:
def project(v, fov: 500)
  z = v[2].nonzero? || 0.001
  { x: 640 + v[0] * fov / z,
    y: 360 + v[1] * fov / z }
end

# Render a textured triangle:
a, b, c = triangle.map { |v| project(v) }
args.outputs.sprites << {
  x: a[:x], y: a[:y], x2: b[:x], y2: b[:y], x3: c[:x], y3: c[:y],
  source_x: 0, source_y: 0,
  source_x2: 80, source_y2: 0,
  source_x3: 0, source_y3: 80,
  path: 'sprites/tex.png'
}
```

## Raycasting (Wolfenstein-style)

### DDA raycast

```ruby
MAP_W = 16; MAP_H = 16
NUM_RAYS = 120
SCREEN_W = 1280; SCREEN_H = 720

def cast_ray(map, px, py, angle)
  rad = angle.to_radians
  dir_x = Math.cos(rad); dir_y = Math.sin(rad)

  map_x = px.to_i; map_y = py.to_i
  step_x = dir_x > 0 ? 1 : -1
  step_y = dir_y > 0 ? 1 : -1
  delta_x = dir_x == 0 ? Float::INFINITY : (1.0 / dir_x).abs
  delta_y = dir_y == 0 ? Float::INFINITY : (1.0 / dir_y).abs
  side_x  = dir_x < 0 ? (px - map_x) * delta_x : (map_x + 1 - px) * delta_x
  side_y  = dir_y < 0 ? (py - map_y) * delta_y : (map_y + 1 - py) * delta_y

  hit_side = nil
  64.times do
    if side_x < side_y
      side_x += delta_x; map_x += step_x; hit_side = :vertical
    else
      side_y += delta_y; map_y += step_y; hit_side = :horizontal
    end
    break if map[map_y] && map[map_y][map_x] == 1
  end

  dist = hit_side == :vertical ? (side_x - delta_x) : (side_y - delta_y)
  { dist: dist, side: hit_side, map_x: map_x, map_y: map_y }
end
```

### Wall column rendering

```ruby
def render_walls(args, player, map)
  fov = 60.0
  ray_step = fov / NUM_RAYS
  col_w = SCREEN_W.fdiv(NUM_RAYS).ceil

  NUM_RAYS.times do |i|
    angle = player.angle - fov / 2 + i * ray_step
    hit   = cast_ray(map, player.x, player.y, angle)
    next if hit[:dist] <= 0

    wall_h = (SCREEN_H / hit[:dist]).clamp(0, SCREEN_H)
    bright = (1.0 - (hit[:dist] / 16.0)).clamp(0, 1)
    shade  = hit[:side] == :vertical ? bright : bright * 0.7
    c = (shade * 200).to_i

    args.outputs[:screen].solids << {
      x: i * col_w,
      y: (SCREEN_H - wall_h) / 2,
      w: col_w, h: wall_h,
      r: c, g: c, b: c
    }
  end
end
```

### Depth buffer for sprite occlusion

```ruby
depths = Array.new(NUM_RAYS, Float::INFINITY)

NUM_RAYS.times do |i|
  hit = cast_ray(...)
  depths[i] = hit[:dist]
end

# When rendering sprites, check depth:
screen_x_col = (sprite_screen_x / (SCREEN_W.fdiv(NUM_RAYS))).round
if sprite_dist < (depths[screen_x_col] || Float::INFINITY)
  # Sprite is in front of wall — render it
end
```

### Inverse-square lighting

```ruby
light_range = 8.0
brightness = 1.0 - (dist / light_range) ** 2
brightness = brightness.clamp(0, 1)
c = (brightness * 255).to_i
```

## Mode7 (Floor/Ceiling Projection)

Classic SNES-style affine texture mapping:

```ruby
def render_mode7(args, cam_x:, cam_y:, cam_angle:, horizon: 360, fov: 1.0)
  floor_path = 'sprites/floor.png'
  floor_w, floor_h = args.gtk.calcspritebox(floor_path)

  (0...horizon).each do |screen_y|
    z_ratio = ((horizon - screen_y) * 100.0) / (horizon - screen_y + 1)
    next if z_ratio >= 2048

    row_width = (z_ratio * fov).to_i
    start_x   = cam_x - row_width / 2
    start_y   = cam_y + z_ratio

    args.outputs[:floor].sprites << {
      x: 0, y: screen_y, w: SCREEN_W, h: 1,
      path: floor_path,
      source_x: (start_x % floor_w).to_i,
      source_y: (start_y % floor_h).to_i,
      source_w: row_width, source_h: 1
    }
  end

  args.outputs.sprites << { x: 0, y: 0, w: SCREEN_W, h: SCREEN_H, path: :floor }
end
```

### Mode7 sprite projection

```ruby
def project_sprite_mode7(cam_x, cam_y, cam_angle, sprite_wx, sprite_wy)
  rel_x  = sprite_wx - cam_x
  rel_y  = sprite_wy - cam_y
  inv_det = 1.0 / (cam_angle.cos_r * 1 - cam_angle.sin_r * 1)
  tx = inv_det * (rel_x - cam_angle.sin_r * rel_y)
  ty = inv_det * (-cam_angle.sin_r * rel_x + cam_angle.cos_r * rel_y)
  screen_x = (SCREEN_W / 2) * (1 + tx / ty)
  screen_y = (SCREEN_H / 2) * (1 - 1.0 / ty)
  { x: screen_x, y: screen_y, scale: 1.0 / ty }
end
```

## Wireframe from .OFF Files

```ruby
def load_off(path)
  lines = GTK.read_file(path)
    .split("\n")
    .reject { |l| l.start_with?('#') || l.strip.empty? }
    .map { |l| l.split('#')[0].split(' ') }

  raise "Not an OFF file" unless lines.shift == ["OFF"]
  vert_count, face_count, _ = lines.shift.map(&:to_i)

  verts = vert_count.map { lines.shift.map(&:to_f) }
  faces = face_count.map { lines.shift.map(&:to_i)[1..] }

  edges = faces.flat_map { |f| f.each_cons(2).map { |a, b| [a, b].sort } }
    .uniq
    .map { |a, b| [verts[a], verts[b]] }

  { verts: verts, faces: faces, edges: edges }
end

def render_wireframe(args, mesh, transform)
  mesh[:edges].each do |v0, v1|
    a = project_vertex(mul_vec4(transform, v0 + [1]))
    b = project_vertex(mul_vec4(transform, v1 + [1]))
    args.outputs.lines << { x: a[:x], y: a[:y], x2: b[:x], y2: b[:y], r: 0, g: 255, b: 0 }
  end
end
```

## Depth Sorting (Back-to-Front)

```ruby
# For sprite-based 3D, sort entities by distance from camera:
args.state.entities
  .sort_by { |e| -Geometry.distance(camera, e) }
  .each { |e| args.outputs.sprites << render_entity(e, camera) }
```

## Random Points on a Sphere (procedural generation)

```ruby
def random_sphere_point
  loop do
    p = { x: rand * 2 - 1, y: rand * 2 - 1, z: rand * 2 - 1 }
    return p if p[:x]**2 + p[:y]**2 + p[:z]**2 <= 1.0
  end
end
```

