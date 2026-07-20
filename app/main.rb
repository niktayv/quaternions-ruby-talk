require "app/quaternion.rb"
require "app/cube.rb"
require "app/cube_demo.rb"

module Main
  def tick(args)
    args.state.demo ||= CubeDemo.new
    args.state.demo.tick(args)
  end
end
