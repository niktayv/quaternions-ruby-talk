module Main
  def tick(args)
    args.outputs.background_color = [20, 24, 35]

    args.outputs.labels << {
      x: 640,
      y: 380,
      text: "Quaternion Cube",
      alignment_enum: 1,
      size_enum: 8,
      r: 255,
      g: 255,
      b: 255
    }

    args.outputs.labels << {
      x: 640,
      y: 330,
      text: "DragonRuby is ready",
      alignment_enum: 1,
      r: 200,
      g: 210,
      b: 225
    }
  end
end
