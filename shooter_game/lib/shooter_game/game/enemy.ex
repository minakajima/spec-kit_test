defmodule ShooterGame.Game.Enemy do
  @moduledoc """
  Enemy represents an enemy ship in the shooter game.
  Enemies move in curved patterns, shoot at the player at intervals,
  and can be destroyed by player bullets.
  """

  @derive Jason.Encoder
  @enforce_keys [:x, :y, :id]
  defstruct [
    # Identity & Position
    :id, :x, :y,                # id: unique identifier, x/y: float coordinates
    
    # Physical properties
    health: 1,                  # integer (health points)
    width: 30,                  # integer (pixels)
    height: 30,                 # integer (pixels)
    
    # Movement properties
    velocity_x: 0.0,            # float (pixels per frame)
    velocity_y: 2.0,            # float (pixels per frame) - default downward movement
    curve_amplitude: 50.0,      # float - how wide the curve is
    curve_frequency: 0.1,       # float - how fast the curve oscillates
    movement_time: 0.0,         # float - accumulated time for curve calculation
    
    # Combat properties
    last_shot_time: 0,          # monotonic time of last shot
    shot_interval: 1500,        # milliseconds between shots (1.5s as per spec C)
    shot_accuracy: 0.8,         # float 0-1, how accurate shots are toward player
    
    # Enemy behavior type
    behavior: :curved_shooter,   # :curved_shooter | :straight | :zigzag | :spinner
    
    # Visual properties
    color: :red,                # :red | :green | :purple (different enemy types)
    angle: 0.0,                 # rotation angle in radians
    
    # Spawning properties
    spawn_time: 0,              # monotonic time when enemy was created
    
    # Score value
    points: 10                  # points awarded when destroyed
  ]

  @type behavior :: :curved_shooter | :straight | :zigzag | :spinner
  @type color :: :red | :green | :purple
  
  @type t :: %__MODULE__{
    id: String.t(),
    x: float(),
    y: float(),
    health: pos_integer(),
    width: pos_integer(),
    height: pos_integer(),
    velocity_x: float(),
    velocity_y: float(),
    curve_amplitude: float(),
    curve_frequency: float(),
    movement_time: float(),
    last_shot_time: integer(),
    shot_interval: pos_integer(),
    shot_accuracy: float(),
    behavior: behavior(),
    color: color(),
    angle: float(),
    spawn_time: integer(),
    points: pos_integer()
  }

  @doc """
  Creates a new enemy at the specified position with a unique ID.
  """
  @spec new(number(), number()) :: t()
  def new(x, y) do
    current_time = :erlang.monotonic_time(:millisecond)
    
    %__MODULE__{
      id: generate_id(),
      x: x,
      y: y,
      last_shot_time: current_time,
      spawn_time: current_time
    }
  end

  @doc """
  Creates a new enemy with custom properties.
  """
  @spec new(number(), number(), keyword()) :: t()
  def new(x, y, opts \\ []) do
    current_time = :erlang.monotonic_time(:millisecond)
    
    %__MODULE__{
      id: Keyword.get(opts, :id, generate_id()),
      x: x,
      y: y,
      health: Keyword.get(opts, :health, 1),
      width: Keyword.get(opts, :width, 30),
      height: Keyword.get(opts, :height, 30),
      velocity_x: Keyword.get(opts, :velocity_x, 0.0),
      velocity_y: Keyword.get(opts, :velocity_y, 2.0),
      curve_amplitude: Keyword.get(opts, :curve_amplitude, 50.0),
      curve_frequency: Keyword.get(opts, :curve_frequency, 0.1),
      shot_interval: Keyword.get(opts, :shot_interval, 1500),
      shot_accuracy: Keyword.get(opts, :shot_accuracy, 0.8),
      behavior: Keyword.get(opts, :behavior, :curved_shooter),
      color: Keyword.get(opts, :color, :red),
      points: Keyword.get(opts, :points, 10),
      last_shot_time: current_time,
      spawn_time: current_time
    }
  end

  @doc """
  Updates enemy position based on its movement behavior.
  """
  @spec update_position(t(), float()) :: t()
  def update_position(%__MODULE__{behavior: :curved_shooter} = enemy, delta_time) do
    # Curved movement with oscillation
    new_movement_time = enemy.movement_time + delta_time
    
    # Calculate curve offset
    curve_offset = :math.sin(new_movement_time * enemy.curve_frequency) * enemy.curve_amplitude
    
    # Update position
    new_x = enemy.x + curve_offset * delta_time * 0.1  # Scale down the curve effect
    new_y = enemy.y + enemy.velocity_y * delta_time
    new_angle = :math.sin(new_movement_time * enemy.curve_frequency * 2) * 0.5  # Rotating effect
    
    %{enemy |
      x: new_x,
      y: new_y,
      movement_time: new_movement_time,
      angle: new_angle
    }
  end

  def update_position(%__MODULE__{behavior: :straight} = enemy, delta_time) do
    # Simple straight movement
    new_x = enemy.x + enemy.velocity_x * delta_time
    new_y = enemy.y + enemy.velocity_y * delta_time
    
    %{enemy | x: new_x, y: new_y}
  end

  def update_position(%__MODULE__{behavior: :zigzag} = enemy, delta_time) do
    # Zigzag pattern
    new_movement_time = enemy.movement_time + delta_time
    direction = if rem(trunc(new_movement_time * 2), 2) == 0, do: 1, else: -1
    
    new_x = enemy.x + enemy.velocity_x * direction * delta_time
    new_y = enemy.y + enemy.velocity_y * delta_time
    
    %{enemy |
      x: new_x,
      y: new_y,
      movement_time: new_movement_time
    }
  end

  def update_position(%__MODULE__{behavior: :spinner} = enemy, delta_time) do
    # Spinning movement
    new_movement_time = enemy.movement_time + delta_time
    new_angle = enemy.angle + delta_time * 5.0  # 5 radians per second
    
    new_x = enemy.x + enemy.velocity_x * delta_time
    new_y = enemy.y + enemy.velocity_y * delta_time
    
    %{enemy |
      x: new_x,
      y: new_y,
      movement_time: new_movement_time,
      angle: new_angle
    }
  end

  @doc """
  Checks if the enemy can shoot (interval has elapsed).
  """
  @spec can_shoot?(t()) :: boolean()
  def can_shoot?(%__MODULE__{last_shot_time: last_shot, shot_interval: interval}) do
    current_time = :erlang.monotonic_time(:millisecond)
    current_time - last_shot >= interval
  end

  @doc """
  Updates the last shot time to current time.
  """
  @spec record_shot(t()) :: t()
  def record_shot(%__MODULE__{} = enemy) do
    %{enemy | last_shot_time: :erlang.monotonic_time(:millisecond)}
  end

  @doc """
  Calculates shot direction toward player with accuracy variance.
  Returns {velocity_x, velocity_y} for bullet.
  """
  @spec calculate_shot_direction(t(), float(), float(), float()) :: {float(), float()}
  def calculate_shot_direction(%__MODULE__{} = enemy, player_x, player_y, bullet_speed) do
    # Vector from enemy to player
    dx = player_x - enemy.x
    dy = player_y - enemy.y
    distance = :math.sqrt(dx * dx + dy * dy)
    
    # Normalize direction
    norm_dx = dx / distance
    norm_dy = dy / distance
    
    # Apply accuracy (add some randomness based on accuracy)
    accuracy_variance = 1.0 - enemy.shot_accuracy
    random_angle = (:rand.uniform() - 0.5) * accuracy_variance * :math.pi() / 2
    
    # Rotate the direction by random angle
    cos_angle = :math.cos(random_angle)
    sin_angle = :math.sin(random_angle)
    
    final_dx = norm_dx * cos_angle - norm_dy * sin_angle
    final_dy = norm_dx * sin_angle + norm_dy * cos_angle
    
    {final_dx * bullet_speed, final_dy * bullet_speed}
  end

  @doc """
  Damages the enemy (reduces health).
  """
  @spec take_damage(t(), pos_integer()) :: t()
  def take_damage(%__MODULE__{health: health} = enemy, damage) do
    new_health = max(0, health - damage)
    %{enemy | health: new_health}
  end

  @doc """
  Checks if the enemy is alive.
  """
  @spec alive?(t()) :: boolean()
  def alive?(%__MODULE__{health: health}), do: health > 0

  @doc """
  Checks if the enemy is off-screen (should be removed).
  """
  @spec off_screen?(t(), pos_integer(), pos_integer()) :: boolean()
  def off_screen?(%__MODULE__{x: x, y: y, width: width, height: height}, game_width, game_height) do
    x + width / 2 < 0 or                    # Left of screen
    x - width / 2 > game_width or           # Right of screen  
    y + height / 2 < 0 or                   # Above screen
    y - height / 2 > game_height            # Below screen
  end

  @doc """
  Gets the enemy's bounding box for collision detection.
  Returns {left, top, right, bottom}.
  """
  @spec bounding_box(t()) :: {float(), float(), float(), float()}
  def bounding_box(%__MODULE__{x: x, y: y, width: width, height: height}) do
    half_width = width / 2
    half_height = height / 2
    
    {
      x - half_width,    # left
      y - half_height,   # top
      x + half_width,    # right  
      y + half_height    # bottom
    }
  end

  @doc """
  Gets the bullet spawn position (front of the enemy ship).
  """
  @spec bullet_spawn_position(t()) :: {float(), float()}
  def bullet_spawn_position(%__MODULE__{x: x, y: y, height: height}) do
    # Enemy bullets spawn from the bottom of the enemy ship
    {x, y + height / 2}
  end

  @doc """
  Gets enemy age in milliseconds since spawn.
  """
  @spec age(t()) :: integer()
  def age(%__MODULE__{spawn_time: spawn_time}) do
    :erlang.monotonic_time(:millisecond) - spawn_time
  end

  # Private helper functions

  defp generate_id do
    # Generate a unique ID using timestamp and random number
    timestamp = :erlang.monotonic_time(:millisecond)
    random = :rand.uniform(999)
    "enemy_#{timestamp}_#{random}"
  end
end