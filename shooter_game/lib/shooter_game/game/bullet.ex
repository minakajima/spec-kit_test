defmodule ShooterGame.Game.Bullet do
  @moduledoc """
  Bullet represents projectiles in the shooter game.
  Bullets are fired by both players and enemies with different properties.
  """

  @derive Jason.Encoder
  @enforce_keys [:x, :y, :velocity_x, :velocity_y, :owner_type, :id]
  defstruct [
    # Identity & Position
    :id, :x, :y,                # id: unique identifier, x/y: float coordinates
    
    # Movement
    :velocity_x, :velocity_y,   # float (pixels per frame)
    
    # Properties
    owner_type: :player,        # :player | :enemy - who fired this bullet
    owner_id: nil,              # ID of the entity that fired this bullet
    damage: 1,                  # integer - damage dealt on hit
    
    # Physical properties
    width: 4,                   # integer (pixels) - bullet width
    height: 8,                  # integer (pixels) - bullet height
    
    # Visual properties
    color: :yellow,             # :yellow | :red | :blue | :green
    trail_length: 0,            # integer - trail effect length (0 = no trail)
    
    # Gameplay properties
    piercing: false,            # boolean - can hit multiple targets
    speed: 8.0,                 # float - bullet speed (for reference)
    
    # Enhanced movement (for enemy bullets)
    curve_type: :straight,      # :straight | :sine | :spiral | :homing
    curve_amplitude: 0.0,       # float - strength of curve effect
    curve_frequency: 0.1,       # float - frequency of curve oscillation
    movement_time: 0.0,         # float - accumulated time for curve calculations
    initial_velocity_x: 0.0,    # float - original velocity_x for curve calculations
    initial_velocity_y: 0.0,    # float - original velocity_y for curve calculations
    
    # Timing
    spawn_time: 0,              # monotonic time when bullet was created
    lifetime: 5000              # milliseconds - how long bullet lives
  ]

  @type owner_type :: :player | :enemy
  @type color :: :yellow | :red | :blue | :green | :white | :orange
  @type curve_type :: :straight | :sine | :spiral | :homing
  
  @type t :: %__MODULE__{
    id: String.t(),
    x: float(),
    y: float(),
    velocity_x: float(),
    velocity_y: float(),
    owner_type: owner_type(),
    owner_id: String.t() | nil,
    damage: pos_integer(),
    width: pos_integer(),
    height: pos_integer(),
    color: color(),
    trail_length: non_neg_integer(),
    piercing: boolean(),
    speed: float(),
    spawn_time: integer(),
    lifetime: pos_integer()
  }

  @doc """
  Creates a new player bullet with upward velocity.
  """
  @spec new_player_bullet(number(), number(), String.t() | nil) :: t()
  def new_player_bullet(x, y, player_id \\ nil) do
    %__MODULE__{
      id: generate_id(),
      x: x,
      y: y,
      velocity_x: 0.0,
      velocity_y: -8.0,           # Player bullets go up
      owner_type: :player,
      owner_id: player_id,
      color: :yellow,
      spawn_time: :erlang.monotonic_time(:millisecond)
    }
  end

  @doc """
  Creates a new enemy bullet with specified direction and curve type.
  """
  @spec new_enemy_bullet(number(), number(), number(), number(), String.t(), keyword()) :: t()
  def new_enemy_bullet(x, y, velocity_x, velocity_y, enemy_id, opts \\ []) do
    curve_type = Keyword.get(opts, :curve_type, :sine)
    curve_amplitude = Keyword.get(opts, :curve_amplitude, 50.0)
    
    %__MODULE__{
      id: generate_id(),
      x: x,
      y: y,
      velocity_x: velocity_x,
      velocity_y: velocity_y,
      owner_type: :enemy,
      owner_id: enemy_id,
      color: :red,
      width: 3,
      height: 6,
      curve_type: curve_type,
      curve_amplitude: curve_amplitude,
      curve_frequency: Keyword.get(opts, :curve_frequency, 0.1),
      movement_time: 0.0,
      initial_velocity_x: velocity_x,
      initial_velocity_y: velocity_y,
      spawn_time: :erlang.monotonic_time(:millisecond)
    }
  end

  @doc """
  Creates a bullet with custom properties.
  """
  @spec new(number(), number(), number(), number(), owner_type(), keyword()) :: t()
  def new(x, y, velocity_x, velocity_y, owner_type, opts \\ []) do
    %__MODULE__{
      id: Keyword.get(opts, :id, generate_id()),
      x: x,
      y: y,
      velocity_x: velocity_x,
      velocity_y: velocity_y,
      owner_type: owner_type,
      owner_id: Keyword.get(opts, :owner_id),
      damage: Keyword.get(opts, :damage, 1),
      width: Keyword.get(opts, :width, 4),
      height: Keyword.get(opts, :height, 8),
      color: Keyword.get(opts, :color, get_default_color(owner_type)),
      trail_length: Keyword.get(opts, :trail_length, 0),
      piercing: Keyword.get(opts, :piercing, false),
      speed: Keyword.get(opts, :speed, calculate_speed(velocity_x, velocity_y)),
      lifetime: Keyword.get(opts, :lifetime, 5000),
      spawn_time: :erlang.monotonic_time(:millisecond)
    }
  end

  @doc """
  Updates bullet position based on velocity and curve type.
  """
  @spec update_position(t(), float()) :: t()
  def update_position(%__MODULE__{curve_type: :straight} = bullet, delta_time) do
    new_x = bullet.x + bullet.velocity_x * delta_time
    new_y = bullet.y + bullet.velocity_y * delta_time
    
    %{bullet | x: new_x, y: new_y}
  end

  def update_position(%__MODULE__{curve_type: curve_type} = bullet, delta_time) do
    new_movement_time = bullet.movement_time + delta_time
    
    case curve_type do
      :sine ->
        update_position_sine(bullet, delta_time, new_movement_time)
      :spiral ->
        update_position_spiral(bullet, delta_time, new_movement_time)
      :homing ->
        update_position_homing(bullet, delta_time, new_movement_time)
      _ ->
        # Fallback to straight movement
        new_x = bullet.x + bullet.velocity_x * delta_time
        new_y = bullet.y + bullet.velocity_y * delta_time
        %{bullet | x: new_x, y: new_y, movement_time: new_movement_time}
    end
  end

  # Sine wave movement for curved enemy bullets
  defp update_position_sine(bullet, delta_time, new_movement_time) do
    # Base movement
    base_x = bullet.x + bullet.velocity_x * delta_time
    base_y = bullet.y + bullet.velocity_y * delta_time
    
    # Add sine wave offset
    sine_offset = bullet.curve_amplitude * :math.sin(new_movement_time * bullet.curve_frequency)
    
    # Apply offset perpendicular to movement direction
    if abs(bullet.initial_velocity_x) > abs(bullet.initial_velocity_y) do
      # Horizontal primary movement, offset vertically
      %{bullet | x: base_x, y: base_y + sine_offset, movement_time: new_movement_time}
    else
      # Vertical primary movement, offset horizontally
      %{bullet | x: base_x + sine_offset, y: base_y, movement_time: new_movement_time}
    end
  end

  # Spiral movement for advanced enemy bullets
  defp update_position_spiral(bullet, delta_time, new_movement_time) do
    base_x = bullet.x + bullet.velocity_x * delta_time
    base_y = bullet.y + bullet.velocity_y * delta_time
    
    # Spiral effect
    radius = bullet.curve_amplitude * (new_movement_time * 0.1)
    angle = new_movement_time * bullet.curve_frequency * 2
    
    spiral_x = radius * :math.cos(angle)
    spiral_y = radius * :math.sin(angle)
    
    %{bullet | 
      x: base_x + spiral_x, 
      y: base_y + spiral_y, 
      movement_time: new_movement_time
    }
  end

  # Simplified homing behavior (could be expanded with player position)
  defp update_position_homing(bullet, delta_time, new_movement_time) do
    # For now, just add slight wobble - true homing would need player position
    base_x = bullet.x + bullet.velocity_x * delta_time
    base_y = bullet.y + bullet.velocity_y * delta_time
    
    wobble = bullet.curve_amplitude * 0.1 * :math.sin(new_movement_time * bullet.curve_frequency * 5)
    
    %{bullet | 
      x: base_x + wobble, 
      y: base_y, 
      movement_time: new_movement_time
    }
  end

  @doc """
  Checks if bullet is off-screen and should be removed.
  """
  @spec off_screen?(t(), pos_integer(), pos_integer()) :: boolean()
  def off_screen?(%__MODULE__{x: x, y: y, width: width, height: height}, game_width, game_height) do
    x + width / 2 < 0 or                    # Left of screen
    x - width / 2 > game_width or           # Right of screen
    y + height / 2 < 0 or                   # Above screen (player bullets)
    y - height / 2 > game_height            # Below screen (enemy bullets)
  end

  @doc """
  Checks if bullet has expired based on lifetime.
  """
  @spec expired?(t()) :: boolean()
  def expired?(%__MODULE__{spawn_time: spawn_time, lifetime: lifetime}) do
    current_time = :erlang.monotonic_time(:millisecond)
    current_time - spawn_time > lifetime
  end

  @doc """
  Gets the bullet's bounding box for collision detection.
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
  Checks if this bullet can hit the specified target type.
  Player bullets can hit enemies, enemy bullets can hit players.
  """
  @spec can_hit?(t(), owner_type()) :: boolean()
  def can_hit?(%__MODULE__{owner_type: :player}, :enemy), do: true
  def can_hit?(%__MODULE__{owner_type: :enemy}, :player), do: true
  def can_hit?(%__MODULE__{}, _), do: false

  @doc """
  Checks if this bullet was fired by the specified entity.
  """
  @spec fired_by?(t(), owner_type(), String.t() | nil) :: boolean()
  def fired_by?(%__MODULE__{owner_type: type, owner_id: id}, owner_type, owner_id) do
    type == owner_type and id == owner_id
  end

  @doc """
  Creates a homing bullet that adjusts its direction toward a target.
  """
  @spec create_homing_bullet(number(), number(), number(), number(), String.t(), keyword()) :: t()
  def create_homing_bullet(x, y, target_x, target_y, enemy_id, opts \\ []) do
    # Calculate direction to target
    dx = target_x - x
    dy = target_y - y
    distance = :math.sqrt(dx * dx + dy * dy)
    
    speed = Keyword.get(opts, :speed, 6.0)
    
    velocity_x = if distance > 0, do: (dx / distance) * speed, else: 0.0
    velocity_y = if distance > 0, do: (dy / distance) * speed, else: speed
    
    new_enemy_bullet(x, y, velocity_x, velocity_y, enemy_id)
    |> Map.put(:color, Keyword.get(opts, :color, :orange))
    |> Map.put(:trail_length, Keyword.get(opts, :trail_length, 3))
  end

  @doc """
  Creates a spread pattern of bullets (shotgun effect).
  """
  @spec create_spread_bullets(number(), number(), number(), number(), String.t(), pos_integer(), float()) :: [t()]
  def create_spread_bullets(x, y, base_velocity_x, base_velocity_y, enemy_id, count, spread_angle) do
    if count <= 1 do
      [new_enemy_bullet(x, y, base_velocity_x, base_velocity_y, enemy_id)]
    else
      angle_step = spread_angle / (count - 1)
      start_angle = -spread_angle / 2
      
      for i <- 0..(count - 1) do
        angle = start_angle + i * angle_step
        cos_a = :math.cos(angle)
        sin_a = :math.sin(angle)
        
        # Rotate the velocity vector
        rotated_vx = base_velocity_x * cos_a - base_velocity_y * sin_a
        rotated_vy = base_velocity_x * sin_a + base_velocity_y * cos_a
        
        new_enemy_bullet(x, y, rotated_vx, rotated_vy, enemy_id)
      end
    end
  end

  @doc """
  Gets bullet age in milliseconds since spawn.
  """
  @spec age(t()) :: integer()
  def age(%__MODULE__{spawn_time: spawn_time}) do
    :erlang.monotonic_time(:millisecond) - spawn_time
  end

  @doc """
  Checks if bullet should show trail effect.
  """
  @spec has_trail?(t()) :: boolean()
  def has_trail?(%__MODULE__{trail_length: trail_length}), do: trail_length > 0

  # Private helper functions

  defp generate_id do
    # Generate a unique ID using timestamp and random number
    timestamp = :erlang.monotonic_time(:millisecond)
    random = :rand.uniform(9999)
    "bullet_#{timestamp}_#{random}"
  end

  defp get_default_color(:player), do: :yellow
  defp get_default_color(:enemy), do: :red

  defp calculate_speed(velocity_x, velocity_y) do
    :math.sqrt(velocity_x * velocity_x + velocity_y * velocity_y)
  end
end