---
name: dragonruby-pathfinding
description: Pathfinding algorithms in DragonRuby GTK — A*, BFS, flood fill, priority queues, spatial hashing, quad trees, line-of-sight. Use when the user asks about enemy AI navigation, movement grids, or reachability.
---

This skill covers spatial algorithms for DragonRuby games. For built-in geometry utilities see the main `dragonruby` skill.

## A* Pathfinding

### Priority queue (min-heap)

```ruby
class PriorityQueue
  def initialize(&has_priority)
    @ary = []
    @has_priority = has_priority
  end

  def push(item)
    @ary << item
    heapify_up(@ary.length - 1)
  end

  def pop
    return @ary.pop if @ary.length == 1
    top = @ary[0]
    @ary[0] = @ary.pop
    heapify_down(0)
    top
  end

  def empty? = @ary.empty?

  private

  def heapify_up(i)
    return if i == 0
    parent = (i - 1) / 2
    if @has_priority.call(@ary[i], @ary[parent])
      @ary[i], @ary[parent] = @ary[parent], @ary[i]
      heapify_up(parent)
    end
  end

  def heapify_down(i)
    l = 2 * i + 1; r = 2 * i + 2; top = i
    top = l if l < @ary.length && @has_priority.call(@ary[l], @ary[top])
    top = r if r < @ary.length && @has_priority.call(@ary[r], @ary[top])
    if top != i
      @ary[i], @ary[top] = @ary[top], @ary[i]
      heapify_down(top)
    end
  end
end
```

### Manhattan distance heuristic

```ruby
def manhattan(a, b)
  (a[:x] - b[:x]).abs + (a[:y] - b[:y]).abs
end
```

### A* solver (incremental — one step per tick for visualisation)

```ruby
def init_astar(args, start, goal, walls)
  args.state.astar = {
    frontier:  PriorityQueue.new { |a, b| a[:priority] < b[:priority] },
    came_from: { start => nil },
    cost_so_far: { start => 0 },
    goal: goal,
    walls: walls,
    path: nil
  }
  args.state.astar.frontier.push({ loc: start, priority: 0 })
end

def step_astar(args)
  a = args.state.astar
  return if a.frontier.empty? || a.path

  current = a.frontier.pop[:loc]

  if current == a.goal
    # Reconstruct path
    path = []; node = a.goal
    while node
      path.unshift(node)
      node = a.came_from[node]
    end
    a.path = path
    return
  end

  neighbors(current, a.walls).each do |next_loc|
    new_cost = a.cost_so_far[current] + 1
    next if a.cost_so_far.key?(next_loc) && a.cost_so_far[next_loc] <= new_cost

    a.cost_so_far[next_loc] = new_cost
    a.came_from[next_loc] = current
    priority = new_cost + manhattan(next_loc, a.goal)
    a.frontier.push({ loc: next_loc, priority: priority })
  end
end

def neighbors(loc, walls, grid_w: 20, grid_h: 15)
  [[0,1],[0,-1],[1,0],[-1,0]].filter_map do |dx, dy|
    n = { x: loc[:x] + dx, y: loc[:y] + dy }
    next if n[:x] < 0 || n[:y] < 0 || n[:x] >= grid_w || n[:y] >= grid_h
    next if walls[n]
    n
  end
end
```

### Full A* (blocking, returns path immediately)

```ruby
def astar(start, goal, walls, grid_w:, grid_h:)
  frontier = PriorityQueue.new { |a, b| a[:priority] < b[:priority] }
  frontier.push({ loc: start, priority: 0 })
  came_from = { start => nil }
  cost = { start => 0 }

  until frontier.empty?
    current = frontier.pop[:loc]
    break if current == goal

    neighbors(current, walls, grid_w: grid_w, grid_h: grid_h).each do |n|
      new_cost = cost[current] + 1
      next if cost.key?(n) && cost[n] <= new_cost
      cost[n] = new_cost
      came_from[n] = current
      frontier.push({ loc: n, priority: new_cost + manhattan(n, goal) })
    end
  end

  # Reconstruct
  return nil unless came_from.key?(goal)
  path = []; node = goal
  while node; path.unshift(node); node = came_from[node]; end
  path
end
```

## Breadth-First Search (BFS)

Simple BFS — good for unweighted grids, tower defence flows:

```ruby
def bfs(start, goal, walls, grid_w:, grid_h:)
  frontier  = [start]
  came_from = { start => nil }

  until frontier.empty?
    current = frontier.shift
    break if current == goal

    neighbors(current, walls, grid_w: grid_w, grid_h: grid_h).each do |n|
      next if came_from.key?(n)
      came_from[n] = current
      frontier << n
    end
  end

  return nil unless came_from.key?(goal)
  path = []; node = goal
  while node; path.unshift(node); node = came_from[node]; end
  path
end
```

### Reverse BFS (flow field for tower defence)

Build a came-from map from the goal outward — every enemy can look up next step in O(1):

```ruby
def build_flow_field(goal, walls, grid_w:, grid_h:)
  frontier  = [goal]
  came_from = { goal => nil }

  until frontier.empty?
    current = frontier.shift
    neighbors(current, walls, grid_w: grid_w, grid_h: grid_h).each do |n|
      next if came_from.key?(n)
      came_from[n] = current
      frontier << n
    end
  end
  came_from
end

# Enemy step: just look up next cell
next_cell = flow_field[enemy_current_cell]
```

## Flood Fill (Reachability / Move Range)

Find all cells reachable within a movement budget:

```ruby
def flood_fill(start, walls, max_steps:, grid_w:, grid_h:, diagonal_cost: 2)
  queue   = [{ loc: start, steps: 0 }]
  visited = { start => 0 }

  until queue.empty?
    current = queue.shift
    loc, steps = current[:loc], current[:steps]

    [  [0,1,1],[0,-1,1],[1,0,1],[-1,0,1],       # cardinal
       [1,1,diagonal_cost],[-1,1,diagonal_cost],  # diagonal
       [1,-1,diagonal_cost],[-1,-1,diagonal_cost]
    ].each do |dx, dy, cost|
      n        = { x: loc[:x] + dx, y: loc[:y] + dy }
      new_cost = steps + cost
      next if walls[n]
      next if n[:x] < 0 || n[:y] < 0 || n[:x] >= grid_w || n[:y] >= grid_h
      next if new_cost > max_steps
      next if visited.key?(n) && visited[n] <= new_cost

      visited[n] = new_cost
      queue << { loc: n, steps: new_cost }
    end
  end
  visited.keys
end
```

## Line of Sight

### Simple raycast LOS

```ruby
def line_of_sight?(from, to, walls)
  dx = to[:x] - from[:x]; dy = to[:y] - from[:y]
  steps = [dx.abs, dy.abs].max
  return true if steps == 0

  sx = dx.to_f / steps; sy = dy.to_f / steps
  (1...steps).each do |i|
    cx = (from[:x] + sx * i).round
    cy = (from[:y] + sy * i).round
    return false if walls[{ x: cx, y: cy }]
  end
  true
end
```

### Thick LOS (roguelike visibility — casts multiple lines)

```ruby
def compute_visible_cells(origin, walls, radius:, grid_w:, grid_h:)
  visible = Set.new
  variations = (-radius..radius).to_a

  variations.product(variations).each do |rise, run|
    next if rise == 0 && run == 0
    x = origin[:x]; y = origin[:y]; dist = 0

    while dist <= radius
      cell = { x: x.round, y: y.round }
      break if cell[:x] < 0 || cell[:y] < 0 || cell[:x] >= grid_w || cell[:y] >= grid_h
      visible.add(cell)
      break if walls[cell]
      x += run.to_f / radius; y += rise.to_f / radius; dist += 1
    end
  end
  visible
end
```

## Spatial Hashing

O(1) cell lookup — much faster than array searching for large grids:

```ruby
# Build lookup:
args.state.entity_lookup = {}
args.state.entities.each do |e|
  key = [e[:grid_x], e[:grid_y]]
  args.state.entity_lookup[key] = e
end

# Query:
cell = args.state.entity_lookup[[5, 3]]

# Also use for walls:
walls = {}
wall_list.each { |w| walls[[w[:x], w[:y]]] = true }
blocked = walls[[nx, ny]]
```

## Heat-Seeking Projectile

Bullets that always track to the current position of their target (passed by reference):

```ruby
args.state.bullets << {
  x: player.x, y: player.y, w: 8, h: 8,
  speed: 4,
  target: enemy   # reference — updates as enemy moves
}

args.state.bullets.each do |b|
  angle = Geometry.angle(b, b[:target])
  b.x += angle.vector_x * b[:speed]
  b.y += angle.vector_y * b[:speed]
end
```

## Pathfinding Visualisation

Render A* frontier / visited / path for debugging:

```ruby
def render_astar_debug(args, astar, tile_size: 32)
  astar.came_from.each_key do |loc|
    args.outputs.solids << {
      x: loc[:x] * tile_size, y: loc[:y] * tile_size,
      w: tile_size, h: tile_size,
      r: 0, g: 0, b: 200, a: 80
    }
  end
  return unless astar.path
  astar.path.each do |loc|
    args.outputs.solids << {
      x: loc[:x] * tile_size, y: loc[:y] * tile_size,
      w: tile_size, h: tile_size,
      r: 255, g: 200, b: 0, a: 180
    }
  end
end
```

## Grid Coordinate Helpers

```ruby
TILE = 32

def world_to_grid(x, y)
  { x: x.idiv(TILE), y: y.idiv(TILE) }
end

def grid_to_world(gx, gy)
  { x: gx * TILE, y: gy * TILE, w: TILE, h: TILE }
end

# Snap mouse to grid:
def grid_snap(mouse_x, mouse_y)
  { x: mouse_x.idiv(TILE) * TILE, y: mouse_y.idiv(TILE) * TILE }
end
```

## Diagonal Movement Rules

For tile-based games, prevent corner-cutting:

```ruby
def can_move_diagonal?(walls, from, dx, dy)
  return false if walls[[from[:x] + dx, from[:y]]]
  return false if walls[[from[:x], from[:y] + dy]]
  return false if walls[[from[:x] + dx, from[:y] + dy]]
  true
end
```

## Modular Tick-by-Tick Solver

Spread expensive computation across frames so the game stays responsive:

```ruby
args.state.solver_mode ||= :idle

def tick_solver(args)
  case args.state.solver_mode
  when :idle
    # nothing
  when :solving
    10.times { step_astar(args) }  # process 10 steps per tick
    args.state.solver_mode = :done if args.state.astar.path || args.state.astar.frontier.empty?
  when :done
    # use args.state.astar.path
  end
end
```
