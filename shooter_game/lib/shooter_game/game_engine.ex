defmodule ShooterGame.GameEngine do
  @moduledoc """
  Central game engine that manages game state, entities, and game loop.
  Handles spawning, updates, collisions, and game logic orchestration.
  """

  use GenServer

  alias ShooterGame.Game.{State, Player, Enemy, Bullet, Collision}
  
  # For backward compatibility
  alias ShooterGame.Game.State, as: GameState

  # Game configuration
  @game_width 800
  @game_height 600
  @enemy_spawn_interval 2000  # milliseconds
  @game_tick_rate 30          # Hz (server-side updates)
  @max_enemies 10
  @max_bullets 50

  defstruct [
    game_state: nil,
    last_update: 0,
    last_enemy_spawn: 0,
    game_width: @game_width,
    game_height: @game_height,
    paused: false,
    subscribers: []  # List of PIDs to notify of game state changes
  ]

  @type t :: %__MODULE__{
    game_state: GameState.t() | nil,
    last_update: integer(),
    last_enemy_spawn: integer(),
    game_width: pos_integer(),
    game_height: pos_integer(),
    paused: boolean(),
    subscribers: [pid()]
  }

  ## Public API

  @doc """
  Starts the game engine GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Starts a new game.
  """
  @spec start_game() :: :ok
  def start_game do
    GenServer.call(__MODULE__, :start_game)
  end

  @doc """
  Resets the current game to initial state.
  """
  @spec reset_game() :: :ok  
  def reset_game do
    GenServer.call(__MODULE__, :reset_game)
  end

  @doc """
  Pauses or unpauses the game.
  """
  @spec set_paused(boolean()) :: :ok
  def set_paused(paused) do
    GenServer.call(__MODULE__, {:set_paused, paused})
  end

  @doc """
  Updates player position based on mouse coordinates.
  """
  @spec update_player_position(number(), number()) :: :ok
  def update_player_position(x, y) do
    GenServer.cast(__MODULE__, {:update_player_position, x, y})
  end

  @doc """
  Sets player firing state.
  """
  @spec set_player_firing(boolean()) :: :ok
  def set_player_firing(firing) do
    GenServer.cast(__MODULE__, {:set_player_firing, firing})
  end

  @doc """
  Gets current game state.
  """
  @spec get_game_state() :: GameState.t() | nil
  def get_game_state do
    GenServer.call(__MODULE__, :get_game_state)
  end

  @doc """
  Subscribes to game state updates.
  """
  @spec subscribe() :: :ok
  def subscribe do
    GenServer.cast(__MODULE__, {:subscribe, self()})
  end

  @doc """
  Unsubscribes from game state updates.
  """
  @spec unsubscribe() :: :ok
  def unsubscribe do
    GenServer.cast(__MODULE__, {:unsubscribe, self()})
  end

  @doc """
  Forces an immediate game update (for testing).
  """
  @spec force_update() :: :ok
  def force_update do
    GenServer.cast(__MODULE__, :force_update)
  end

  ## GenServer Callbacks

  @impl GenServer
  def init(opts) do
    # Schedule periodic game updates
    :timer.send_interval(trunc(1000 / @game_tick_rate), :game_tick)
    
    state = %__MODULE__{
      game_width: Keyword.get(opts, :width, @game_width),
      game_height: Keyword.get(opts, :height, @game_height),
      last_update: :erlang.monotonic_time(:millisecond),
      last_enemy_spawn: :erlang.monotonic_time(:millisecond)
    }
    
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:start_game, _from, state) do
    # Create a new game state with the specified dimensions
    game_state = 
      GameState.new(state.game_width, state.game_height)
      |> Map.put(:status, :playing)
    
    new_state = %{state | 
      game_state: game_state,
      paused: false,
      last_update: :erlang.monotonic_time(:millisecond),
      last_enemy_spawn: :erlang.monotonic_time(:millisecond)
    }
    
    broadcast_state_update(new_state)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:reset_game, _from, state) do
    if state.game_state do
      reset_game_state = GameState.reset(state.game_state)
      new_state = %{state | 
        game_state: reset_game_state,
        last_update: :erlang.monotonic_time(:millisecond),
        last_enemy_spawn: :erlang.monotonic_time(:millisecond)
      }
      broadcast_state_update(new_state)
      {:reply, :ok, new_state}
    else
      {:reply, :ok, state}
    end
  end

  @impl GenServer
  def handle_call({:set_paused, paused}, _from, state) do
    new_state = %{state | paused: paused}
    broadcast_state_update(new_state)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_game_state, _from, state) do
    {:reply, state.game_state, state}
  end

  @impl GenServer
  def handle_cast({:update_player_position, x, y}, state) do
        if state.game_state && GameState.playing?(state.game_state) do
      bullet = Bullet.new(state.game_state.player.x, state.game_state.player.y - 20, 0, -10, :player)
      updated_game_state = state.game_state
      |> GameState.add_bullet(bullet)
      |> GameState.increment_shots_fired()
      new_state = %{state | game_state: updated_game_state}
      broadcast_state_update(new_state)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_cast({:set_player_firing, firing}, state) do
    if state.game_state && GameState.playing?(state.game_state) do
      updated_player = Player.set_firing(state.game_state.player, firing)
      updated_game_state = %{state.game_state | player: updated_player}
      new_state = %{state | game_state: updated_game_state}
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_cast({:subscribe, pid}, state) do
    # Monitor subscriber so we can clean up if they crash
    Process.monitor(pid)
    new_subscribers = [pid | state.subscribers]
    {:noreply, %{state | subscribers: new_subscribers}}
  end

  @impl GenServer
  def handle_cast({:unsubscribe, pid}, state) do
    new_subscribers = List.delete(state.subscribers, pid)
    {:noreply, %{state | subscribers: new_subscribers}}
  end

  @impl GenServer
  def handle_cast(:force_update, state) do
    new_state = update_game_state(state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(:game_tick, %{paused: true} = state) do
    # Skip updates when paused
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:game_tick, %{game_state: nil} = state) do
    # Skip updates when game hasn't started
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:game_tick, %{game_state: %{status: status}} = state) when status != :playing do
    # Skip updates when game is not in playing state
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:game_tick, state) do
    new_state = update_game_state(state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Remove crashed subscriber
    new_subscribers = List.delete(state.subscribers, pid)
    {:noreply, %{state | subscribers: new_subscribers}}
  end

  ## Private Functions

  defp update_game_state(%{game_state: nil} = state), do: state

  defp update_game_state(state) do
    current_time = :erlang.monotonic_time(:millisecond)
    delta_time = current_time - state.last_update
    
    updated_game_state = 
      state.game_state
      |> spawn_enemies_if_needed(current_time, state.last_enemy_spawn, state.game_width)
      |> spawn_player_bullets_if_needed()
      |> spawn_enemy_bullets_if_needed()
      |> update_entities_positions(delta_time / 1000.0)
      |> handle_collisions()
      |> remove_dead_entities()
      |> check_game_over()
    
    new_last_enemy_spawn = 
      if should_spawn_enemy?(current_time, state.last_enemy_spawn) do
        current_time
      else
        state.last_enemy_spawn
      end

    new_state = %{state |
      game_state: updated_game_state,
      last_update: current_time,
      last_enemy_spawn: new_last_enemy_spawn
    }

    broadcast_state_update(new_state)
    new_state
  end

  defp spawn_enemies_if_needed(game_state, current_time, last_spawn_time, game_width) do
    if should_spawn_enemy?(current_time, last_spawn_time) and 
       length(game_state.enemies) < @max_enemies and
       GameState.playing?(game_state) do
      
      # Spawn enemy at random X position at top of screen
      x = :rand.uniform() * (game_width - 60) + 30  # 30px margin from edges
      y = -30  # Start above screen
      
      enemy = Enemy.new(x, y, 
        behavior: :curved_shooter,
        shot_interval: 1500,
        shot_accuracy: 0.8,
        points: 10
      )
      
      GameState.add_enemy(game_state, enemy)
    else
      game_state
    end
  end

  defp should_spawn_enemy?(current_time, last_spawn_time) do
    current_time - last_spawn_time >= @enemy_spawn_interval
  end

  defp spawn_player_bullets_if_needed(game_state) do
    if game_state.player.firing and 
       Player.can_fire?(game_state.player) and
       length(game_state.player_bullets) < @max_bullets and
       Player.alive?(game_state.player) do
      
      {bullet_x, bullet_y} = Player.bullet_spawn_position(game_state.player)
      bullet = Bullet.new_player_bullet(bullet_x, bullet_y)
      
      updated_player = Player.record_shot(game_state.player)
      
      game_state
      |> Map.put(:player, updated_player)
      |> GameState.add_bullet(bullet)
    else
      game_state
    end
  end

  defp spawn_enemy_bullets_if_needed(game_state) do
    Enum.reduce(game_state.enemies, game_state, fn enemy, acc_state ->
      if Enemy.can_shoot?(enemy) and 
         length(acc_state.enemy_bullets) < @max_bullets and
         Player.alive?(acc_state.player) do
        
        {bullet_x, bullet_y} = Enemy.bullet_spawn_position(enemy)
        player_x = acc_state.player.x
        player_y = acc_state.player.y
        
        {velocity_x, velocity_y} = Enemy.calculate_shot_direction(enemy, player_x, player_y, 6.0)
        
        # Choose bullet type based on enemy behavior
        bullet_opts = case enemy.behavior do
          :curved_shooter -> 
            [curve_type: :sine, curve_amplitude: 30.0, curve_frequency: 0.15]
          _ -> 
            [curve_type: :straight]
        end
        
        bullet = Bullet.new_enemy_bullet(bullet_x, bullet_y, velocity_x, velocity_y, enemy.id, bullet_opts)
        updated_enemy = Enemy.record_shot(enemy)
        
        acc_state
        |> GameState.update_enemy(updated_enemy)
        |> GameState.add_bullet(bullet)
      else
        acc_state
      end
    end)
  end

  defp update_entities_positions(game_state, delta_time) do
    # Update player state (invincibility, blink effects)
    updated_player = Player.update_state(game_state.player)
    
    # Update enemy positions
    updated_enemies = Enum.map(game_state.enemies, &Enemy.update_position(&1, delta_time))
    
    # Update bullet positions
    updated_player_bullets = Enum.map(game_state.player_bullets, &Bullet.update_position(&1, delta_time))
    updated_enemy_bullets = Enum.map(game_state.enemy_bullets, &Bullet.update_position(&1, delta_time))
    
    %{game_state | 
      player: updated_player,
      enemies: updated_enemies, 
      player_bullets: updated_player_bullets,
      enemy_bullets: updated_enemy_bullets
    }
  end

  defp handle_collisions(game_state) do
    # Player bullet vs Enemy collisions
    bullet_enemy_collisions = Collision.find_bullet_enemy_collisions(game_state.player_bullets, game_state.enemies)
    
    # Enemy bullet vs Player collisions  
    bullet_player_collisions = Collision.find_bullet_player_collisions(game_state.enemy_bullets, game_state.player)
    
    # Enemy vs Player collisions
    enemy_player_collisions = Collision.find_player_enemy_collisions(game_state.enemies, game_state.player)
    
    game_state
    |> process_bullet_enemy_collisions(bullet_enemy_collisions)
    |> process_bullet_player_collisions(bullet_player_collisions)
    |> process_enemy_player_collisions(enemy_player_collisions)
  end

  defp process_bullet_enemy_collisions(game_state, collisions) do
    Enum.reduce(collisions, game_state, fn {bullet, enemy}, acc_state ->
      # Damage enemy
      damaged_enemy = Enemy.take_damage(enemy, bullet.damage)
      
      # Award points if enemy was destroyed
      new_score = if Enemy.alive?(damaged_enemy) do
        acc_state.score
      else
        acc_state.score + enemy.points
      end
      
      # Update statistics
      updated_state = GameState.increment_shots_hit(acc_state)
      updated_state = if !Enemy.alive?(damaged_enemy) do
        GameState.increment_enemies_defeated(updated_state)
      else
        updated_state
      end
      
      updated_state
      |> GameState.remove_bullet(bullet.id)
      |> GameState.update_enemy(damaged_enemy)
      |> Map.put(:score, new_score)
    end)
  end

  defp process_bullet_player_collisions(game_state, colliding_bullets) do
    Enum.reduce(colliding_bullets, game_state, fn bullet, acc_state ->
      if Player.can_take_damage?(acc_state.player) do
        damaged_player = Player.take_damage(acc_state.player, bullet.damage)
        
        acc_state
        |> GameState.remove_bullet(bullet.id)
        |> GameState.increment_damage_taken(bullet.damage)
        |> Map.put(:player, damaged_player)
      else
        # Player is invincible, still remove bullet but no damage
        GameState.remove_bullet(acc_state, bullet.id)
      end
    end)
  end

  defp process_enemy_player_collisions(game_state, colliding_enemies) do
    if length(colliding_enemies) > 0 and Player.can_take_damage?(game_state.player) do
      # Player takes damage from direct collision
      damaged_player = Player.take_damage(game_state.player, 1)
      
      game_state
      |> GameState.increment_damage_taken(1)
      |> Map.put(:player, damaged_player)
    else
      game_state
    end
  end

  defp remove_dead_entities(game_state) do
    # Remove dead enemies
    alive_enemies = Enum.filter(game_state.enemies, &Enemy.alive?/1)
    
    # Remove off-screen enemies
    on_screen_enemies = Enum.filter(alive_enemies, &(!Enemy.off_screen?(&1, game_state.game_width, game_state.game_height)))
    
    # Remove off-screen or expired bullets
    active_player_bullets = Enum.filter(game_state.player_bullets, fn bullet ->
      not Bullet.off_screen?(bullet, game_state.game_width, game_state.game_height) and
      not Bullet.expired?(bullet)
    end)
    
    active_enemy_bullets = Enum.filter(game_state.enemy_bullets, fn bullet ->
      not Bullet.off_screen?(bullet, game_state.game_width, game_state.game_height) and
      not Bullet.expired?(bullet)
    end)
    
    %{game_state | enemies: on_screen_enemies, player_bullets: active_player_bullets, enemy_bullets: active_enemy_bullets}
  end

  defp check_game_over(game_state) do
    if Player.alive?(game_state.player) do
      game_state
    else
      # Calculate final score with time bonus
      final_score = calculate_final_score(game_state)
      
      # Update game state for game over
      game_state
      |> GameState.set_game_over()
      |> Map.put(:score, final_score)
      |> Map.put(:final_score, final_score)
      |> add_game_over_stats()
    end
  end

  # Calculate final score including time survived bonus
  defp calculate_final_score(game_state) do
    base_score = game_state.score
    
    # Time bonus: 1 point per second survived
    current_time = :erlang.monotonic_time(:millisecond)
    start_time = game_state.start_time || current_time
    time_survived = max(0, (current_time - start_time) / 1000)
    time_bonus = trunc(time_survived)
    
    # Enemy defeat bonus
    enemies_defeated = calculate_enemies_defeated(game_state)
    defeat_bonus = enemies_defeated * 5
    
    base_score + time_bonus + defeat_bonus
  end

  # Add game over statistics
  defp add_game_over_stats(game_state) do
    current_time = :erlang.monotonic_time(:millisecond)
    start_time = game_state.start_time || current_time
    
    game_over_stats = %{
      time_survived: max(0, (current_time - start_time) / 1000),
      enemies_defeated: calculate_enemies_defeated(game_state),
      shots_fired: game_state.shots_fired || 0,
      accuracy: calculate_accuracy(game_state),
      final_score: game_state.score
    }
    
    Map.put(game_state, :game_over_stats, game_over_stats)
  end

  # Calculate shooting accuracy
  defp calculate_accuracy(game_state) do
    shots_fired = game_state.shots_fired || 0
    enemies_hit = game_state.enemies_hit || 0
    
    if shots_fired > 0 do
      (enemies_hit / shots_fired * 100) |> Float.round(1)
    else
      0.0
    end
  end

  # Calculate total enemies defeated during the game
  defp calculate_enemies_defeated(game_state) do
    # This would need to be tracked during the game
    # For now, estimate based on score (10 points per enemy)
    max(0, trunc(game_state.score / 10))
  end

  defp broadcast_state_update(state) do
    Enum.each(state.subscribers, fn pid ->
      send(pid, {:game_state_update, state.game_state})
    end)
  end
end