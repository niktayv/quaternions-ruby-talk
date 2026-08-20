---
name: dragonruby-platformer
description: Platformer game patterns in DragonRuby GTK — physics, gravity, jumping, AABB collision resolution, action state machines, sprite animation, moving platforms, combo inputs. Use when building platformers, action games, or side-scrollers.
---

This skill covers platformer-specific patterns. For core DragonRuby API see the main `dragonruby` skill; for render targets see `/dragonruby-rendering`.

## Physics Model

```ruby
GRAVITY      = -0.4
MAX_FALL     = -15
MOVE_SPEED   =  4
ACCELERATION =  0.8
FRICTION     =  0.85
JUMP_POWER   = 12

def defaults_player(args)
  args.state.player ||= {
    x: 200, y: 200, w: 32, h: 48,
    dx: 0, dy: 0,
    on_ground: false,
    facing: 1,         # 1 = right, -1 = left
    action: :standing,
    action_at: 0
  }
end

def calc_physics(args)
  p = args.state.player

  # Gravity
  p.dy = (p.dy + GRAVITY).clamp(MAX_FALL, JUMP_POWER)

  # Horizontal movement
  lr = args.inputs.left_right
  if lr != 0
    p.dx += lr * ACCELERATION
    p.dx  = p.dx.clamp(-MOVE_SPEED, MOVE_SPEED)
    p.facing = lr
  else
    p.dx *= FRICTION
    p.dx  = 0 if p.dx.abs < 0.3
  end

  # Resolve X
  p.x += p.dx
  resolve_horizontal_collisions(args)

  # Resolve Y
  p.y += p.dy
  p.on_ground = false
  resolve_vertical_collisions(args)
end
```

## AABB Collision Resolution (Axis-Separated)

Always resolve X and Y separately to allow wall-sliding and ceiling bumps:

```ruby
def resolve_horizontal_collisions(args)
  p = args.state.player
  col = args.state.terrain.find { |t| p.intersect_rect?(t) }
  return unless col

  if p.dx > 0
    p.x  = col.x - p.w
  elsif p.dx < 0
    p.x  = col.x + col.w
  end
  p.dx = 0
end

def resolve_vertical_collisions(args)
  p = args.state.player
  col = args.state.terrain.find { |t| p.intersect_rect?(t) }
  return unless col

  if p.dy < 0   # falling
    p.y         = col.y + col.h
    p.on_ground = true
  elsif p.dy > 0   # rising (hit ceiling)
    p.y = col.y - p.h
  end
  p.dy = 0
end
```

### Separate collision rects for per-side detection

```ruby
def player_collision_rects(p)
  {
    body:   { x: p.x + 2,  y: p.y + 2,  w: p.w - 4,  h: p.h - 4 },
    bottom: { x: p.x + 4,  y: p.y - 2,  w: p.w - 8,  h: 4 },
    left:   { x: p.x - 2,  y: p.y + 4,  w: 4,         h: p.h - 8 },
    right:  { x: p.x + p.w - 2, y: p.y + 4, w: 4, h: p.h - 8 }
  }
end
```

## Variable-Height Jumping

Hold jump for higher; tap for small hop:

```ruby
JUMP_FRAMES = 12   # max frames of upward push

def calc_jump(args)
  p = args.state.player

  # Press to start jump:
  if (args.inputs.keyboard.key_down.space || args.inputs.controller_one.key_down.a) &&
     p.on_ground
    p.dy       = JUMP_POWER
    p.jump_at  = Kernel.tick_count
    p.jumping  = true
    p.on_ground = false
    p.action   = :jumping
    p.action_at = Kernel.tick_count
  end

  # Hold to continue boosting:
  if p.jumping && p.jump_at.elapsed_time < JUMP_FRAMES &&
     (args.inputs.keyboard.key_held.space || args.inputs.controller_one.key_held.a)
    p.dy = JUMP_POWER - (JUMP_POWER * p.jump_at.elapsed_time / JUMP_FRAMES.to_f)
  end

  # Stop boosting on release:
  if p.jumping && (args.inputs.keyboard.key_up.space || args.inputs.controller_one.key_up.a)
    p.jumping = false
    p.dy = p.dy.lesser(0) if p.dy > 0
  end

  p.jumping = false if p.on_ground
end
```

## Double Jump / Coyote Time

```ruby
COYOTE_FRAMES = 8   # grace period after walking off ledge

def calc_jump_extended(args)
  p = args.state.player

  # Track when we last left the ground:
  if p.on_ground
    p.jump_count = 0
    p.left_ground_at = Kernel.tick_count
  end

  coyote_ok = p.left_ground_at.elapsed_time <= COYOTE_FRAMES

  pressed = args.inputs.keyboard.key_down.space ||
            args.inputs.controller_one.key_down.a

  if pressed && (p.on_ground || coyote_ok || p.jump_count < 2)
    p.dy = JUMP_POWER
    p.jump_count += 1
    p.jumping = true
  end
end
```

## Action State Machine

Track what the player is doing for animation and logic:

```ruby
ACTIONS = {
  standing: { sprites: 1,  hold: 8,  loop: true  },
  running:  { sprites: 6,  hold: 5,  loop: true  },
  jumping:  { sprites: 1,  hold: 1,  loop: false },
  falling:  { sprites: 1,  hold: 1,  loop: false },
  attacking:{ sprites: 5,  hold: 4,  loop: false }
}

def calc_action(args)
  p = args.state.player
  new_action = if p.action == :attacking && !p.action_at.elapsed?(ACTIONS[:attacking][:sprites] * ACTIONS[:attacking][:hold])
    :attacking
  elsif !p.on_ground && p.dy < 0
    :falling
  elsif !p.on_ground
    :jumping
  elsif p.dx.abs > 0.5
    :running
  else
    :standing
  end

  if new_action != p.action
    p.action    = new_action
    p.action_at = Kernel.tick_count
  end
end

def render_player(args)
  p = args.state.player
  cfg = ACTIONS[p.action]
  frame = p.action_at.frame_index(frame_count: cfg[:sprites],
                                   hold_each_frame_for: cfg[:hold],
                                   repeat: cfg[:loop])
  frame ||= cfg[:sprites] - 1   # hold last frame when non-looping finishes
  path = "sprites/player/#{p.action}_#{frame}.png"

  args.outputs.sprites << {
    x: p.x, y: p.y, w: p.w, h: p.h,
    path: path,
    flip_horizontally: p.facing < 0
  }
end
```

## Moving Platforms

```ruby
def calc_platforms(args)
  args.state.platforms.each do |plat|
    # Move platform back and forth:
    plat.x += plat.dx * plat.speed
    if plat.x > plat.max_x || plat.x < plat.min_x
      plat.dx *= -1
    end

    # Carry the player if standing on it:
    if args.state.player.on_ground
      col = args.state.platforms.find { |pl| args.state.player.intersect_rect?(pl) }
      args.state.player.x += col.dx * col.speed if col
    end
  end
end
```

## Attack Hitbox Window

Damage is only dealt on a specific animation frame:

```ruby
ATTACK_FRAME    = 3
ATTACK_HOLD     = 4   # frames per sprite

def calc_attack(args)
  p = args.state.player
  return unless p.action == :attacking

  frame = p.action_at.frame_index(frame_count: 5, hold_each_frame_for: ATTACK_HOLD, repeat: false)
  return unless frame == ATTACK_FRAME && p.action_at.elapsed_time == ATTACK_FRAME * ATTACK_HOLD

  hit_box = { x: p.x + p.facing * p.w, y: p.y + 8, w: 32, h: 32 }
  args.state.enemies.each do |e|
    next unless Geometry.intersect_rect?(hit_box, e)
    e.hp -= 1
    # Push-back:
    e.dx = p.facing * 5
    e.dy = 3
  end
end
```

## Special Move / Combo Detection

Buffer recent inputs and check sequences within a time window:

```ruby
INPUT_BUFFER_SIZE = 8
COMBO_WINDOW      = 20   # ticks

def record_input(args, key)
  args.state.input_buffer ||= []
  args.state.input_buffer.unshift({ key: key, at: Kernel.tick_count })
  args.state.input_buffer = args.state.input_buffer.first(INPUT_BUFFER_SIZE)
end

def combo_detected?(args, sequence)
  buf = args.state.input_buffer
  return false if buf.length < sequence.length
  return false if Kernel.tick_count - buf.first[:at] > COMBO_WINDOW

  buf.first(sequence.length).map { |e| e[:key] } == sequence
end

# In input handler:
if args.inputs.keyboard.key_down.right
  record_input(args, :right)
end
if combo_detected?(args, [:right, :right])
  trigger_dash(args)
end
```

## Particle Trail Effect

```ruby
def spawn_run_dust(args, player)
  return unless player.on_ground && player.dx.abs > 1
  args.state.particles << {
    x: player.x + rand(player.w), y: player.y,
    w: 8, h: 8, a: 180,
    dx: -player.dx * 0.3 + rand * 2 - 1,
    dy: rand * 2,
    path: :solid, r: 180, g: 160, b: 120
  }
end
```

## Boundary Handling

```ruby
def clamp_to_world(args)
  p = args.state.player
  p.x = p.x.clamp(0, args.state.world_w - p.w)
  # Fall off bottom = die:
  if p.y < -p.h * 2
    respawn(args)
  end
end
```

## Level Data Format

Simple CSV for terrain (save/load from files):

```ruby
def write_terrain(args)
  csv = args.state.terrain.map { |t| "#{t.x},#{t.y},#{t.w},#{t.h}" }.join("\n")
  GTK.write_file('data/level_01.txt', csv)
end

def load_terrain(path)
  raw = GTK.read_file(path)
  return [] unless raw
  raw.split("\n").map do |line|
    x, y, w, h = line.split(',').map(&:to_i)
    { x: x, y: y, w: w, h: h, path: 'sprites/tile.png' }
  end
end
```

## Grid-Snapped Level Editor (in-game)

```ruby
TILE = 32

def tick_editor(args)
  mx = args.inputs.mouse.x.idiv(TILE) * TILE
  my = args.inputs.mouse.y.idiv(TILE) * TILE
  ghost = { x: mx, y: my, w: TILE, h: TILE }

  args.outputs.borders << ghost.merge(r: 255, g: 255, b: 0)

  if args.inputs.mouse.button_left
    args.state.terrain << ghost.merge(path: 'sprites/tile.png') unless
      args.state.terrain.any? { |t| t.x == mx && t.y == my }
  end

  if args.inputs.mouse.button_right
    args.state.terrain.reject! { |t| t.x == mx && t.y == my }
  end

  if args.inputs.keyboard.key_down.s && args.inputs.keyboard.key_held.control
    write_terrain(args)
    args.gtk.notify!("Saved!")
  end
end
```

## One-Time Initialization Guard

```ruby
def tick(args)
  if Kernel.tick_count == 0
    args.state.terrain = load_terrain('data/level_01.txt')
    defaults_player(args)
  end
  # ...
end
```

## Render Cached Stage

Cache static terrain into a render target so it isn't redrawn every frame:

```ruby
unless args.state.stage_cached
  args.outputs[:stage].width  = args.state.world_w
  args.outputs[:stage].height = 720
  args.outputs[:stage].sprites << args.state.terrain.map { |t| t.merge(path: 'sprites/tile.png') }
  args.state.stage_cached = true
end

# Render stage through camera:
args.outputs.sprites << {
  x: -args.state.cam_x, y: 0,
  w: args.state.world_w, h: 720,
  path: :stage
}
```
