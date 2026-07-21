class Cube
  VERTICES = [
    [-1, -1, -1],
    [ 1, -1, -1],
    [ 1,  1, -1],
    [-1,  1, -1],
    [-1, -1,  1],
    [ 1, -1,  1],
    [ 1,  1,  1],
    [-1,  1,  1]
  ].freeze

  VERTEX_LABELS = ("A".."H").to_a.freeze

  EDGES = [
    [0, 1], [1, 2], [2, 3], [3, 0],
    [4, 5], [5, 6], [6, 7], [7, 4],
    [0, 4], [1, 5], [2, 6], [3, 7]
  ].freeze

  EDGE_COLOURS = [
    [255, 179, 186], [255, 223, 186], [255, 255, 186], [186, 255, 201],
    [186, 225, 255], [201, 186, 255], [255, 186, 224], [217, 194, 175],
    [197, 225, 165], [165, 216, 208], [189, 178, 255], [244, 172, 183]
  ].freeze

  def initialize(size: 130, camera_distance: 5)
    @size = size
    @camera_distance = camera_distance
  end

  def projected_vertices(orientation, centre_x:, centre_y:)
    VERTICES.map do |vertex|
      projected_point(vertex, orientation, centre_x: centre_x, centre_y: centre_y)
    end
  end

  def projected_point(point, orientation, centre_x:, centre_y:)
    project(orientation.rotate(point), centre_x: centre_x, centre_y: centre_y)
  end

  def vertex_depths(orientation)
    VERTICES.map { |vertex| orientation.rotate(vertex)[2] }
  end

  private

  def project(point, centre_x:, centre_y:)
    x, y, z = point

    depth = @camera_distance - z
    perspective = @camera_distance / depth

    [
      centre_x + x * @size * perspective,
      centre_y + y * @size * perspective
    ]
  end
end
