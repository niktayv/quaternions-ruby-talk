module QuaternionSliders
  SLIDER_X = 950
  SLIDER_WIDTH = 220
  SLIDER_HEIGHT = 14
  QUATERNION_SLIDERS = [
    { key: :w, label: "w",     y: 610, colour: [235, 240, 255] },
    { key: :x, label: "x * i", y: 540, colour: [255, 134, 134] },
    { key: :y, label: "y * j", y: 470, colour: [125, 220, 153] },
    { key: :z, label: "z * k", y: 400, colour: [130, 177, 255] }
  ].freeze

  private

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
end
