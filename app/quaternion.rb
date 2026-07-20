class Quaternion
  attr_reader :w, :x, :y, :z

  def initialize(w, x, y, z)
    @w = w.to_f
    @x = x.to_f
    @y = y.to_f
    @z = z.to_f
  end

  def self.identity
    new(1, 0, 0, 0)
  end

  def self.from_axis_angle(axis, angle)
    ax, ay, az = normalize_vector(axis)

    half_angle = angle / 2.0
    scale = Math.sin(half_angle)

    new(
      Math.cos(half_angle),
      ax * scale,
      ay * scale,
      az * scale
    )
  end

  def *(other)
    Quaternion.new(
      w * other.w - x * other.x - y * other.y - z * other.z,
      w * other.x + x * other.w + y * other.z - z * other.y,
      w * other.y - x * other.z + y * other.w + z * other.x,
      w * other.z + x * other.y - y * other.x + z * other.w
    )
  end

  def conjugate
    Quaternion.new(w, -x, -y, -z)
  end

  def normalized
    magnitude = Math.sqrt(
      w * w +
      x * x +
      y * y +
      z * z
    )

    return Quaternion.identity if magnitude.zero?

    Quaternion.new(
      w / magnitude,
      x / magnitude,
      y / magnitude,
      z / magnitude
    )
  end

  def rotate(vector)
    point = Quaternion.new(
      0,
      vector[0],
      vector[1],
      vector[2]
    )

    result = self * point * conjugate

    [result.x, result.y, result.z]
  end

  def self.normalize_vector(vector)
    x, y, z = vector
    magnitude = Math.sqrt(x * x + y * y + z * z)

    return [1.0, 0.0, 0.0] if magnitude.zero?

    [
      x / magnitude,
      y / magnitude,
      z / magnitude
    ]
  end
end
