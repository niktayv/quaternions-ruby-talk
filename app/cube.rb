class Cube
  attr_accessor :size

  # Renderer extents x:y:z = 3:1:2 give displayed local-axis proportions 3:2:1.
  VERTICES = [
    [-1.5, -0.5, -1],
    [ 1.5, -0.5, -1],
    [ 1.5,  0.5, -1],
    [-1.5,  0.5, -1],
    [-1.5, -0.5,  1],
    [ 1.5, -0.5,  1],
    [ 1.5,  0.5,  1],
    [-1.5,  0.5,  1]
  ].freeze

  VERTEX_LABELS = ("A".."H").to_a.freeze

  EDGES = [
    [0, 1], [1, 2], [2, 3], [3, 0],
    [4, 5], [5, 6], [6, 7], [7, 4],
    [0, 4], [1, 5], [2, 6], [3, 7]
  ].freeze

  FACES = [
    [0, 1, 2, 3], [4, 5, 6, 7], [0, 4, 5, 1],
    [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]
  ].freeze

  def initialize(size: 117)
    @size = size.to_f
  end

  def projected_vertices(orientation, centre_x:, centre_y:)
    VERTICES.map do |vertex|
      projected_point(vertex, orientation, centre_x: centre_x, centre_y: centre_y)
    end
  end

  def projected_point(point, orientation, centre_x:, centre_y:)
    project(orientation.rotate(point), centre_x: centre_x, centre_y: centre_y)
  end

  def vertex_depths(orientation, view_direction: [0, 0, -1])
    # The depth cue is independent of the isometric screen projection.
    # It is the dot product with the caller's viewer-facing axis.
    VERTICES.map do |vertex|
      x, y, z = orientation.rotate(vertex)
      x * view_direction[0] + y * view_direction[1] + z * view_direction[2]
    end
  end

  private

  def project(point, centre_x:, centre_y:)
    x, y, z = point

    # Project the three renderer axes at equal scale, 120 degrees apart:
    # x points up-right, y points up, and z points up-left.
    horizontal = Math.sqrt(3.0) / 2.0
    vertical = 0.5

    [
      centre_x + (x - z) * @size * horizontal,
      centre_y + (y + (x + z) * vertical) * @size
    ]
  end
end
