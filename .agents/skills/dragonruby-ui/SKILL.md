---
name: dragonruby-ui
description: UI controls in DragonRuby GTK — buttons, checkboxes, toggles, scroll views, menus, input remapping, tooltips, progress bars, accessibility. Use when building game menus, HUDs, settings screens, or in-game UI widgets.
---

This skill covers DragonRuby UI patterns. Layout grid and basic label/rect output are in the main `dragonruby` skill.

## Layout Grid

```ruby
# 12×24 grid in landscape — each cell maps to pixel coords:
rect = Layout.rect(row: 0, col: 0, w: 6, h: 2)
# => { x:, y:, w:, h:, center: { x:, y: } }

point = Layout.point(row: 5, col: 4, row_anchor: 0.5, col_anchor: 0.5)

# Group of rects spaced horizontally:
group = Layout.rect_group(row: 10, dcol: 1, w: 1, h: 1, group: items)

# Visualise the grid during development:
args.outputs.debug << Layout.debug_primitives
```

## Button

```ruby
def button_prefab(rect, text, hovered: false, active: false)
  bg_color = active ? [80, 160, 80] : hovered ? [60, 80, 120] : [40, 60, 100]
  [
    rect.merge(path: :solid, *bg_color.zip([:r, :g, :b]).to_h),
    rect.merge(path: :border, r: 200, g: 200, b: 255),
    rect.center.merge(text: text, alignment_enum: 1, vertical_alignment_enum: 1,
                      r: 255, g: 255, b: 255)
  ]
end

def button_clicked?(args, rect)
  args.inputs.mouse.click && args.inputs.mouse.click.point.inside_rect?(rect)
end

def button_hovered?(args, rect)
  args.inputs.mouse.inside_rect?(rect)
end

# Usage:
btn = Layout.rect(row: 8, col: 8, w: 8, h: 2)
args.outputs.primitives << button_prefab(btn, "Start", hovered: button_hovered?(args, btn))
if button_clicked?(args, btn)
  args.state.next_scene = :game
end
```

## Checkbox

```ruby
def defaults_checkbox(id:, x:, y:, size: 24, checked: false)
  { id: id, x: x, y: y, w: size, h: size, checked: checked, changed_at: -999 }
end

def tick_checkbox(args, cb)
  if args.inputs.mouse.click && args.inputs.mouse.click.point.inside_rect?(cb)
    cb.checked  = !cb.checked
    cb.changed_at = Kernel.tick_count
  end
end

def render_checkbox(cb, duration: 15)
  perc = Easing.smooth_stop(start_at: cb.changed_at, duration: duration,
                             tick_count: Kernel.tick_count, power: 4)
  perc = cb.checked ? perc : 1 - perc
  fill_w = (cb.w * perc).to_i
  [
    cb.merge(path: :border, r: 200, g: 200, b: 200),
    cb.merge(w: fill_w, path: :solid, r: 80, g: 200, b: 80)
  ]
end
```

## Toggle Switch

```ruby
def render_toggle(toggle, label:, duration: 15)
  perc = toggle.on ? Easing.smooth_stop(start_at: toggle.changed_at, duration: duration,
                                         tick_count: Kernel.tick_count, power: 4)
               : Easing.smooth_stop(start_at: toggle.changed_at, duration: duration,
                                    tick_count: Kernel.tick_count, power: 4, flip: true)
  track_color = toggle.on ? [60, 180, 60] : [80, 80, 80]
  knob_x = toggle.x + perc * (toggle.w - toggle.h)
  [
    toggle.merge(path: :solid, **track_color.zip([:r,:g,:b]).to_h, a: 200),
    { x: knob_x, y: toggle.y, w: toggle.h, h: toggle.h, path: :solid, r: 240, g: 240, b: 240 },
    { x: toggle.x + toggle.w + 8, y: toggle.y, text: label, r: 255, g: 255, b: 255 }
  ]
end
```

## Slider

```ruby
def render_slider(s)
  fill_w = (s.w * s.value).to_i
  [
    s.merge(path: :solid, r: 50, g: 50, b: 50),
    s.merge(w: fill_w, path: :solid, r: 100, g: 150, b: 255),
    { x: s.x + fill_w - 6, y: s.y - 4, w: 12, h: s.h + 8, path: :solid, r: 255, g: 255, b: 255 }
  ]
end

def tick_slider(args, s)
  if args.inputs.mouse.held && args.inputs.mouse.inside_rect?(s)
    s.value = ((args.inputs.mouse.x - s.x).to_f / s.w).clamp(0.0, 1.0)
  end
end
```

## Progress Bar

```ruby
def render_progress_bar(rect, value, color: [80, 200, 80], bg_color: [40, 40, 40])
  [
    rect.merge(path: :solid, r: *bg_color),
    rect.merge(w: (rect.w * value).to_i, path: :solid, r: *color)
  ]
end
```

## Scroll View

Physics-based scrolling with momentum:

```ruby
args.state.scroll_y  ||= 0
args.state.scroll_dy ||= 0.0
SCROLL_FRICTION = 0.92
CONTENT_H = 2000   # total scrollable height

def tick_scroll(args)
  if args.inputs.mouse.wheel
    args.state.scroll_dy += args.inputs.mouse.wheel.y * 10
  end

  if args.inputs.mouse.click
    args.state.scroll_drag_start_y = args.inputs.mouse.y
    args.state.scroll_drag_start   = args.state.scroll_y
  elsif args.inputs.mouse.held && args.state.scroll_drag_start_y
    args.state.scroll_y = args.state.scroll_drag_start +
                          (args.inputs.mouse.y - args.state.scroll_drag_start_y) * 2
    args.state.scroll_dy = 0
  elsif args.inputs.mouse.up
    args.state.scroll_drag_start_y = nil
  end

  args.state.scroll_dy *= SCROLL_FRICTION
  args.state.scroll_dy  = 0 if args.state.scroll_dy.abs < 0.5
  args.state.scroll_y  += args.state.scroll_dy
  args.state.scroll_y   = args.state.scroll_y.clamp(-(CONTENT_H - 720), 0)
end

# Apply offset when rendering items:
def render_scroll_items(args, items, clip_rect)
  offset_items = items.map { |i| i.merge(y: i.y + args.state.scroll_y) }
  visible = Geometry.find_all_intersect_rect(clip_rect, offset_items)
  args.outputs.primitives << visible
end
```

## Menu Navigation (Keyboard / Controller / Mouse)

Support all input devices seamlessly:

```ruby
def tick_menu(args)
  items = args.state.menu_items

  if args.inputs.last_active == :mouse
    # Highlight on hover
    args.state.hovered = items.find { |i| args.inputs.mouse.inside_rect?(i.rect) }
  else
    # Navigate with keys/controller
    args.state.hovered = Geometry.rect_navigate(
      rect:       args.state.hovered,
      rects:      items,
      left_right: args.inputs.key_down.left_right,
      up_down:    args.inputs.key_down.up_down,
      using:      :rect,
      wrap_y:     true
    )
  end

  # Confirm selection:
  if args.inputs.mouse.click && args.state.hovered
    args.state.hovered.on_click&.call
  elsif args.inputs.keyboard.key_down.enter || args.inputs.controller_one.key_down.a
    args.state.hovered&.on_click&.call
  end
end
```

## Radial Menu

```ruby
def build_radial_menu(items, cx:, cy:, radius:)
  items.each_with_index.map do |item, i|
    angle = 90 + (360.0 / items.length) * i
    x = cx + angle.vector_x * radius - item[:w] / 2
    y = cy + angle.vector_y * radius - item[:h] / 2
    item.merge(x: x, y: y, menu_angle: angle)
  end
end

args.state.menu_items = build_radial_menu(
  [{ w: 80, h: 30, text: "Attack" }, { w: 80, h: 30, text: "Item" }],
  cx: 640, cy: 360, radius: 120
)
```

## Input Remapping

```ruby
args.state.bindings ||= {
  keyboard: { move_left: [:left], move_right: [:right], jump: [:space] },
  controller: { move_left: [:left], move_right: [:right], jump: [:a] }
}

def action_pressed?(args, action)
  device = args.inputs.last_active == :controller ? :controller : :keyboard
  keys   = args.state.bindings[device][action]
  input  = device == :controller ? args.inputs.controller_one : args.inputs.keyboard
  keys.any? { |k| input.key_down_or_held?(k) }
end

def start_remapping(args, action)
  args.state.remapping = action
  args.state.remap_mode = true
end

def tick_remap(args)
  return unless args.state.remap_mode
  key = args.inputs.keyboard.truthy_keys.first
  if key
    args.state.bindings[:keyboard][args.state.remapping] = [key]
    args.state.remap_mode = false
  end
end
```

## Tooltip

```ruby
def render_tooltip(args, rect, text)
  return unless args.inputs.mouse.inside_rect?(rect)
  return if Kernel.tick_count - (args.state.hover_start ||= Kernel.tick_count) < 45

  tw, th = args.gtk.calcstringbox(text)
  tx = args.inputs.mouse.x + 12
  ty = args.inputs.mouse.y + 12
  args.outputs.primitives << [
    { x: tx - 4, y: ty - 4, w: tw + 8, h: th + 8, path: :solid, r: 30, g: 30, b: 30, a: 220 },
    { x: tx, y: ty, text: text, r: 255, g: 255, b: 255 }
  ]
end
```

## Animated Selection Cursor (Lerp)

```ruby
args.state.cursor_x ||= 0
args.state.cursor_y ||= 0

target = args.state.selected_item
args.state.cursor_x = args.state.cursor_x.lerp(target.x - 4, 0.25)
args.state.cursor_y = args.state.cursor_y.lerp(target.y - 4, 0.25)

args.outputs.borders << { x: args.state.cursor_x, y: args.state.cursor_y,
                           w: target.w + 8, h: target.h + 8, r: 255, g: 220, b: 0 }
```

## Persistent UI State (save checkbox/slider values)

```ruby
def save_ui_state(args)
  data = args.state.checkboxes.map { |c| "#{c.id},#{c.checked}" }.join("\n")
  GTK.write_file('data/ui_state.txt', data)
end

def load_ui_state(args)
  raw = GTK.read_file('data/ui_state.txt')
  return unless raw
  raw.each_line do |line|
    id, val = line.strip.split(',')
    cb = args.state.checkboxes.find { |c| c.id.to_s == id }
    cb.checked = val == 'true' if cb
  end
end
```

## Accessibility (Screen Reader)

```ruby
# Register interactive elements for assistive technology:
args.outputs.a11y[:play_button] = {
  a11y_text:  "Play Game",
  a11y_trait: :button,
  x: btn.x, y: btn.y, w: btn.w, h: btn.h
}

args.outputs.a11y[:hp_label] = {
  a11y_text:  "Health: #{hp}",
  a11y_trait: :label,
  x: hud_x, y: hud_y, w: 100, h: 24
}
```

## Frame-by-Frame Debug Control

Useful for in-game dev tools:

```ruby
args.state.clock        ||= 0
args.state.frame_by_frame ||= false

if args.inputs.keyboard.key_down.f9
  args.state.frame_by_frame = !args.state.frame_by_frame
end

if args.state.frame_by_frame
  args.state.clock += 1 if args.inputs.keyboard.key_down.period   # '.' = next frame
else
  args.state.clock += 1
end
```

## Pulse / Attention Animation

```ruby
class PulseButton
  attr_accessor :rect, :text, :clicked_at
  PULSE_SPLINE = [[0, 0.9, 1.0, 1.0], [1.0, 0.1, 0, 0]]

  def tick(inputs)
    if inputs.mouse.click && inputs.mouse.click.point.inside_rect?(@rect)
      @clicked_at = Kernel.tick_count
      yield if block_given?
    end
  end

  def render
    scale = if @clicked_at
      1 - 0.15 * Easing.spline(@clicked_at, Kernel.tick_count, 20, PULSE_SPLINE)
    else
      1.0
    end
    scaled = Geometry.scale_rect(@rect, scale, 0.5, 0.5)
    [scaled.merge(path: :solid, r: 60, g: 100, b: 180),
     scaled.center.merge(text: @text, alignment_enum: 1, vertical_alignment_enum: 1)]
  end
end
```
