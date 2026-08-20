---
name: dragonruby-rendering
description: Advanced DragonRuby GTK rendering — render targets, pixel arrays, HD/lowrez resolution, thick lines, blendmodes, tiling textures. Use when the user asks about advanced visual effects or rendering performance.
---

This skill covers advanced rendering patterns in DragonRuby GTK. For basic sprite/label/solid output see the main `dragonruby` skill.

## Render Targets (Off-screen Buffers)

Render targets let you draw into a named virtual canvas, then use it as a sprite. They are very powerful for caching, effects, and UI composition.

```ruby
# Draw into target each tick (transient! clears it each frame):
args.outputs[:hud].transient!
args.outputs[:hud].width  = 400
args.outputs[:hud].height = 200
args.outputs[:hud].background_color = [0, 0, 0, 0]  # transparent bg
args.outputs[:hud].sprites << { x: 0, y: 0, w: 32, h: 32, path: 'sprites/icon.png' }
args.outputs[:hud].labels  << { x: 200, y: 100, text: "HP: 3", alignment_enum: 1 }

# Composite into the main scene:
args.outputs.sprites << { x: 0, y: 520, w: 400, h: 200, path: :hud }
```

### Cached render target (draw once, reuse)
```ruby
# Build the target only on tick 0 (or when content changes):
if Kernel.tick_count == 0
  args.outputs[:map_tiles].width  = 2560
  args.outputs[:map_tiles].height = 1440
  world_tiles.each { |t| args.outputs[:map_tiles].sprites << t }
end

# Render a viewport portion of the cached target each tick:
args.outputs.sprites << {
  x: 0, y: 0, w: 1280, h: 720,
  path: :map_tiles,
  source_x: cam.x, source_y: cam.y,
  source_w: 1280, source_h: 720
}
```

### Checking target readiness
```ruby
return if args.outputs.render_targets.queued?(:my_target)
return unless args.outputs.render_targets.ready?(:my_target)
```

## Blendmodes & Clipping

```ruby
# Blendmode 0 = ignore alpha (overwrite). Use for hollow borders:
args.outputs[:border_target].primitives << [
  { x: 0, y: 0, w: w, h: h, path: :solid, r: 255, g: 255, b: 255 },
  { x: t, y: t, w: w - t*2, h: h - t*2, path: :empty, blendmode: 0 }
]
```

### Clipping (viewport mask)
```ruby
args.outputs[:clipped].width  = clip_w
args.outputs[:clipped].height = clip_h
args.outputs[:clipped].sprites << all_world_sprites

args.outputs.sprites << {
  x: clip_x, y: clip_y, w: clip_w, h: clip_h,
  path: :clipped,
  source_x: clip_x, source_y: clip_y,
  source_w: clip_w, source_h: clip_h
}
```

## Pixel Arrays

Direct pixel-level manipulation for dynamic textures:

```ruby
# Create a pixel array (ABGR 32-bit integers):
w = 64; h = 64
args.pixel_array(:canvas).width  = w
args.pixel_array(:canvas).height = h

# Fill solid black:
args.pixel_array(:canvas).pixels.fill(0xFF000000, 0, w * h)

# Draw a horizontal green line at row y:
y = 32
args.pixel_array(:canvas).pixels.fill(0xFF00FF00, y * w, w)

# Set individual pixel (x, y):
def set_pixel(px_array, w, x, y, abgr)
  px_array.pixels[y * w + x] = abgr
end

# ABGR hex format: 0xAABBGGRR
RED   = 0xFF0000FF
GREEN = 0xFF00FF00
BLUE  = 0xFFFF0000

# Animate pixel-by-pixel scanner:
args.state.scan_pos = (args.state.scan_pos || 0 + 1) % h
args.pixel_array(:scanner).width  = w
args.pixel_array(:scanner).height = h
args.pixel_array(:scanner).pixels.fill(0xFF000000, 0, w * h)
args.pixel_array(:scanner).pixels.fill(0xFF00FF00, args.state.scan_pos * w, w)

# Use pixel array as a sprite:
args.outputs.sprites << { x: 100, y: 100, w: w, h: h, path: :canvas }
```

### Load pixels from a file
```ruby
px = GTK.get_pixels('sprites/map.png')  # => { w:, h:, pixels: [] }
args.pixel_array(:map).width  = px.w
args.pixel_array(:map).height = px.h
args.pixel_array(:map).pixels = px.pixels
```

## HD & High-DPI Rendering

### Automatic HD sprite selection

DragonRuby automatically picks the right resolution file by naming convention:
- 720p:  `player.png`
- 1080p: `player@125.png`
- 1440p: `player@200.png`
- 4K:    `player@300.png`

No code changes needed — just provide the additional files.

```ruby
# Query current rendering scale at runtime:
args.grid.texture_scale_enum  # integer scale enum
args.grid.native_scale        # float scale multiplier
```

### Allscreen properties (ultrawide/notch support)

```ruby
args.grid.allscreen_w         # full renderable width (beyond safe area)
args.grid.allscreen_h
args.grid.allscreen_offset_x  # offset from left to safe area
args.grid.left                # safe area left edge
args.grid.right               # safe area right edge

# Background that fills to screen edges:
args.outputs.sprites << {
  x: args.grid.allscreen_left,
  y: args.grid.allscreen_bottom,
  w: args.grid.allscreen_w,
  h: args.grid.allscreen_h,
  path: 'sprites/bg.png',
  source_x: 2000 - args.grid.allscreen_w / 2,
  source_y: 2000 - args.grid.allscreen_h / 2,
  source_w: args.grid.allscreen_w,
  source_h: args.grid.allscreen_h
}
```

## Low-Resolution (Pixel Art) Display

Scale a tiny virtual canvas up to fill the screen — classic for pixel art games:

```ruby
GAME_W = 84; GAME_H = 48   # virtual resolution (e.g. Nokia 3310)
SCREEN_W = 1280; SCREEN_H = 720
ZOOM = [SCREEN_W / GAME_W, SCREEN_H / GAME_H].min
OFFSET_X = (SCREEN_W - GAME_W * ZOOM) / 2
OFFSET_Y = (SCREEN_H - GAME_H * ZOOM) / 2

def tick(args)
  # Draw at native resolution into target:
  args.outputs[:game].transient!
  args.outputs[:game].width  = GAME_W
  args.outputs[:game].height = GAME_H
  args.outputs[:game].background_color = [199, 240, 216]
  # ... all game rendering goes here at GAME_W x GAME_H coords

  # Scale up to screen:
  args.outputs.sprites << {
    x: OFFSET_X, y: OFFSET_Y,
    w: GAME_W * ZOOM, h: GAME_H * ZOOM,
    path: :game
  }
end

# Translate mouse input from screen space back to game space:
def game_mouse(args)
  { x: (args.inputs.mouse.x - OFFSET_X).idiv(ZOOM),
    y: (args.inputs.mouse.y - OFFSET_Y).idiv(ZOOM) }
end
```

## Thick Lines

DragonRuby only draws 1px lines natively. Emulate thick lines with a rotated solid:

```ruby
def thick_line(x:, y:, x2:, y2:, thickness: 3, r: 255, g: 255, b: 255, a: 255)
  dx = x2 - x; dy = y2 - y
  length = Math.sqrt(dx*dx + dy*dy)
  angle  = Math.atan2(dy, dx).to_degrees
  {
    x: x, y: y,
    w: length, h: thickness,
    angle: angle, angle_anchor_x: 0, angle_anchor_y: 0.5,
    path: :solid,
    r: r, g: g, b: b, a: a
  }
end

args.outputs.sprites << thick_line(x: 100, y: 100, x2: 400, y2: 300, thickness: 4)
```

## Repeating / Tiled Textures

```ruby
def tiled_background(args, path, dest_x:, dest_y:, dest_w:, dest_h:)
  sw, sh = args.gtk.calcspritebox(path)
  rt_name = :"tile_#{path}"
  if Kernel.tick_count == 0
    args.outputs[rt_name].width  = dest_w
    args.outputs[rt_name].height = dest_h
    cols = (dest_w.fdiv(sw)).ceil + 1
    rows = (dest_h.fdiv(sh)).ceil + 1
    args.outputs[rt_name].sprites << rows.map { |r|
      cols.map { |c|
        { x: c * sw, y: dest_h - (r + 1) * sh, w: sw, h: sh, path: path }
      }
    }
  end
  { x: dest_x, y: dest_y, w: dest_w, h: dest_h, path: rt_name }
end

args.outputs.sprites << tiled_background(args, 'sprites/grass.png',
                                          dest_x: 0, dest_y: 0,
                                          dest_w: 1280, dest_h: 720)
```

## Coordinate System Origin Switching

```ruby
args.grid.origin_center!        # (0,0) at screen centre
args.grid.origin_bottom_left!   # (0,0) at bottom-left (default)
```

Render targets inherit the current origin mode.

## Tile-Based Large Maps

Only load the 9 tiles surrounding the player's position (3×3 grid of chunks):

```ruby
CHUNK = 640
chunk_x = player.x.idiv(CHUNK)
chunk_y = player.y.idiv(CHUNK)
offset_x = 960 - (player.x - chunk_x * CHUNK)
offset_y = 960 - (player.y - chunk_y * CHUNK)

(-1..1).each do |cx|
  (-1..1).each do |cy|
    path = :"chunk_#{chunk_x + cx}_#{chunk_y + cy}"
    args.outputs.sprites << {
      x: offset_x + cx * CHUNK,
      y: offset_y + cy * CHUNK,
      w: CHUNK, h: CHUNK,
      path: path
    }
  end
end
```

## Screenshots

```ruby
args.outputs.screenshots << {
  filename: "screenshots/shot_#{Kernel.tick_count}.png",
  x: 0, y: 0, w: 1280, h: 720,
  chroma_key: { r: 0, g: 255, b: 0 }   # optional: make green transparent
}
```

## Static Sprites for Performance

```ruby
# Add once; objects are held by reference and mutated in place:
if Kernel.tick_count == 0
  args.state.stars = 500.map { { x: rand(1280), y: rand(720), w: 2, h: 2, path: :solid, r: 255, g: 255, b: 255 } }
  args.outputs.static_sprites << args.state.stars
end

# Update positions without re-adding:
args.state.stars.each { |s| s[:x] = (s[:x] + 0.5) % 1280 }
```

## Shaders (Indie/Pro)

```ruby
args.outputs.sprites << {
  x: 0, y: 0, w: 1280, h: 720,
  path: 'sprites/scene.png',
  shader: 'shaders/scanlines.glsl',
  shader_tex1: :render_target_name,
  # Uniforms:
  shader_u_time: Kernel.tick_count / 60.0
}
```
