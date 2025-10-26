defmodule ShooterGame.Game.PlayerTest do
  use ExUnit.Case, async: true
  
  alias ShooterGame.Game.Player
  alias ShooterGame.Game.TestHelpers

  describe "new/2" do
    test "creates player with default properties" do
      player = Player.new(400, 500)
      
      assert player.x == 400
      assert player.y == 500
      assert player.health == 1
      assert player.width == 40
      assert player.height == 40
      assert player.firing == false
      assert player.shot_cooldown == 100
      assert player.max_speed == 8.0
      assert player.color == :blue
    end

    test "creates player with custom properties" do
      opts = [
        health: 3,
        width: 50,
        height: 50,
        shot_cooldown: 50,
        max_speed: 12.0,
        color: :red
      ]
      
      player = Player.new(300, 400, opts)
      
      assert player.x == 300
      assert player.y == 400
      assert player.health == 3
      assert player.width == 50
      assert player.height == 50
      assert player.shot_cooldown == 50
      assert player.max_speed == 12.0
      assert player.color == :red
    end
  end

  describe "move_to/5" do
    test "moves player to target position within bounds" do
      player = Player.new(400, 300)
      
      moved_player = Player.move_to(player, 200, 250, 800, 600)
      
      assert moved_player.x == 200
      assert moved_player.y == 250
      assert moved_player.velocity_x == -200  # 200 - 400
      assert moved_player.velocity_y == -50   # 250 - 300
    end

    test "clamps position to game boundaries" do
      player = Player.new(400, 300)
      
      # Try to move outside left boundary
      moved_player = Player.move_to(player, -50, 300, 800, 600)
      assert moved_player.x == 20  # half_width = 20
      
      # Try to move outside right boundary
      moved_player = Player.move_to(player, 850, 300, 800, 600)
      assert moved_player.x == 780  # 800 - 20
      
      # Try to move outside top boundary
      moved_player = Player.move_to(player, 400, -50, 800, 600)
      assert moved_player.y == 20  # half_height = 20
      
      # Try to move outside bottom boundary
      moved_player = Player.move_to(player, 400, 650, 800, 600)
      assert moved_player.y == 580  # 600 - 20
    end
  end

  describe "firing mechanics" do
    test "set_firing/2 updates firing state" do
      player = Player.new(400, 300)
      
      firing_player = Player.set_firing(player, true)
      assert firing_player.firing == true
      
      not_firing_player = Player.set_firing(firing_player, false)
      assert not_firing_player.firing == false
    end

    test "can_fire?/1 respects cooldown" do
      player = Player.new(400, 300)
      
      # Should be able to fire initially
      assert Player.can_fire?(player)
      
      # After recording a shot, should respect cooldown
      shot_player = Player.record_shot(player)
      refute Player.can_fire?(shot_player)
      
      # Simulate cooldown period passing
      old_time = :erlang.monotonic_time(:millisecond) - 150
      cooled_player = %{shot_player | last_shot_time: old_time}
      assert Player.can_fire?(cooled_player)
    end

    test "record_shot/1 updates last shot time" do
      player = Player.new(400, 300)
      original_time = player.last_shot_time
      
      # Wait a bit to ensure time difference
      :timer.sleep(1)
      shot_player = Player.record_shot(player)
      
      assert shot_player.last_shot_time > original_time
    end
  end

  describe "health and damage" do
    test "take_damage/2 reduces health correctly" do
      player = Player.new(400, 300, health: 3)
      
      damaged_player = Player.take_damage(player, 1)
      assert damaged_player.health == 2
      
      more_damaged = Player.take_damage(damaged_player, 2)
      assert more_damaged.health == 0
      
      # Health cannot go below 0
      over_damaged = Player.take_damage(more_damaged, 5)
      assert over_damaged.health == 0
    end

    test "heal/3 increases health up to maximum" do
      player = Player.new(400, 300, health: 1)
      damaged_player = Player.take_damage(player, 1)
      assert damaged_player.health == 0
      
      healed_player = Player.heal(damaged_player, 1)
      assert healed_player.health == 1
      
      # Cannot heal above maximum (default 1)
      over_healed = Player.heal(healed_player, 2)
      assert over_healed.health == 1
      
      # Test with custom maximum
      max_healed = Player.heal(damaged_player, 3, 3)
      assert max_healed.health == 3
    end

    test "alive?/1 checks health correctly" do
      alive_player = Player.new(400, 300, health: 1)
      assert Player.alive?(alive_player)
      
      dead_player = Player.take_damage(alive_player, 1)
      refute Player.alive?(dead_player)
    end
  end

  describe "bounding_box/1" do
    test "calculates correct bounding box" do
      player = Player.new(400, 300, width: 40, height: 40)
      
      {left, top, right, bottom} = Player.bounding_box(player)
      
      assert left == 380   # 400 - 20
      assert top == 280    # 300 - 20
      assert right == 420  # 400 + 20
      assert bottom == 320 # 300 + 20
    end
  end

  describe "bullet_spawn_position/1" do
    test "calculates bullet spawn position at front of ship" do
      player = Player.new(400, 300, height: 40)
      
      {x, y} = Player.bullet_spawn_position(player)
      
      assert x == 400  # Same x as player
      assert y == 280  # 300 - 20 (front of ship)
    end
  end

  describe "property validation" do
    test "enforces required keys" do
      assert_raise ArgumentError, fn ->
        struct!(Player, %{y: 300})  # Missing x
      end
      
      assert_raise ArgumentError, fn ->
        struct!(Player, %{x: 400})  # Missing y
      end
    end

    test "validates color types" do
      # Valid colors
      blue_player = Player.new(400, 300, color: :blue)
      assert blue_player.color == :blue
      
      red_player = Player.new(400, 300, color: :red)
      assert red_player.color == :red
      
      green_player = Player.new(400, 300, color: :green)
      assert green_player.color == :green
    end
  end

  describe "integration with TestHelpers" do
    test "create_test_player works correctly" do
      player = TestHelpers.create_test_player()
      assert %Player{} = player
      assert player.x == 400.0
      assert player.y == 500.0
      
      custom_player = TestHelpers.create_test_player(x: 200, y: 100, health: 3)
      assert custom_player.x == 200
      assert custom_player.y == 100
      assert custom_player.health == 3
    end
  end
end