defmodule ShooterGame.GameEngineTest do
  use ExUnit.Case, async: false  # Not async because it involves GenServer
  
  alias ShooterGame.GameEngine
  alias ShooterGame.Game.{GameState, Player, Enemy, Bullet}
  alias ShooterGame.Game.TestHelpers

  setup do
    # Start a fresh GameEngine for each test
    {:ok, pid} = GenServer.start_link(GameEngine, [], name: :"test_engine_#{:rand.uniform(1000)}")
    
    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)
    
    %{engine: pid}
  end

  describe "start_game/0" do
    test "starts a new game successfully", %{engine: engine} do
      assert :ok == GenServer.call(engine, :start_game)
      
      game_state = GenServer.call(engine, :get_game_state)
      
      assert game_state != nil
      assert game_state.status == :playing
      assert %Player{} = game_state.player
      assert game_state.player.x == 400  # Middle of default 800px width
      assert game_state.score == 0
      assert game_state.enemies == []
      assert game_state.bullets == []
    end

    test "game starts with player at bottom center", %{engine: engine} do
      GenServer.call(engine, :start_game)
      game_state = GenServer.call(engine, :get_game_state)
      
      assert game_state.player.x == 400  # 800 / 2
      assert game_state.player.y == 550  # 600 - 50
    end
  end

  describe "reset_game/0" do
    test "resets game to initial state", %{engine: engine} do
      # Start and modify game state
      GenServer.call(engine, :start_game)
      GenServer.cast(engine, {:update_player_position, 200, 300})
      
      # Add some entities and score (would normally happen through gameplay)
      game_state = GenServer.call(engine, :get_game_state)
      modified_state = %{game_state | score: 500, status: :game_over}
      :sys.replace_state(engine, fn _ -> %{GenServer.call(engine, :get_game_state) | game_state: modified_state} end)
      
      # Reset the game
      assert :ok == GenServer.call(engine, :reset_game)
      
      reset_state = GenServer.call(engine, :get_game_state)
      assert reset_state.score == 0
      assert reset_state.status == :waiting
      assert reset_state.enemies == []
      assert reset_state.bullets == []
    end
  end

  describe "pause/unpause game" do
    test "can pause and unpause game", %{engine: engine} do
      GenServer.call(engine, :start_game)
      
      assert :ok == GenServer.call(engine, {:set_paused, true})
      game_state = GenServer.call(engine, :get_game_state)
      assert game_state.paused == true
      
      assert :ok == GenServer.call(engine, {:set_paused, false})
      game_state = GenServer.call(engine, :get_game_state)
      assert game_state.paused == false
    end
  end

  describe "player control" do
    test "updates player position", %{engine: engine} do
      GenServer.call(engine, :start_game)
      
      GenServer.cast(engine, {:update_player_position, 300, 200})
      
      # Give async operation time to complete
      :timer.sleep(10)
      
      game_state = GenServer.call(engine, :get_game_state)
      assert game_state.player.x == 300
      assert game_state.player.y == 200
    end

    test "clamps player position to boundaries", %{engine: engine} do
      GenServer.call(engine, :start_game)
      
      # Try to move outside boundaries
      GenServer.cast(engine, {:update_player_position, -100, -100})
      :timer.sleep(10)
      
      game_state = GenServer.call(engine, :get_game_state)
      assert game_state.player.x >= 20  # Half of player width (40/2)
      assert game_state.player.y >= 20  # Half of player height (40/2)
    end

    test "ignores position updates when not playing", %{engine: engine} do
      # Don't start game (status should be :waiting)
      original_state = GenServer.call(engine, :get_game_state)
      
      GenServer.cast(engine, {:update_player_position, 300, 200})
      :timer.sleep(10)
      
      final_state = GenServer.call(engine, :get_game_state)
      assert final_state == original_state  # No change
    end

    test "sets player firing state", %{engine: engine} do
      GenServer.call(engine, :start_game)
      
      GenServer.cast(engine, {:set_player_firing, true})
      :timer.sleep(10)
      
      game_state = GenServer.call(engine, :get_game_state)
      assert game_state.player.firing == true
      
      GenServer.cast(engine, {:set_player_firing, false})
      :timer.sleep(10)
      
      game_state = GenServer.call(engine, :get_game_state)
      assert game_state.player.firing == false
    end
  end

  describe "subscription system" do
    test "subscribes and receives game state updates", %{engine: engine} do
      # Subscribe to updates
      GenServer.cast(engine, {:subscribe, self()})
      
      # Start game should trigger update
      GenServer.call(engine, :start_game)
      
      # Should receive game state update
      assert_receive {:game_state_update, game_state}, 100
      assert game_state.status == :playing
    end

    test "unsubscribes from updates", %{engine: engine} do
      # Subscribe then unsubscribe
      GenServer.cast(engine, {:subscribe, self()})
      GenServer.cast(engine, {:unsubscribe, self()})
      
      # Start game
      GenServer.call(engine, :start_game)
      
      # Should not receive update
      refute_receive {:game_state_update, _}, 50
    end

    test "handles subscriber process crashes", %{engine: engine} do
      # Create a temporary process to subscribe
      subscriber = spawn(fn -> :timer.sleep(1000) end)
      GenServer.cast(engine, {:subscribe, subscriber})
      
      # Kill the subscriber
      Process.exit(subscriber, :kill)
      :timer.sleep(10)
      
      # Engine should still work normally
      assert :ok == GenServer.call(engine, :start_game)
    end
  end

  describe "force_update/0" do
    test "forces immediate game state update", %{engine: engine} do
      GenServer.call(engine, :start_game)
      GenServer.cast(engine, {:subscribe, self()})
      
      # Clear any pending messages
      receive do
        {:game_state_update, _} -> :ok
      after
        10 -> :ok
      end
      
      # Force update
      GenServer.cast(engine, :force_update)
      
      # Should receive update
      assert_receive {:game_state_update, _}, 100
    end
  end

  describe "game loop integration" do
    @tag :slow
    test "game tick updates are sent periodically", %{engine: engine} do
      GenServer.call(engine, :start_game)
      GenServer.cast(engine, {:subscribe, self()})
      
      # Should receive periodic updates (game runs at 30Hz = ~33ms intervals)
      assert_receive {:game_state_update, _}, 100
    end

    @tag :slow  
    test "paused game does not send updates", %{engine: engine} do
      GenServer.call(engine, :start_game)
      GenServer.call(engine, {:set_paused, true})
      GenServer.cast(engine, {:subscribe, self()})
      
      # Clear initial subscription message
      receive do
        {:game_state_update, _} -> :ok
      after
        10 -> :ok
      end
      
      # Should not receive updates while paused
      refute_receive {:game_state_update, _}, 100
    end
  end

  describe "error handling" do
    test "handles get_game_state when no game started", %{engine: engine} do
      game_state = GenServer.call(engine, :get_game_state)
      assert game_state == nil
    end

    test "handles reset when no game exists", %{engine: engine} do
      # Should not crash
      assert :ok == GenServer.call(engine, :reset_game)
    end

    test "handles pause when no game exists", %{engine: engine} do
      # Should not crash
      assert :ok == GenServer.call(engine, {:set_paused, true})
    end
  end

  describe "game state transitions" do
    test "progresses through game states correctly", %{engine: engine} do
      # Initial state
      assert GenServer.call(engine, :get_game_state) == nil
      
      # Start game
      GenServer.call(engine, :start_game)
      game_state = GenServer.call(engine, :get_game_state)
      assert game_state.status == :playing
      
      # Pause game
      GenServer.call(engine, {:set_paused, true})
      game_state = GenServer.call(engine, :get_game_state)
      assert game_state.paused == true
      
      # Resume game
      GenServer.call(engine, {:set_paused, false})
      game_state = GenServer.call(engine, :get_game_state)
      assert game_state.paused == false
      
      # Reset game
      GenServer.call(engine, :reset_game)
      game_state = GenServer.call(engine, :get_game_state)
      assert game_state.status == :waiting
    end
  end
end