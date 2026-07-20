class CubeDemo
  ROTATION_STEP = Math::PI / 12.0

  def tick(args)
    initialise_state(args)
    process_input(args)
    render(args)
  end

  private

  def initialise_state(args)
    args.state.orientation ||= Quaternion.identity
    args.state.cube ||= Cube.new
  end

  def process_input(args)
    keyboard = args.inputs.keyboard

    rotate(args, [1, 0, 0],  ROTATION_STEP) if keyboard.key_down.x
    rotate(args, [0, 1, 0],  ROTATION_STEP) if keyboard.key_down.y
    rotate(args, [0, 0, 1],  ROTATION_STEP) if keyboard.key_down.z

    rotate(args, [1, 0, 0], -ROTATION_STEP) if keyboard.key_down.j
    rotate(args, [0, 1, 0], -ROTATION_STEP) if keyboard.key_down.k
    rotate(args, [0, 0, 1], -ROTATION_STEP) if keyboard.key_down.l

    reset(args) if keyboard.key_down.r
  end

  def rotate(args, axis, angle)
    rotation = Quaternion.from_axis_angle(axis, angle)

    args.state.orientation =
      (rotation * args.state.orientation).normalized
  end

  def reset(args)
    args.state.orientation = Quaternion.identity
  end

  def render(args)
    args.outputs.background_color = [18, 22, 32]

    draw_title(args)
    draw_cube(args)
    draw_instructions(args)
    draw_quaternion(args)
  end

  def draw_title(args)
    args.outputs.labels << {
      x: 640,
      y: 690,
      text: "Quaternion Cube",
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

    Cube::EDGES.each do |from_index, to_index|
      x1, y1 = points[from_index]
      x2, y2 = points[to_index]

      args.outputs.lines << {
        x: x1,
        y: y1,
        x2: x2,
        y2: y2,
        r: 130,
        g: 210,
        b: 255,
        a: 255
      }
    end
  end

  def draw_instructions(args)
    args.outputs.labels << {
      x: 640,
      y: 100,
      text: "X/Y/Z: rotate forward    J/K/L: rotate backward    R: reset",
      alignment_enum: 1,
      r: 190,
      g: 200,
      b: 215
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
