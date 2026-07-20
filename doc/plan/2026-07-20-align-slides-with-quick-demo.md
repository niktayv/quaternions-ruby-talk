# Align the quaternion slides with the quick demo

Status: draft for review. This plan proposes changes to
`slides/quaternions_dragonruby_marp.md`; it does not modify the slide deck or
the code implementation plan.

## Source of truth

The first implementation milestone remains the complete 15-degree,
keyboard-controlled cube described in
`doc/plan/2026-07-20-wire-up-quick-demo.md`.

The slide deck should match that milestone instead of expanding it. In
particular:

- the live demo uses `X`, `Y`, and `Z` for +15-degree world-axis steps;
- `J`, `K`, and `L` apply the corresponding -15-degree steps;
- `R` resets the cube to the identity orientation;
- arbitrary-axis animation, SLERP, and a gemstone or crane remain later work.

A 90-degree order comparison is still available without changing the code:
press a direction key six times.

## Required slide corrections

### 1. Fix Marp math rendering

Add an explicit math renderer to the front matter:

```yaml
math: mathjax
```

Replace every block delimiter:

```text
\[ ... \]
```

with:

```text
$$ ... $$
```

Replace every inline delimiter:

```text
\( ... \)
```

with:

```text
$...$
```

The existing PDF contains raw commands such as `\ldots` and `\frac`, so this
must be corrected before reviewing slide layout or wording.

### 2. Match the quaternion snippets to the array-based implementation

On “Axis-angle constructor”, replace the undefined helper:

```ruby
ax, ay, az = normalize(axis)
```

with:

```ruby
ax, ay, az = normalize_vector(axis)
```

On “Rotating a vector”, replace the undefined `Vector3` API with the exact
array-based shape used by the implementation plan:

```ruby
def rotate(vector)
  point = Quaternion.new(0, *vector)
  result = self * point * conjugate

  [result.x, result.y, result.z]
end
```

The shorter splat form is suitable for the slide and is equivalent to the
expanded component access in the full implementation.

### 3. Match projection constants to the planned cube

The implementation plan uses:

- cube size `130`;
- camera distance `5`;
- screen centre `[640, 380]`.

Change the “Projection” snippet to those values:

```ruby
def project(x, y, z)
  camera = 5.0
  scale = camera / (camera - z)

  [
    640 + x * 130 * scale,
    380 + y * 130 * scale
  ]
end
```

Do not change the implementation to the slide's current `160` and `360`
values merely for visual alignment.

### 4. Remove the undefined drawing helper

The “Drawing the cube” slide calls `line(points[a], points[b])`, but the
implementation defines no `line` helper. Replace it with a compact version of
the actual DragonRuby line hashes:

```ruby
Cube::EDGES.each do |from_index, to_index|
  x1, y1 = points[from_index]
  x2, y2 = points[to_index]

  args.outputs.lines << {
    x: x1, y: y1, x2: x2, y2: y2
  }
end
```

If this is too dense at presentation size, split projection and drawing across
two slides rather than introducing an unimplemented helper.

### 5. Make the DragonRuby entry point honest

The checkout and implementation plan use `module Main`. On “Why DragonRuby?”,
either label the current `def tick(args)` fragment as simplified pseudocode or
show the actual entry shape:

```ruby
module Main
  def tick(args)
    # update state
    # draw frame
  end
end
```

Use the same shape on “What DragonRuby is doing” if that slide is intended to
show repository code rather than conceptual pseudocode.

### 6. Present one live demo, then future directions

The quick implementation does not provide four live demos. Adjust the headings
and wording so only the keyboard/order sequence is presented as live.

#### Current “Demo 1: arbitrary axis rotation”

Rename this to “One rotation, any axis” or “Next: an arbitrary axis”. Keep the
`[1, 1, 1]` code as a conceptual extension, and state that it is the next
implementation milestone rather than part of the quick demo.

Do not add automatic mode to the first implementation solely to preserve the
current “Demo 1” label.

#### Current “Demo 2: order matters”

Keep this as the live demo, but use the implemented 15-degree step and actual
input structure:

```ruby
rotation = Quaternion.from_axis_angle(
  [1, 0, 0],
  ROTATION_STEP
)

args.state.orientation =
  (rotation * args.state.orientation).normalized
```

The slide can omit the negative-axis controls; the dedicated controls slide
will show the full mapping.

For a visually clear 90-degree comparison, use these sequences:

```text
R, X, X, X, X, X, X, Y, Y, Y, Y, Y, Y
R, Y, Y, Y, Y, Y, Y, X, X, X, X, X, X
```

In presenter notes and concise slide copy, abbreviate them as:

```text
R, X×6, Y×6
R, Y×6, X×6
```

This demonstrates the same 90-degree order difference as the draft without
changing `ROTATION_STEP` from `Math::PI / 12.0`.

#### Current “Demo 3: smooth orientation travel”

Rename it to “Where this goes next: SLERP”. State that
`Quaternion.slerp` is illustrative and is not implemented in the quick demo.

#### Current “Demo 4: from cube to spectacle”

Rename it to “Beyond the cube”. Use future-tense wording for the gemstone,
crane, trails, and other visual ideas.

Use the same future framing on “Construction-site callback” so it does not
imply that the first milestone includes a crane scene.

### 7. Add the actual live controls

Insert a controls slide immediately before the live order demonstration:

```markdown
# Live demo controls

- **X / Y / Z** — rotate +15° around world axes
- **J / K / L** — rotate -15° around world axes
- **R** — reset to identity
- Compare **R, X×6, Y×6** with **R, Y×6, X×6**
```

This slide should replace, not supplement, any proposed controls that mention
automatic mode or 90-degree single-key steps.

## Slide-by-slide checklist

| Slide or section | Required correction |
| --- | --- |
| Front matter | Add `math: mathjax` |
| All mathematics | Use `$...$` and `$$...$$` delimiters |
| Why DragonRuby? | Use `module Main` or label the code as pseudocode |
| Axis-angle constructor | Use `normalize_vector` |
| Rotating a vector | Use arrays; remove `Vector3` |
| Projection | Use camera `5`, size `130`, centre `[640, 380]` |
| Drawing the cube | Replace the undefined `line` helper |
| Arbitrary-axis section | Present as the next milestone, not a live demo |
| Order-matters section | Use 15-degree code and the `X×6` / `Y×6` run sheet |
| SLERP section | Present as unimplemented future work |
| Spectacle and crane sections | Use future-tense wording |
| Before the live sequence | Add the actual controls slide |

## Optional pacing pass

This is separate from correctness and implementation alignment.

The current deck exports to 39 slides. If the talk slot is around 20 minutes:

1. merge the natural-number and integer slides;
2. merge the rational-number and real-number slides;
3. keep the complex-number rotation bridge;
4. keep axis-angle, point rotation, and the live order demo;
5. combine the gemstone and construction-site ideas into one future-work slide.

Do not make these pacing cuts until the available talk time is known.

## Verification

After applying the corrections:

1. export `slides/quaternions_dragonruby_marp.pdf`;
2. confirm no raw TeX commands appear in the rendered slides;
3. check code blocks for clipping at presentation size;
4. compare every code identifier and constant against
   `doc/plan/2026-07-20-wire-up-quick-demo.md`;
5. run the implemented demo from a reset state;
6. rehearse `R, X×6, Y×6` and `R, Y×6, X×6`;
7. confirm slides describe arbitrary-axis rotation, SLERP, and spectacle work
   as future milestones rather than shipped behavior.

## References

- [DragonRuby documentation](https://docs.dragonruby.org/static/docs.html)
- [Marp Core math typesetting](https://github.com/marp-team/marp-core#math-typesetting)
