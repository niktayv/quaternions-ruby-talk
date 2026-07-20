A good first milestone is deliberately modest:

> Display a perspective wireframe cube and rotate it in 15-degree steps using the keyboard.

Keep the quaternion mathematics, cube geometry, rendering, and DragonRuby application loop separate. That will make the code easier to explain during the talk.

DragonRuby loads `app/main.rb` as the entry point. This checkout's starter exposes `tick` inside `module Main`. Additional project files can be loaded with paths such as `require "app/quaternion.rb"`. The application receives persistent state through `args.state`, keyboard input through `args.inputs`, and rendering collections through `args.outputs`. ([docs.dragonruby.org][1])

## Target structure

From the repository root, create this structure:

```text
app/
├── main.rb
├── quaternion.rb
├── cube.rb
└── cube_demo.rb
metadata/
sprites/
```

The responsibilities will be:

```text
quaternion.rb   Quaternion construction, multiplication and vector rotation
cube.rb         Cube vertices, edges and perspective projection
cube_demo.rb    Input, state updates and rendering
main.rb         DragonRuby entry point
```

You can implement this in four small stages.

---

# Stage 1: Replace the original demo

The pristine starter is already preserved by the existing `Prepare the stage`
commit. Confirm that the working tree is clean before replacing it:

```bash
git status --short
```

Replace `app/main.rb` with:

```ruby
module Main
  def tick(args)
    args.outputs.background_color = [20, 24, 35]

    args.outputs.labels << {
      x: 640,
      y: 380,
      text: "Quaternion Cube",
      alignment_enum: 1,
      size_enum: 8
    }

    args.outputs.labels << {
      x: 640,
      y: 330,
      text: "DragonRuby is ready",
      alignment_enum: 1
    }
  end
end
```

Save the file while DragonRuby is running.

You should see a dark canvas with two centred labels.

Commit this checkpoint:

```bash
git add app/main.rb
git commit -m "Replace starter demo with quaternion demo shell"
```

---

# Stage 2: Add the quaternion implementation

Create:

```text
app/quaternion.rb
```

Add:

```ruby
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
```

For this initial demo, that is all the quaternion functionality you need.

The central method is:

```ruby
def rotate(vector)
  point = Quaternion.new(0, *vector)
  result = self * point * conjugate

  [result.x, result.y, result.z]
end
```

Conceptually, this implements:

$$
p' = qpq^{-1}.
$$

Because the orientation is kept normalised, its conjugate is also its inverse.

Do not load the file yet. First commit it independently:

```bash
git add app/quaternion.rb
git commit -m "Add quaternion rotation implementation"
```

---

# Stage 3: Define and project the cube

Create:

```text
app/cube.rb
```

Add:

```ruby
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
```

This file contains no DragonRuby-specific code.

It does two things:

1. describes a cube as eight vertices joined by twelve edges;
2. converts rotated 3D points into 2D screen coordinates.

The perspective calculation is:

```ruby
perspective = camera_distance / (camera_distance - z)
```

A point closer to the virtual camera receives a larger scale, while a point farther away receives a smaller one.

Commit it:

```bash
git add app/cube.rb
git commit -m "Add cube geometry and perspective projection"
```

---

# Stage 4: Add the DragonRuby application

Create:

```text
app/cube_demo.rb
```

Add:

```ruby
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
```

Now replace `app/main.rb` with:

```ruby
require "app/quaternion.rb"
require "app/cube.rb"
require "app/cube_demo.rb"

module Main
  def tick(args)
    args.state.demo ||= CubeDemo.new
    args.state.demo.tick(args)
  end
end
```

DragonRuby examples commonly split application code into files under `app/` and load them from `main.rb` with `require "app/…"` paths. ([Gist][2])

Save all four files.

DragonRuby should reload the application and show the cube.

Commit the completed milestone:

```bash
git add app
git commit -m "Add keyboard-controlled quaternion cube"
```

---

# Controls

The initial controls are:

| Key | Action                               |
| --- | ------------------------------------ |
| `X` | Rotate +15° around the global x-axis |
| `Y` | Rotate +15° around the global y-axis |
| `Z` | Rotate +15° around the global z-axis |
| `J` | Rotate −15° around the global x-axis |
| `K` | Rotate −15° around the global y-axis |
| `L` | Rotate −15° around the global z-axis |
| `R` | Reset to the identity orientation    |

The displayed value:

```text
q = 1.000 +0.000i +0.000j +0.000k
```

is the cube’s current orientation.

After pressing `X`, it should become approximately:

```text
q = 0.991 +0.131i +0.000j +0.000k
```

The angle is 15°, but the quaternion contains the half-angle:

$$
\cos 7.5^\circ \approx 0.991,\qquad
\sin 7.5^\circ \approx 0.131.
$$

That gives you a useful observation for the presentation.

---

# Verify non-commutativity

Once the cube works, perform this test.

First sequence:

```text
R
X
Y
```

Observe the cube’s orientation.

Then:

```text
R
Y
X
```

The final orientation should differ.

You can also watch the displayed quaternion values. They will not be the same, apart from the special equivalence between $q$ and $-q$.

This demonstrates:

$$
q_yq_x \ne q_xq_y.
$$

In the code, new rotations are applied using:

```ruby
rotation * args.state.orientation
```

That means each keyboard command is interpreted around a **global/world axis**.

Later, changing it to:

```ruby
args.state.orientation * rotation
```

will apply the command in the cube’s **local coordinate system**. This distinction is valuable, but I would leave it for the second implementation milestone.

---

# Troubleshooting

## Blank screen after adding `require`

Look at the terminal where DragonRuby is running. A syntax error or missing file will be reported there.

Confirm the names exactly:

```text
app/quaternion.rb
app/cube.rb
app/cube_demo.rb
app/main.rb
```

Linux paths are case-sensitive.

## `uninitialized constant Quaternion`

Check that `main.rb` loads files in this order:

```ruby
require "app/quaternion.rb"
require "app/cube.rb"
require "app/cube_demo.rb"
```

`cube.rb` uses `Quaternion`, and `cube_demo.rb` uses both classes.

## Changes appear not to take effect

Persistent objects inside `args.state` can survive code reloads. Press `R` first.

For structural changes to classes or state, restart DragonRuby from the
repository root:

```bash
../dragonruby
```

## The cube becomes distorted or disappears

Check that the cube vertices remain around (-1) to (1), and that:

```ruby
camera_distance: 5
```

has not been reduced below the cube’s effective depth.

## A key rotates repeatedly

Use:

```ruby
keyboard.key_down.x
```

for one rotation per key press.

Do not use:

```ruby
keyboard.x
```

at this stage, because that represents a held key and would rotate the cube on every frame.

---

# Recommended next implementation sequence

Once this checkpoint is stable, evolve it in this order:

1. Draw coloured local (x), (y), and (z) axes.
2. Add a toggle between world-axis and local-axis multiplication.
3. Add an arbitrary diagonal axis such as `[1, 1, 1]`.
4. Add continuous rotation while a key is held.
5. Add target orientations and SLERP.
6. Replace the cube with a ruby gemstone or construction crane.

The code above gives you the smallest useful foundation for all of those additions.

[1]: https://docs.dragonruby.org/?utm_source=chatgpt.com "DragonRuby Docs"
[2]: https://gist.github.com/amirrajan/57a75d83ad281db6c7dbcefde77dca2d?utm_source=chatgpt.com "DragonRuby Game Toolkit - Ramp Collision. Demo: https://youtu.be/gU7m23yYs60 · GitHub"
