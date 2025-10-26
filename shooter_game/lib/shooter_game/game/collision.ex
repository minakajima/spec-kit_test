defmodule ShooterGame.Game.Collision do
  @moduledoc """
  Collision detection utilities for the shooter game.
  Provides efficient collision detection between game entities using bounding boxes.
  """

  alias ShooterGame.Game.{Player, Enemy, Bullet}

  @type collision_result :: {boolean(), any()}
  @type bounding_box :: {float(), float(), float(), float()}

  @doc """
  Checks collision between two bounding boxes.
  Each bounding box is a tuple {left, top, right, bottom}.
  """
  @spec boxes_collide?(bounding_box(), bounding_box()) :: boolean()
  def boxes_collide?({left1, top1, right1, bottom1}, {left2, top2, right2, bottom2}) do
    not (left1 >= right2 or right1 <= left2 or top1 >= bottom2 or bottom1 <= top2)
  end

  @doc """
  Enhanced collision detection using circular collision for better accuracy.
  Returns true if two circles overlap.
  """
  @spec circles_collide?(float(), float(), float(), float(), float(), float()) :: boolean()
  def circles_collide?(x1, y1, r1, x2, y2, r2) do
    dx = x1 - x2
    dy = y1 - y2
    distance_squared = dx * dx + dy * dy
    radius_sum_squared = (r1 + r2) * (r1 + r2)
    distance_squared <= radius_sum_squared
  end

  @doc """
  Hybrid collision detection using both bounding box and circular collision.
  First checks bounding box (fast), then circular collision (accurate).
  """
  @spec precise_collision?(any(), any()) :: boolean()
  def precise_collision?(entity1, entity2) do
    # Quick bounding box check first
    box1 = get_bounding_box(entity1)
    box2 = get_bounding_box(entity2)
    
    if boxes_collide?(box1, box2) do
      # More precise circular collision check
      {x1, y1, r1} = get_collision_circle(entity1)
      {x2, y2, r2} = get_collision_circle(entity2)
      circles_collide?(x1, y1, r1, x2, y2, r2)
    else
      false
    end
  end

  @doc """
  Gets collision circle for an entity (x, y, radius).
  """
  @spec get_collision_circle(any()) :: {float(), float(), float()}
  def get_collision_circle(%Player{x: x, y: y, width: w, height: h}) do
    {x, y, min(w, h) / 2.5}
  end

  def get_collision_circle(%Enemy{x: x, y: y, width: w, height: h}) do
    {x, y, min(w, h) / 2.2}
  end

  def get_collision_circle(%Bullet{x: x, y: y, width: w, height: h}) do
    {x, y, min(w, h) / 2.0}
  end

  @doc """
  Gets bounding box for any entity.
  """
  @spec get_bounding_box(any()) :: bounding_box()
  def get_bounding_box(%Player{} = player), do: Player.bounding_box(player)
  def get_bounding_box(%Enemy{} = enemy), do: Enemy.bounding_box(enemy)
  def get_bounding_box(%Bullet{} = bullet), do: Bullet.bounding_box(bullet)

  @doc """
  Enhanced collision between player and enemy using precise detection.
  """
  @spec player_enemy_collision?(Player.t(), Enemy.t()) :: boolean()
  def player_enemy_collision?(%Player{} = player, %Enemy{} = enemy) do
    # Use precise collision for player-enemy collisions (critical for gameplay)
    precise_collision?(player, enemy)
  end

  @doc """
  Enhanced collision between bullet and player.
  Only enemy bullets can hit players.
  """
  @spec bullet_player_collision?(Bullet.t(), Player.t()) :: boolean()
  def bullet_player_collision?(%Bullet{owner_type: :enemy} = bullet, %Player{} = player) do
    # Use precise collision for bullet-player collisions (critical for damage)
    precise_collision?(bullet, player)
  end

  def bullet_player_collision?(%Bullet{}, %Player{}), do: false

  @doc """
  Enhanced collision between bullet and enemy.
  Only player bullets can hit enemies.
  """
  @spec bullet_enemy_collision?(Bullet.t(), Enemy.t()) :: boolean()
  def bullet_enemy_collision?(%Bullet{owner_type: :player} = bullet, %Enemy{} = enemy) do
    # Use bounding box for bullet-enemy (faster, sufficient accuracy for scoring)
    bullet_box = Bullet.bounding_box(bullet)
    enemy_box = Enemy.bounding_box(enemy)
    boxes_collide?(bullet_box, enemy_box)
  end

  def bullet_enemy_collision?(%Bullet{}, %Enemy{}), do: false

  @doc """
  Finds all collisions between player bullets and enemies.
  Returns list of {bullet, enemy} tuples that are colliding.
  """
  @spec find_bullet_enemy_collisions([Bullet.t()], [Enemy.t()]) :: [{Bullet.t(), Enemy.t()}]
  def find_bullet_enemy_collisions(bullets, enemies) do
    for bullet <- bullets,
        bullet.owner_type == :player,
        enemy <- enemies,
        Enemy.alive?(enemy),
        bullet_enemy_collision?(bullet, enemy) do
      {bullet, enemy}
    end
  end

  @doc """
  Finds all collisions between enemy bullets and the player.
  Returns list of bullets that hit the player.
  """
  @spec find_bullet_player_collisions([Bullet.t()], Player.t()) :: [Bullet.t()]
  def find_bullet_player_collisions(bullets, %Player{} = player) do
    if Player.alive?(player) do
      for bullet <- bullets,
          bullet.owner_type == :enemy,
          bullet_player_collision?(bullet, player) do
        bullet
      end
    else
      []
    end
  end

  @doc """
  Finds all collisions between enemies and the player.
  Returns list of enemies that are colliding with player.
  """
  @spec find_player_enemy_collisions([Enemy.t()], Player.t()) :: [Enemy.t()]
  def find_player_enemy_collisions(enemies, %Player{} = player) do
    if Player.alive?(player) do
      for enemy <- enemies,
          Enemy.alive?(enemy),
          player_enemy_collision?(player, enemy) do
        enemy
      end
    else
      []
    end
  end

  @doc """
  Checks if a point is within a bounding box.
  Useful for mouse click detection.
  """
  @spec point_in_box?(number(), number(), bounding_box()) :: boolean()
  def point_in_box?(x, y, {left, top, right, bottom}) do
    x >= left and x <= right and y >= top and y <= bottom
  end

  @doc """
  Checks if a circular area collides with a bounding box.
  Useful for explosion effects or area-of-effect damage.
  """
  @spec circle_box_collision?(number(), number(), number(), bounding_box()) :: boolean()
  def circle_box_collision?(circle_x, circle_y, radius, {left, top, right, bottom}) do
    # Find the closest point on the rectangle to the circle center
    closest_x = clamp(circle_x, left, right)
    closest_y = clamp(circle_y, top, bottom)
    
    # Calculate distance from circle center to closest point
    dx = circle_x - closest_x
    dy = circle_y - closest_y
    distance_squared = dx * dx + dy * dy
    
    # Check if distance is less than radius
    distance_squared <= radius * radius
  end

  @doc """
  Performs broad-phase collision detection using spatial partitioning.
  Groups entities by grid cells to reduce collision checks.
  """
  @spec spatial_partition([any()], pos_integer(), pos_integer(), pos_integer()) :: %{
          {integer(), integer()} => [any()]
        }
  def spatial_partition(entities, game_width, game_height, cell_size) do
    entities
    |> Enum.reduce(%{}, fn entity, acc ->
      {x, y} = get_entity_position(entity)
      grid_x = trunc(x / cell_size)
      grid_y = trunc(y / cell_size)
      
      Map.update(acc, {grid_x, grid_y}, [entity], &[entity | &1])
    end)
  end

  @doc """
  Optimized collision detection using spatial partitioning.
  Only checks entities in the same or adjacent grid cells.
  """
  @spec find_collisions_optimized([any()], [any()], pos_integer(), pos_integer(), function()) :: [
          any()
        ]
  def find_collisions_optimized(entities_a, entities_b, game_width, game_height, collision_fn) do
    cell_size = 100  # 100 pixel grid cells
    
    partition_a = spatial_partition(entities_a, game_width, game_height, cell_size)
    partition_b = spatial_partition(entities_b, game_width, game_height, cell_size)
    
    for {{grid_x, grid_y}, group_a} <- partition_a,
        group_b <- get_adjacent_groups(partition_b, grid_x, grid_y),
        entity_a <- group_a,
        entity_b <- group_b,
        collision_fn.(entity_a, entity_b) do
      {entity_a, entity_b}
    end
  end

  @doc """
  Checks if an entity is within screen bounds (with optional margin).
  """
  @spec within_bounds?(any(), pos_integer(), pos_integer(), integer()) :: boolean()
  def within_bounds?(entity, game_width, game_height, margin \\ 0) do
    {x, y} = get_entity_position(entity)
    {width, height} = get_entity_size(entity)
    
    x + width / 2 >= -margin and
      x - width / 2 <= game_width + margin and
      y + height / 2 >= -margin and
      y - height / 2 <= game_height + margin
  end

  @doc """
  Calculates the overlap area between two bounding boxes.
  Returns {width, height} of overlap, or {0, 0} if no overlap.
  """
  @spec overlap_area(bounding_box(), bounding_box()) :: {float(), float()}
  def overlap_area({left1, top1, right1, bottom1}, {left2, top2, right2, bottom2}) do
    if boxes_collide?({left1, top1, right1, bottom1}, {left2, top2, right2, bottom2}) do
      overlap_left = max(left1, left2)
      overlap_top = max(top1, top2)
      overlap_right = min(right1, right2)
      overlap_bottom = min(bottom1, bottom2)
      
      {overlap_right - overlap_left, overlap_bottom - overlap_top}
    else
      {0.0, 0.0}
    end
  end

  @doc """
  Calculates the distance between two entities' centers.
  """
  @spec distance_between(any(), any()) :: float()
  def distance_between(entity1, entity2) do
    {x1, y1} = get_entity_position(entity1)
    {x2, y2} = get_entity_position(entity2)
    
    dx = x2 - x1
    dy = y2 - y1
    
    :math.sqrt(dx * dx + dy * dy)
  end

  # Private helper functions

  defp clamp(value, min_val, max_val) do
    value |> max(min_val) |> min(max_val)
  end

  defp get_entity_position(%Player{x: x, y: y}), do: {x, y}
  defp get_entity_position(%Enemy{x: x, y: y}), do: {x, y}
  defp get_entity_position(%Bullet{x: x, y: y}), do: {x, y}
  defp get_entity_position(%{x: x, y: y}), do: {x, y}

  defp get_entity_size(%Player{width: w, height: h}), do: {w, h}
  defp get_entity_size(%Enemy{width: w, height: h}), do: {w, h}
  defp get_entity_size(%Bullet{width: w, height: h}), do: {w, h}
  defp get_entity_size(%{width: w, height: h}), do: {w, h}

  defp get_adjacent_groups(partition, grid_x, grid_y) do
    # Get entities from current cell and 8 adjacent cells
    for dx <- -1..1,
        dy <- -1..1 do
      Map.get(partition, {grid_x + dx, grid_y + dy}, [])
    end
    |> List.flatten()
  end
end