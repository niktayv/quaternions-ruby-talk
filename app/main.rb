require "app/quaternion_demo.rb"

module Main
  def tick(args)
    args.state.demo ||= QuaternionDemo.new
    args.state.demo.tick(args)
  end
end
