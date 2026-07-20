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

  EDGES = [
    [0, 1], [1, 2], [2, 3], [3, 0],
    [4, 5], [5, 6], [6, 7], [7, 4],
    [0, 4], [1, 5], [2, 6], [3, 7]
  ].freeze

  def initialize(size: 130, camera_distance: 5)
    @size = size
    @camera_distance = camera_distance
  end

  def projected_vertices(orientation, centre_x:, centre_y:)
    VERTICES.map do |vertex|
      rotated = orientation.rotate(vertex)

      project(
        rotated,
        centre_x: centre_x,
        centre_y: centre_y
      )
    end
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
