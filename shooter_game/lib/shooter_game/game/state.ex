defmodule ShooterGame.Game.State do
  @moduledoc """
  GameState represents the complete state of the shooter game at any point in time.
  All game state transitions are performed through pure functions that take this state
  and return a new state, following the functional programming principles.
  """

  alias ShooterGame.Game.{Player, Enemy, Bullet}

  @derive Jason.Encoder
  @enforce_keys [:player, :status]
  defstruct [
    # Core entities
    :player,                    # %Player{} - The player entity
    enemies: [],                # [%Enemy{}] - List of all active enemies
    player_bullets: [],         # [%Bullet{}] - List of player-fired bullets
    enemy_bullets: [],          # [%Bullet{}] - List of enemy-fired bullets
    
    # Game state
    score: 0,                   # Current score
    high_score: 0,              # Highest score achieved (loaded from LocalStorage)
    status: :start,             # :start | :playing | :game_over | :paused
    final_score: 0,             # Final calculated score with bonuses
    
    # Game dimensions and timing
    game_width: 800,            # Game area width in pixels
    game_height: 600,           # Game area height in pixels
    last_spawn_time: 0,         # Last enemy spawn time (monotonic time)
    start_time: 0,              # Game start time (monotonic time)
    elapsed_time: 0,            # Time since game started (milliseconds)
    time_limit: 180_000,        # Game time limit (3 minutes)
    
    # Game statistics
    shots_fired: 0,             # Total shots fired by player
    shots_hit: 0,               # Shots that hit enemies
    enemies_defeated: 0,        # Enemies destroyed
    damage_taken: 0,            # Total damage received by player
    
    # Game over statistics
    game_over_stats: nil,       # Map with final statistics
    
    # Performance tracking
    frame_count: 0,             # Total frames processed
    last_frame_time: 0          # Last frame processing time
  ]

  @type status :: :start | :playing | :game_over | :paused
  
  @type t :: %__MODULE__{
    player: Player.t(),
    enemies: [Enemy.t()],
    player_bullets: [Bullet.t()],
    enemy_bullets: [Bullet.t()],
    score: non_neg_integer(),
    high_score: non_neg_integer(),
    status: status(),
    final_score: non_neg_integer(),
    game_width: pos_integer(),
    game_height: pos_integer(),
    last_spawn_time: integer(),
    start_time: integer(),
    elapsed_time: non_neg_integer(),
    time_limit: pos_integer(),
    shots_fired: non_neg_integer(),
    shots_hit: non_neg_integer(),
    enemies_defeated: non_neg_integer(),
    damage_taken: non_neg_integer(),
    game_over_stats: map() | nil,
    frame_count: non_neg_integer(),
    last_frame_time: integer()
  }

  @doc """
  Creates a new initial game state with default values.
  Player is positioned at the bottom center of the screen.
  """
  @spec new() :: t()
  def new do
    current_time = :erlang.monotonic_time(:millisecond)
    
    %__MODULE__{
      player: Player.new(400, 550),  # Center bottom position
      status: :start,
      game_width: 800,
      game_height: 600,
      start_time: current_time,
      last_spawn_time: current_time,
      last_frame_time: current_time
    }
  end

  @doc """
  Creates a new game state with custom dimensions.
  """
  @spec new(pos_integer(), pos_integer()) :: t()
  def new(width, height) do
    current_time = :erlang.monotonic_time(:millisecond)
    
    %__MODULE__{
      player: Player.new(width / 2, height - 50),  # Center bottom position
      status: :start,
      game_width: width,
      game_height: height,
      start_time: current_time,
      last_spawn_time: current_time,
      last_frame_time: current_time
    }
  end

  @doc """
  Resets the game state for a new game, preserving high score.
  """
  @spec reset(t()) :: t()
  def reset(%__MODULE__{high_score: high_score, game_width: width, game_height: height}) do
    current_time = :erlang.monotonic_time(:millisecond)
    
    %__MODULE__{
      player: Player.new(width / 2, height - 50),
      enemies: [],
      player_bullets: [],
      enemy_bullets: [],
      score: 0,
      high_score: high_score,
      status: :playing,
      final_score: 0,
      game_width: width,
      game_height: height,
      start_time: current_time,
      elapsed_time: 0,
      shots_fired: 0,
      shots_hit: 0,
      enemies_defeated: 0,
      damage_taken: 0,
      game_over_stats: nil,
      last_spawn_time: current_time,
      last_frame_time: current_time,
      frame_count: 0
    }
  end

  @doc """
  Updates the high score if the current score is higher.
  """
  @spec update_high_score(t()) :: t()
  def update_high_score(%__MODULE__{score: score, high_score: high_score} = state) when score > high_score do
    %{state | high_score: score}
  end
  def update_high_score(state), do: state

  @doc """
  Checks if the game is over due to time limit.
  """
  @spec time_expired?(t()) :: boolean()
  def time_expired?(%__MODULE__{elapsed_time: elapsed, time_limit: limit}) do
    elapsed >= limit
  end

  @doc """
  Checks if the player is alive.
  """
  @spec player_alive?(t()) :: boolean()
  def player_alive?(%__MODULE__{player: %Player{health: health}}) do
    health > 0
  end

  @doc """
  Sets game status to game over.
  """
  @spec set_game_over(t()) :: t()
  def set_game_over(%__MODULE__{} = state) do
    %{state | status: :game_over}
  end

  @doc """
  Checks if the game is currently playing.
  """
  @spec playing?(t()) :: boolean()
  def playing?(%__MODULE__{status: :playing}), do: true
  def playing?(_), do: false

  @doc """
  Increments the shots fired counter.
  """
  @spec increment_shots_fired(t()) :: t()
  def increment_shots_fired(%__MODULE__{} = state) do
    %{state | shots_fired: state.shots_fired + 1}
  end

  @doc """
  Increments the shots hit counter (when bullet hits enemy).
  """
  @spec increment_shots_hit(t()) :: t()
  def increment_shots_hit(%__MODULE__{} = state) do
    %{state | shots_hit: state.shots_hit + 1}
  end

  @doc """
  Increments the enemies defeated counter.
  """
  @spec increment_enemies_defeated(t()) :: t()
  def increment_enemies_defeated(%__MODULE__{} = state) do
    %{state | enemies_defeated: state.enemies_defeated + 1}
  end

  @doc """
  Increments the damage taken counter.
  """
  @spec increment_damage_taken(t(), pos_integer()) :: t()
  def increment_damage_taken(%__MODULE__{} = state, damage) do
    %{state | damage_taken: state.damage_taken + damage}
  end

  @doc """
  Gets the current frame rate (approximate).
  """
  @spec current_fps(t()) :: float()
  def current_fps(%__MODULE__{frame_count: count, elapsed_time: elapsed}) when elapsed > 0 do
    count / (elapsed / 1000.0)
  end
  def current_fps(_), do: 0.0
  @doc """
  Adds a bullet to the game state.
  """
  @spec add_bullet(t(), Bullet.t()) :: t()
  def add_bullet(%__MODULE__{} = state, %Bullet{owner_type: :player} = bullet) do
    %{state | player_bullets: [bullet | state.player_bullets]}
  end
  
  def add_bullet(%__MODULE__{} = state, %Bullet{owner_type: :enemy} = bullet) do
    %{state | enemy_bullets: [bullet | state.enemy_bullets]}
  end

  @doc """
  Removes a bullet from the game state by ID.
  """
  @spec remove_bullet(t(), String.t()) :: t()
  def remove_bullet(%__MODULE__{} = state, bullet_id) do
    %{state | 
      player_bullets: Enum.reject(state.player_bullets, fn b -> b.id == bullet_id end),
      enemy_bullets: Enum.reject(state.enemy_bullets, fn b -> b.id == bullet_id end)
    }
  end

  @doc """
  Adds an enemy to the game state.
  """
  @spec add_enemy(t(), Enemy.t()) :: t()
  def add_enemy(%__MODULE__{} = state, %Enemy{} = enemy) do
    %{state | enemies: [enemy | state.enemies]}
  end

  @doc """
  Updates an enemy in the game state.
  """
  @spec update_enemy(t(), Enemy.t()) :: t()
  def update_enemy(%__MODULE__{} = state, %Enemy{} = updated_enemy) do
    enemies = Enum.map(state.enemies, fn enemy ->
      if enemy.id == updated_enemy.id, do: updated_enemy, else: enemy
    end)
    %{state | enemies: enemies}

end
end
