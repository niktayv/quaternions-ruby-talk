class CubeDemo
  ROTATION_STEP = Math::PI / 12.0
  CUBE_SIZE = 117
  SLIDER_X = 950
  SLIDER_WIDTH = 220
  SLIDER_HEIGHT = 14
  QUATERNION_SLIDERS = [
    { key: :w, label: "w",     y: 610, colour: [235, 240, 255] },
    { key: :x, label: "x * i", y: 540, colour: [255, 134, 134] },
    { key: :y, label: "y * j", y: 470, colour: [125, 220, 153] },
    { key: :z, label: "z * k", y: 400, colour: [130, 177, 255] }
  ].freeze
  LOCAL_AXES = [
    { label: "(x)", vector: [-1.35, 0, 0], colour: [255, 134, 134] },
    { label: "(y)", vector: [0, 0, -1.35], colour: [125, 220, 153] },
    { label: "(z)", vector: [0, 1.35, 0], colour: [130, 177, 255] }
  ].freeze
  ROTATION_AXES = {
    x: [-1, 0, 0],
    y: [0, 0, -1],
    z: [0, 1, 0]
  }.freeze

  def tick(args)
    initialise_state(args)
    process_input(args)
    render(args)
  end

  private

  def initialise_state(args)
    args.state.orientation ||= Quaternion.identity
    args.state.cube ||= Cube.new(size: CUBE_SIZE)
    args.state.cube.size = CUBE_SIZE
    args.state.rotation_mode ||= :world
    args.state.quaternion_components ||= quaternion_components(args.state.orientation)
  end

  def process_input(args)
    keyboard = args.inputs.keyboard

    update_quaternion_from_sliders(args)

    rotate(args, ROTATION_AXES[:x],  ROTATION_STEP) if keyboard.key_down.x
    rotate(args, ROTATION_AXES[:y],  ROTATION_STEP) if keyboard.key_down.y
    rotate(args, ROTATION_AXES[:z],  ROTATION_STEP) if keyboard.key_down.z

    rotate(args, ROTATION_AXES[:x], -ROTATION_STEP) if keyboard.key_down.j
    rotate(args, ROTATION_AXES[:y], -ROTATION_STEP) if keyboard.key_down.k
    rotate(args, ROTATION_AXES[:z], -ROTATION_STEP) if keyboard.key_down.l

    reset(args) if keyboard.key_down.r
    toggle_rotation_mode(args) if keyboard.key_down.m
  end

  def rotate(args, axis, angle)
    rotation = Quaternion.from_axis_angle(axis, angle)

    args.state.orientation =
      if args.state.rotation_mode == :local
        (args.state.orientation * rotation).normalized
      else
        (rotation * args.state.orientation).normalized
      end

    sync_quaternion_components(args)
  end

  def toggle_rotation_mode(args)
    args.state.rotation_mode =
      args.state.rotation_mode == :world ? :local : :world
  end

  def reset(args)
    args.state.orientation = Quaternion.identity
    sync_quaternion_components(args)
  end

  def render(args)
    args.outputs.background_color = [18, 22, 32]

    draw_title(args)
    draw_cube(args)
    draw_local_axes(args)
    draw_world_axes(args)
    draw_quaternion_sliders(args)
    draw_rotation_mode(args)
    draw_instructions(args)
    draw_quaternion(args)
  end

  def draw_title(args)
    args.outputs.labels << {
      x: 640,
      y: 690,
      text: "Quaternion Parallelepiped",
      alignment_enum: 1,
      size_enum: 6,
      r: 235,
      g: 240,
      b: 255
    }
  end

  def draw_cube(args)
    cube = args.state.cube

    points = cube.projected_vertices(
      args.state.orientation,
      centre_x: 640,
      centre_y: 380
    )
    depths = cube.vertex_depths(
      args.state.orientation,
      view_direction: ROTATION_AXES[:y]
    )
    nearest_depth = depths.max
    farthest_depth = depths.min

    Cube::EDGES.each_with_index do |(from_index, to_index), index|
      x1, y1 = points[from_index]
      x2, y2 = points[to_index]
      r, g, b = Cube::EDGE_COLOURS[index]
      thickness = edge_thickness(
        depths[from_index],
        depths[to_index],
        farthest_depth,
        nearest_depth
      )

      draw_cube_edge(args, x1, y1, x2, y2, [r, g, b], thickness)
    end

    points.each_with_index do |(x, y), index|
      args.outputs.labels << {
        x: x + 10,
        y: y + 10,
        text: Cube::VERTEX_LABELS[index],
        size_enum: 3,
        r: 255,
        g: 235,
        b: 130
      }
    end
  end

  def edge_thickness(from_depth, to_depth, farthest_depth, nearest_depth)
    average_depth = (from_depth + to_depth) / 2.0
    depth_span = nearest_depth - farthest_depth
    return 3 if depth_span.zero?

    relative_depth = (average_depth - farthest_depth) / depth_span
    [[(2 + relative_depth * 3).round, 2].max, 5].min
  end

  def draw_cube_edge(args, x1, y1, x2, y2, colour, thickness)
    length = Math.sqrt((x2 - x1)**2 + (y2 - y1)**2)
    return if length.zero?

    offset_x = -(y2 - y1) / length
    offset_y = (x2 - x1) / length
    r, g, b = colour

    thickness.times do |index|
      offset = index - (thickness - 1) / 2.0

      args.outputs.lines << {
        x: x1 + offset_x * offset,
        y: y1 + offset_y * offset,
        x2: x2 + offset_x * offset,
        y2: y2 + offset_y * offset,
        r: r,
        g: g,
        b: b,
        a: 255
      }
    end
  end

  def draw_local_axes(args)
    cube = args.state.cube
    orientation = args.state.orientation
    origin = cube.projected_point([0, 0, 0], orientation, centre_x: 640, centre_y: 380)

    LOCAL_AXES.each do |axis|
      x, y = cube.projected_point(axis[:vector], orientation, centre_x: 640, centre_y: 380)
      r, g, b = axis[:colour]

      args.outputs.lines << { x: origin[0], y: origin[1], x2: x, y2: y, r: r, g: g, b: b }
      args.outputs.labels << {
        x: x + 8, y: y + 8, text: axis[:label], size_enum: 2, r: r, g: g, b: b
      }
    end
  end

  def draw_instructions(args)
    args.outputs.labels << {
      x: 640,
      y: 100,
      text: "X/Y/Z: rotate forward    J/K/L: rotate backward    R: reset    M: toggle mode",
      alignment_enum: 1,
      r: 190,
      g: 200,
      b: 215
    }
  end

  def draw_world_axes(args)
    x = 1_080
    y = 190
    length = 60
    diagonal = length * Math.sqrt(3.0) / 2.0
    rise = length / 2.0

    args.outputs.labels << {
      x: x,
      y: y + 100,
      text: "World axes (fixed)",
      alignment_enum: 1,
      r: 175,
      g: 185,
      b: 205
    }

    draw_world_axis(args, x, y, x - diagonal, y - rise, "(x)", [255, 134, 134])
    draw_world_axis(args, x, y, x, y + length, "(z)", [130, 177, 255])
    draw_world_axis(args, x, y, x + diagonal, y - rise, "(y)", [125, 220, 153])
  end

  def draw_world_axis(args, x1, y1, x2, y2, label, colour)
    r, g, b = colour

    args.outputs.lines << { x: x1, y: y1, x2: x2, y2: y2, r: r, g: g, b: b, a: 180 }
    args.outputs.labels << { x: x2 + 6, y: y2 + 6, text: label, r: r, g: g, b: b }
  end

  def update_quaternion_from_sliders(args)
    mouse = args.inputs.mouse
    return unless mouse.click || mouse.held

    QUATERNION_SLIDERS.each do |slider|
      inside_slider =
        mouse.x >= SLIDER_X && mouse.x <= SLIDER_X + SLIDER_WIDTH &&
        mouse.y >= slider[:y] - SLIDER_HEIGHT / 2 &&
        mouse.y <= slider[:y] + SLIDER_HEIGHT / 2
      next unless inside_slider

      args.state.quaternion_components[slider[:key]] =
        ((mouse.x - SLIDER_X).fdiv(SLIDER_WIDTH) * 2.0 - 1.0).clamp(-1.0, 1.0)
      args.state.orientation = quaternion_from_components(args.state.quaternion_components)
      sync_quaternion_components(args)
      break
    end
  end

  def quaternion_components(q)
    { w: q.w, x: -q.x, y: -q.z, z: q.y }
  end

  def quaternion_from_components(components)
    Quaternion.new(
      components[:w],
      -components[:x],
      components[:z],
      -components[:y]
    ).normalized
  end

  def sync_quaternion_components(args)
    args.state.quaternion_components = quaternion_components(args.state.orientation)
  end

  def draw_quaternion_sliders(args)
    args.outputs.labels << {
      x: SLIDER_X + SLIDER_WIDTH / 2,
      y: 665,
      text: "q = w + x*i + y*j + z*k",
      alignment_enum: 1,
      r: 215,
      g: 225,
      b: 240
    }

    QUATERNION_SLIDERS.each do |slider|
      value = args.state.quaternion_components[slider[:key]]
      r, g, b = slider[:colour]
      knob_x = SLIDER_X + (value + 1.0).fdiv(2.0) * SLIDER_WIDTH

      args.outputs.labels << {
        x: SLIDER_X - 18,
        y: slider[:y] + 5,
        text: format("%s: %+.2f", slider[:label], value),
        alignment_enum: 2,
        r: r,
        g: g,
        b: b
      }
      args.outputs.solids << {
        x: SLIDER_X,
        y: slider[:y] - SLIDER_HEIGHT / 2,
        w: SLIDER_WIDTH,
        h: SLIDER_HEIGHT,
        r: 50,
        g: 58,
        b: 76
      }
      args.outputs.borders << {
        x: SLIDER_X,
        y: slider[:y] - SLIDER_HEIGHT / 2,
        w: SLIDER_WIDTH,
        h: SLIDER_HEIGHT,
        r: 115,
        g: 128,
        b: 155
      }
      args.outputs.solids << {
        x: knob_x - 6,
        y: slider[:y] - 11,
        w: 12,
        h: 22,
        r: r,
        g: g,
        b: b
      }
    end
  end

  def draw_rotation_mode(args)
    mode = args.state.rotation_mode == :local ? "Local axes" : "World axes"

    args.outputs.labels << {
      x: 640,
      y: 130,
      text: "Rotation mode: #{mode}",
      alignment_enum: 1,
      r: 220,
      g: 225,
      b: 240
    }
  end

  def draw_quaternion(args)
    q = args.state.quaternion_components

    text = format(
      "q = %.3f %+.3fi %+.3fj %+.3fk",
      q[:w],
      q[:x],
      q[:y],
      q[:z]
    )

    args.outputs.labels << {
      x: 640,
      y: 60,
      text: text,
      alignment_enum: 1,
      r: 160,
      g: 175,
      b: 195
    }
  end
end
