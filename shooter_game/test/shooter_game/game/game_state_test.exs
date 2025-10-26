defmodule ShooterGame.Game.GameStateTest do
  use ExUnit.Case, async: true
  
  alias ShooterGame.Game.{GameState, Player, Enemy, Bullet}
  alias ShooterGame.Game.TestHelpers

  describe "new/3" do
    test "creates a new game state with player and dimensions" do
      player = TestHelpers.create_test_player()
      game_state = GameState.new(player, 800, 600)

      assert game_state.player == player
      assert game_state.game_width == 800
      assert game_state.game_height == 600
      assert game_state.status == :waiting
      assert game_state.score == 0
      assert game_state.enemies == []
      assert game_state.bullets == []
      assert game_state.paused == false
    end

    test "validates positive dimensions" do
      player = TestHelpers.create_test_player()
      
      assert_raise ArgumentError, fn ->
        GameState.new(player, 0, 600)
      end
      
      assert_raise ArgumentError, fn ->
        GameState.new(player, 800, -100)
      end
    end
  end

  describe "start_game/1" do
    test "changes status from waiting to playing" do
      game_state = TestHelpers.create_test_game_state(status: :waiting)
      
      started_game = GameState.start_game(game_state)
      
      assert started_game.status == :playing
      assert started_game.start_time > 0
    end

    test "does not change already playing game" do
      game_state = TestHelpers.create_test_game_state(status: :playing)
      original_start_time = game_state.start_time
      
      updated_game = GameState.start_game(game_state)
      
      assert updated_game.status == :playing
      assert updated_game.start_time == original_start_time
    end
  end

  describe "pause_game/1 and unpause_game/1" do
    test "pauses and unpauses a playing game" do
      game_state = TestHelpers.create_test_game_state(status: :playing)
      
      paused_game = GameState.pause_game(game_state)
      assert paused_game.paused == true
      
      unpaused_game = GameState.unpause_game(paused_game)
      assert unpaused_game.paused == false
    end
  end

  describe "set_game_over/1" do
    test "sets game status to game_over and records end time" do
      game_state = TestHelpers.create_test_game_state(status: :playing)
      
      game_over_state = GameState.set_game_over(game_state)
      
      assert game_over_state.status == :game_over
      assert game_over_state.end_time > 0
    end
  end

  describe "reset/1" do
    test "resets game to initial state but keeps player and dimensions" do
      player = TestHelpers.create_test_player()
      enemies = TestHelpers.create_enemy_formation(3)
      bullets = TestHelpers.create_bullet_barrage(5)
      
      game_state = TestHelpers.create_test_game_state(
        player_opts: [health: 0],
        enemies: enemies,
        bullets: bullets,
        score: 1500,
        status: :game_over
      )
      
      reset_game = GameState.reset(game_state)
      
      # Player should be reset to full health at same position
      assert reset_game.player.health == 1
      assert reset_game.player.x == game_state.player.x
      assert reset_game.player.y == game_state.player.y
      
      # Game state should be reset
      assert reset_game.status == :waiting
      assert reset_game.score == 0
      assert reset_game.enemies == []
      assert reset_game.bullets == []
      assert reset_game.paused == false
      assert reset_game.start_time == 0
      assert reset_game.end_time == 0
      
      # Dimensions should be preserved
      assert reset_game.game_width == game_state.game_width
      assert reset_game.game_height == game_state.game_height
    end
  end

  describe "add_enemy/2" do
    test "adds enemy to the game state" do
      game_state = TestHelpers.create_test_game_state()
      enemy = TestHelpers.create_test_enemy()
      
      updated_game = GameState.add_enemy(game_state, enemy)
      
      assert length(updated_game.enemies) == 1
      assert hd(updated_game.enemies) == enemy
    end

    test "maintains enemy order when adding multiple" do
      game_state = TestHelpers.create_test_game_state()
      enemy1 = TestHelpers.create_test_enemy(id: "enemy_1")
      enemy2 = TestHelpers.create_test_enemy(id: "enemy_2")
      
      updated_game = 
        game_state
        |> GameState.add_enemy(enemy1)
        |> GameState.add_enemy(enemy2)
      
      assert length(updated_game.enemies) == 2
      assert Enum.map(updated_game.enemies, & &1.id) == ["enemy_1", "enemy_2"]
    end
  end

  describe "remove_enemy/2" do
    test "removes enemy by id" do
      enemy1 = TestHelpers.create_test_enemy(id: "enemy_1")
      enemy2 = TestHelpers.create_test_enemy(id: "enemy_2")
      game_state = TestHelpers.create_test_game_state(enemies: [enemy1, enemy2])
      
      updated_game = GameState.remove_enemy(game_state, "enemy_1")
      
      assert length(updated_game.enemies) == 1
      assert hd(updated_game.enemies).id == "enemy_2"
    end

    test "does nothing if enemy id not found" do
      enemy = TestHelpers.create_test_enemy(id: "enemy_1")
      game_state = TestHelpers.create_test_game_state(enemies: [enemy])
      
      updated_game = GameState.remove_enemy(game_state, "nonexistent")
      
      assert updated_game.enemies == game_state.enemies
    end
  end

  describe "update_enemy/2" do
    test "updates existing enemy" do
      enemy = TestHelpers.create_test_enemy(id: "enemy_1", health: 3)
      game_state = TestHelpers.create_test_game_state(enemies: [enemy])
      
      damaged_enemy = Enemy.take_damage(enemy, 2)
      updated_game = GameState.update_enemy(game_state, damaged_enemy)
      
      assert length(updated_game.enemies) == 1
      assert hd(updated_game.enemies).health == 1
      assert hd(updated_game.enemies).id == "enemy_1"
    end
  end

  describe "add_bullet/2 and remove_bullet/2" do
    test "adds and removes bullets correctly" do
      game_state = TestHelpers.create_test_game_state()
      bullet = TestHelpers.create_test_bullet(id: "bullet_1")
      
      # Add bullet
      updated_game = GameState.add_bullet(game_state, bullet)
      assert length(updated_game.bullets) == 1
      assert hd(updated_game.bullets).id == "bullet_1"
      
      # Remove bullet
      final_game = GameState.remove_bullet(updated_game, "bullet_1")
      assert final_game.bullets == []
    end
  end

  describe "status checks" do
    test "playing?/1 returns correct status" do
      assert GameState.playing?(TestHelpers.create_test_game_state(status: :playing))
      refute GameState.playing?(TestHelpers.create_test_game_state(status: :waiting))
      refute GameState.playing?(TestHelpers.create_test_game_state(status: :paused))
      refute GameState.playing?(TestHelpers.create_test_game_state(status: :game_over))
    end

    test "game_over?/1 returns correct status" do
      assert GameState.game_over?(TestHelpers.create_test_game_state(status: :game_over))
      refute GameState.game_over?(TestHelpers.create_test_game_state(status: :playing))
      refute GameState.game_over?(TestHelpers.create_test_game_state(status: :waiting))
      refute GameState.game_over?(TestHelpers.create_test_game_state(status: :paused))
    end
  end

  describe "statistics" do
    test "enemy_count/1 returns correct count" do
      enemies = TestHelpers.create_enemy_formation(5)
      game_state = TestHelpers.create_test_game_state(enemies: enemies)
      
      assert GameState.enemy_count(game_state) == 5
    end

    test "bullet_count/1 returns correct count" do
      bullets = TestHelpers.create_bullet_barrage(8)
      game_state = TestHelpers.create_test_game_state(bullets: bullets)
      
      assert GameState.bullet_count(game_state) == 8
    end

    test "game_duration/1 calculates time correctly" do
      start_time = :erlang.monotonic_time(:millisecond)
      game_state = %{TestHelpers.create_test_game_state() | start_time: start_time}
      
      # Simulate some time passing
      :timer.sleep(10)
      duration = GameState.game_duration(game_state)
      
      assert duration >= 10
      assert duration < 100  # Should be reasonable
    end
  end
end