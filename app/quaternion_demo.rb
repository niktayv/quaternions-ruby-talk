require "app/quaternion.rb"
require "app/cube.rb"

class QuaternionDemo
  ROTATION_STEP = Math::PI / 12.0
  LOCAL_AXIS_LENGTH = 1.35
  LOCAL_AXIS_VECTORS = {
    x: [-1, 0, 0],
    y: [0, 0, -1],
    z: [0, 1, 0]
  }.freeze
  LOCAL_AXES = [
    { label: "(x)", vector: LOCAL_AXIS_VECTORS[:x].map { |value| value * LOCAL_AXIS_LENGTH }, colour: [255, 134, 134] },
    { label: "(y)", vector: LOCAL_AXIS_VECTORS[:y].map { |value| value * LOCAL_AXIS_LENGTH }, colour: [125, 220, 153] },
    { label: "(z)", vector: LOCAL_AXIS_VECTORS[:z].map { |value| value * LOCAL_AXIS_LENGTH }, colour: [130, 177, 255] }
  ].freeze
  VIEW_DIRECTION = [-1, 1, -1].freeze
  FACE_COLOURS = [
    [88, 144, 214], [58, 96, 158], [89, 166, 128],
    [205, 120, 120], [184, 158, 86], [151, 110, 185]
  ].freeze

  def tick(args)
    initialise_state(args)
    process_input(args)
    render(args)
  end

  private

  def initialise_state(args)
    args.state.orientation ||= Quaternion.identity
    args.state.cube ||= Cube.new
    args.state.cube.size = Cube::DEFAULT_SIZE
    args.state.rotation_mode ||= :local
  end

  def process_input(args)
    keyboard = args.inputs.keyboard

    rotate(args, LOCAL_AXIS_VECTORS[:x],  ROTATION_STEP) if keyboard.key_down.x
    rotate(args, LOCAL_AXIS_VECTORS[:y],  ROTATION_STEP) if keyboard.key_down.y
    rotate(args, LOCAL_AXIS_VECTORS[:z],  ROTATION_STEP) if keyboard.key_down.z

    rotate(args, LOCAL_AXIS_VECTORS[:x], -ROTATION_STEP) if keyboard.key_down.j
    rotate(args, LOCAL_AXIS_VECTORS[:y], -ROTATION_STEP) if keyboard.key_down.k
    rotate(args, LOCAL_AXIS_VECTORS[:z], -ROTATION_STEP) if keyboard.key_down.l

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
  end

  def toggle_rotation_mode(args)
    args.state.rotation_mode =
      args.state.rotation_mode == :world ? :local : :world
  end

  def reset(args)
    args.state.orientation = Quaternion.identity
    args.state.rotation_mode = :local
  end

  def render(args)
    args.outputs.background_color = [18, 22, 32]

    draw_title(args)
    draw_cube(args)
    draw_local_axes(args)
    draw_world_axes(args)
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
      view_direction: VIEW_DIRECTION
    )
    cube_faces(depths).each do |vertices, colour|
      draw_cube_face(args, points, vertices, colour)
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

  def cube_faces(depths)
    Cube::FACES.each_with_index.sort_by do |vertices, _index|
      vertices.inject(0.0) { |sum, index| sum + depths[index] } / vertices.length
    end.map do |vertices, index|
      [vertices, FACE_COLOURS[index]]
    end
  end

  def draw_cube_face(args, points, vertex_indexes, colour)
    vertices = vertex_indexes.map { |index| points[index] }
    min_y = vertices.map { |point| point[1] }.min.ceil
    max_y = vertices.map { |point| point[1] }.max.floor
    r, g, b = colour

    (min_y..max_y).each do |y|
      scan_y = y + 0.5
      intersections = []

      vertices.each_index do |index|
        first = vertices[index]
        second = vertices[(index + 1) % vertices.length]
        next if first[1] == second[1]

        lower, upper = first[1] < second[1] ? [first, second] : [second, first]
        next unless scan_y >= lower[1] && scan_y < upper[1]

        progress = (scan_y - lower[1]) / (upper[1] - lower[1])
        intersections << lower[0] + (upper[0] - lower[0]) * progress
      end

      next unless intersections.length >= 2

      intersections.sort!
      args.outputs.primitives << {
        primitive_marker: :line,
        x: intersections.first,
        y: y,
        x2: intersections.last,
        y2: y,
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
      text: "X/Y/Z: rotate local axes    J/K/L: rotate backward    R: reset    M: toggle mode",
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
    q = args.state.orientation

    text = format(
      "q = %.3f %+.3fi %+.3fj %+.3fk",
      q.w,
      q.x,
      q.y,
      q.z
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
