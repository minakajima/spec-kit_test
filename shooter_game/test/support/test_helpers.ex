defmodule ShooterGame.Game.TestHelpers do
  @moduledoc """
  Test helper functions for the shooter game.
  Provides utilities for creating test data and assertions.
  """

  alias ShooterGame.Game.{GameState, Player, Enemy, Bullet, Collision}

  @doc """
  Creates a basic game state for testing.
  """
  @spec create_test_game_state(keyword()) :: GameState.t()
  def create_test_game_state(opts \\ []) do
    player = create_test_player(Keyword.get(opts, :player_opts, []))
    width = Keyword.get(opts, :width, 800)
    height = Keyword.get(opts, :height, 600)
    
    GameState.new(player, width, height)
    |> maybe_add_enemies(Keyword.get(opts, :enemies, []))
    |> maybe_add_bullets(Keyword.get(opts, :bullets, []))
    |> maybe_set_score(Keyword.get(opts, :score))
    |> maybe_set_status(Keyword.get(opts, :status))
  end

  @doc """
  Creates a test player with default or custom properties.
  """
  @spec create_test_player(keyword()) :: Player.t()
  def create_test_player(opts \\ []) do
    x = Keyword.get(opts, :x, 400.0)
    y = Keyword.get(opts, :y, 500.0)
    
    Player.new(x, y, opts)
  end

  @doc """
  Creates a test enemy with default or custom properties.
  """
  @spec create_test_enemy(keyword()) :: Enemy.t()
  def create_test_enemy(opts \\ []) do
    x = Keyword.get(opts, :x, 400.0)
    y = Keyword.get(opts, :y, 100.0)
    
    Enemy.new(x, y, opts)
  end

  @doc """
  Creates a test bullet with default or custom properties.
  """
  @spec create_test_bullet(keyword()) :: Bullet.t()
  def create_test_bullet(opts \\ []) do
    x = Keyword.get(opts, :x, 400.0)
    y = Keyword.get(opts, :y, 300.0)
    velocity_x = Keyword.get(opts, :velocity_x, 0.0)
    velocity_y = Keyword.get(opts, :velocity_y, -8.0)
    owner_type = Keyword.get(opts, :owner_type, :player)
    
    Bullet.new(x, y, velocity_x, velocity_y, owner_type, opts)
  end

  @doc """
  Creates multiple test enemies in a formation.
  """
  @spec create_enemy_formation(pos_integer(), keyword()) :: [Enemy.t()]
  def create_enemy_formation(count, opts \\ []) do
    start_x = Keyword.get(opts, :start_x, 100.0)
    start_y = Keyword.get(opts, :start_y, 100.0)
    spacing = Keyword.get(opts, :spacing, 60.0)
    
    for i <- 0..(count - 1) do
      x = start_x + i * spacing
      create_test_enemy([x: x, y: start_y] ++ opts)
    end
  end

  @doc """
  Creates a bullet barrage (multiple bullets).
  """
  @spec create_bullet_barrage(pos_integer(), keyword()) :: [Bullet.t()]
  def create_bullet_barrage(count, opts \\ []) do
    start_x = Keyword.get(opts, :start_x, 400.0)
    start_y = Keyword.get(opts, :start_y, 200.0)
    spread = Keyword.get(opts, :spread, 50.0)
    
    for i <- 0..(count - 1) do
      offset = (i - count / 2) * spread / count
      x = start_x + offset
      create_test_bullet([x: x, y: start_y] ++ opts)
    end
  end

  @doc """
  Advances game time by specified milliseconds.
  Updates all time-sensitive properties.
  """
  @spec advance_time(GameState.t(), pos_integer()) :: GameState.t()
  def advance_time(game_state, milliseconds) do
    delta_time = milliseconds / 1000.0
    
    # Update enemy positions
    updated_enemies = Enum.map(game_state.enemies, &Enemy.update_position(&1, delta_time))
    
    # Update bullet positions
    updated_bullets = Enum.map(game_state.bullets, &Bullet.update_position(&1, delta_time))
    
    %{game_state | enemies: updated_enemies, bullets: updated_bullets}
  end

  @doc """
  Simulates player firing continuously for specified duration.
  """
  @spec simulate_firing(GameState.t(), pos_integer()) :: GameState.t()
  def simulate_firing(game_state, duration_ms) do
    shots = trunc(duration_ms / game_state.player.shot_cooldown)
    
    Enum.reduce(1..shots, game_state, fn _, acc_state ->
      if Player.can_fire?(acc_state.player) do
        {bullet_x, bullet_y} = Player.bullet_spawn_position(acc_state.player)
        bullet = Bullet.new_player_bullet(bullet_x, bullet_y)
        updated_player = Player.record_shot(acc_state.player)
        
        acc_state
        |> Map.put(:player, updated_player)
        |> GameState.add_bullet(bullet)
      else
        acc_state
      end
    end)
  end

  @doc """
  Asserts that two positions are approximately equal (within tolerance).
  """
  @spec assert_positions_close({number(), number()}, {number(), number()}, number()) :: boolean()
  def assert_positions_close({x1, y1}, {x2, y2}, tolerance \\ 0.1) do
    dx = abs(x1 - x2)
    dy = abs(y1 - y2)
    
    dx <= tolerance and dy <= tolerance
  end

  @doc """
  Asserts that entities are colliding.
  """
  @spec assert_collision(any(), any()) :: boolean()
  def assert_collision(entity1, entity2) do
    box1 = get_bounding_box(entity1)
    box2 = get_bounding_box(entity2)
    
    Collision.boxes_collide?(box1, box2)
  end

  @doc """
  Asserts that entities are not colliding.
  """
  @spec assert_no_collision(any(), any()) :: boolean()
  def assert_no_collision(entity1, entity2) do
    not assert_collision(entity1, entity2)
  end

  @doc """
  Creates a collision scenario for testing.
  """
  @spec create_collision_scenario(atom()) :: {any(), any()}
  def create_collision_scenario(:player_enemy) do
    player = create_test_player(x: 400, y: 300)
    enemy = create_test_enemy(x: 400, y: 300)  # Same position = collision
    {player, enemy}
  end

  def create_collision_scenario(:bullet_enemy) do
    bullet = create_test_bullet(x: 400, y: 200, owner_type: :player)
    enemy = create_test_enemy(x: 400, y: 200)  # Same position = collision
    {bullet, enemy}
  end

  def create_collision_scenario(:bullet_player) do
    bullet = create_test_bullet(x: 400, y: 300, owner_type: :enemy)
    player = create_test_player(x: 400, y: 300)  # Same position = collision
    {bullet, player}
  end

  def create_collision_scenario(:no_collision) do
    player = create_test_player(x: 100, y: 100)
    enemy = create_test_enemy(x: 700, y: 500)  # Far apart = no collision
    {player, enemy}
  end

  @doc """
  Verifies game state consistency.
  """
  @spec verify_game_state(GameState.t()) :: boolean()
  def verify_game_state(game_state) do
    # Check that all entities have valid positions
    valid_player = valid_position?(game_state.player)
    valid_enemies = Enum.all?(game_state.enemies, &valid_position?/1)
    valid_bullets = Enum.all?(game_state.bullets, &valid_position?/1)
    
    # Check that status is valid
    valid_status = game_state.status in [:waiting, :playing, :paused, :game_over]
    
    # Check score is non-negative
    valid_score = game_state.score >= 0
    
    valid_player and valid_enemies and valid_bullets and valid_status and valid_score
  end

  @doc """
  Creates test data for performance benchmarks.
  """
  @spec create_benchmark_data(keyword()) :: GameState.t()
  def create_benchmark_data(opts \\ []) do
    enemy_count = Keyword.get(opts, :enemy_count, 50)
    bullet_count = Keyword.get(opts, :bullet_count, 100)
    
    enemies = create_enemy_formation(enemy_count, spacing: 40)
    bullets = create_bullet_barrage(bullet_count, spread: 200)
    
    create_test_game_state(
      enemies: enemies,
      bullets: bullets,
      score: 1000
    )
  end

  # Private helper functions

  defp maybe_add_enemies(game_state, []), do: game_state
  defp maybe_add_enemies(game_state, enemies) do
    Enum.reduce(enemies, game_state, &GameState.add_enemy(&2, &1))
  end

  defp maybe_add_bullets(game_state, []), do: game_state
  defp maybe_add_bullets(game_state, bullets) do
    Enum.reduce(bullets, game_state, &GameState.add_bullet(&2, &1))
  end

  defp maybe_set_score(game_state, nil), do: game_state
  defp maybe_set_score(game_state, score), do: %{game_state | score: score}

  defp maybe_set_status(game_state, nil), do: game_state
  defp maybe_set_status(game_state, status), do: %{game_state | status: status}

  defp get_bounding_box(%Player{} = player), do: Player.bounding_box(player)
  defp get_bounding_box(%Enemy{} = enemy), do: Enemy.bounding_box(enemy)
  defp get_bounding_box(%Bullet{} = bullet), do: Bullet.bounding_box(bullet)

  defp valid_position?(%{x: x, y: y}) when is_number(x) and is_number(y), do: true
  defp valid_position?(_), do: false
end