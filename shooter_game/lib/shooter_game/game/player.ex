defmodule ShooterGame.Game.Player do
  @moduledoc """
  Player represents the player's ship in the shooter game.
  The player is controlled by mouse movements and can fire bullets.
  """

  @derive Jason.Encoder
  @enforce_keys [:x, :y]
  defstruct [
    # Position
    :x, :y,                     # float coordinates (center of player)
    
    # Physical properties
    health: 3,                  # integer (starting health)
    max_health: 3,              # integer (maximum health)
    width: 40,                  # integer (pixels)
    height: 40,                 # integer (pixels)
    
    # Combat state
    firing: false,              # boolean - currently firing
    last_shot_time: 0,          # monotonic time of last shot
    shot_cooldown: 100,         # milliseconds between shots
    
    # Damage & Invincibility
    last_damage_time: 0,        # monotonic time of last damage taken
    invincibility_duration: 1500, # milliseconds of invincibility after damage
    is_invincible: false,       # current invincibility state
    blink_state: false,         # for visual blinking effect
    last_blink_time: 0,         # time tracking for blink effect
    blink_interval: 100,        # milliseconds between blinks
    
    # Movement
    velocity_x: 0.0,            # float (pixels per frame) - for smooth movement
    velocity_y: 0.0,            # float (pixels per frame)
    max_speed: 8.0,             # maximum movement speed
    
    # Visual properties
    color: :blue,               # :blue | :red | :green (for different player types)
    angle: 0.0                  # rotation angle in radians
  ]

  @type color :: :blue | :red | :green
  
  @type t :: %__MODULE__{
    x: float(),
    y: float(),
    health: non_neg_integer(),
    max_health: pos_integer(),
    width: pos_integer(),
    height: pos_integer(),
    firing: boolean(),
    last_shot_time: integer(),
    shot_cooldown: pos_integer(),
    last_damage_time: integer(),
    invincibility_duration: pos_integer(),
    is_invincible: boolean(),
    blink_state: boolean(),
    last_blink_time: integer(),
    blink_interval: pos_integer(),
    velocity_x: float(),
    velocity_y: float(),
    max_speed: float(),
    color: color(),
    angle: float()
  }

  @doc """
  Creates a new player at the specified position.
  """
  @spec new(number(), number()) :: t()
  def new(x, y) do
    %__MODULE__{
      x: x,
      y: y,
      last_shot_time: :erlang.monotonic_time(:millisecond)
    }
  end

  @doc """
  Creates a new player with custom properties.
  """
  @spec new(number(), number(), keyword()) :: t()
  def new(x, y, opts \\ []) do
    current_time = :erlang.monotonic_time(:millisecond)
    max_health = Keyword.get(opts, :max_health, 3)
    
    %__MODULE__{
      x: x,
      y: y,
      health: Keyword.get(opts, :health, max_health),
      max_health: max_health,
      width: Keyword.get(opts, :width, 40),
      height: Keyword.get(opts, :height, 40),
      shot_cooldown: Keyword.get(opts, :shot_cooldown, 100),
      max_speed: Keyword.get(opts, :max_speed, 8.0),
      color: Keyword.get(opts, :color, :blue),
      last_shot_time: current_time,
      last_damage_time: 0,
      last_blink_time: current_time
    }
  end

  @doc """
  Updates player position based on mouse coordinates.
  Validates that the position is within game boundaries.
  """
  @spec move_to(t(), number(), number(), pos_integer(), pos_integer()) :: t()
  def move_to(%__MODULE__{} = player, target_x, target_y, game_width, game_height) do
    # Clamp position to game boundaries
    half_width = player.width / 2
    half_height = player.height / 2
    
    clamped_x = clamp(target_x, half_width, game_width - half_width)
    clamped_y = clamp(target_y, half_height, game_height - half_height)
    
    # Calculate velocity for smooth movement (optional for visual effects)
    velocity_x = clamped_x - player.x
    velocity_y = clamped_y - player.y
    
    %{player | 
      x: clamped_x, 
      y: clamped_y,
      velocity_x: velocity_x,
      velocity_y: velocity_y
    }
  end

  @doc """
  Sets the player's firing state.
  """
  @spec set_firing(t(), boolean()) :: t()
  def set_firing(%__MODULE__{} = player, firing) do
    %{player | firing: firing}
  end

  @doc """
  Checks if the player can fire (cooldown has elapsed).
  """
  @spec can_fire?(t()) :: boolean()
  def can_fire?(%__MODULE__{last_shot_time: last_shot, shot_cooldown: cooldown}) do
    current_time = :erlang.monotonic_time(:millisecond)
    current_time - last_shot >= cooldown
  end

  @doc """
  Updates the last shot time to current time.
  """
  @spec record_shot(t()) :: t()
  def record_shot(%__MODULE__{} = player) do
    %{player | last_shot_time: :erlang.monotonic_time(:millisecond)}
  end

  @doc """
  Damages the player (reduces health) if not invincible.
  Activates invincibility period and visual effects.
  """
  @spec take_damage(t(), pos_integer()) :: t()
  def take_damage(%__MODULE__{is_invincible: true} = player, _damage) do
    # Cannot take damage while invincible
    player
  end

  def take_damage(%__MODULE__{health: health} = player, damage) do
    new_health = max(0, health - damage)
    current_time = :erlang.monotonic_time(:millisecond)
    
    %{player | 
      health: new_health,
      last_damage_time: current_time,
      is_invincible: true,
      blink_state: true,
      last_blink_time: current_time
    }
  end

  @doc """
  Updates player state including invincibility and blink effects.
  Should be called every frame.
  """
  @spec update_state(t()) :: t()
  def update_state(%__MODULE__{} = player) do
    current_time = :erlang.monotonic_time(:millisecond)
    
    player
    |> update_invincibility(current_time)
    |> update_blink_effect(current_time)
  end

  # Updates invincibility state based on time elapsed
  defp update_invincibility(player, current_time) do
    if player.is_invincible do
      time_since_damage = current_time - player.last_damage_time
      
      if time_since_damage >= player.invincibility_duration do
        %{player | is_invincible: false, blink_state: false}
      else
        player
      end
    else
      player
    end
  end

  # Updates blinking visual effect during invincibility
  defp update_blink_effect(%{is_invincible: false} = player, _current_time) do
    %{player | blink_state: false}
  end

  defp update_blink_effect(%{is_invincible: true} = player, current_time) do
    time_since_blink = current_time - player.last_blink_time
    
    if time_since_blink >= player.blink_interval do
      %{player | 
        blink_state: !player.blink_state,
        last_blink_time: current_time
      }
    else
      player
    end
  end

  @doc """
  Checks if player can take damage (not invincible).
  """
  @spec can_take_damage?(t()) :: boolean()
  def can_take_damage?(%__MODULE__{is_invincible: invincible}), do: !invincible

  @doc """
  Heals the player (increases health up to maximum).
  """
  @spec heal(t(), pos_integer()) :: t()
  def heal(%__MODULE__{health: health, max_health: max_health} = player, heal_amount) do
    new_health = min(max_health, health + heal_amount)
    %{player | health: new_health}
  end

  @doc """
  Checks if the player is alive.
  """
  @spec alive?(t()) :: boolean()
  def alive?(%__MODULE__{health: health}), do: health > 0

  @doc """
  Gets the player's bounding box for collision detection.
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
  Gets the bullet spawn position (front of the player ship).
  """
  @spec bullet_spawn_position(t()) :: {float(), float()}
  def bullet_spawn_position(%__MODULE__{x: x, y: y, height: height}) do
    # Bullets spawn from the front (top) of the player ship
    {x, y - height / 2}
  end

  # Private helper functions

  defp clamp(value, min_val, max_val) do
    value
    |> max(min_val)
    |> min(max_val)
  end
end