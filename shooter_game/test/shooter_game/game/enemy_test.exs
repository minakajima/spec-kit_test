defmodule ShooterGame.Game.EnemyTest do
  use ExUnit.Case, async: true
  
  alias ShooterGame.Game.Enemy
  alias ShooterGame.Game.TestHelpers

  describe "new/2" do
    test "creates enemy with default properties" do
      enemy = Enemy.new(200, 100)
      
      assert enemy.x == 200
      assert enemy.y == 100
      assert enemy.health == 1
      assert enemy.width == 30
      assert enemy.height == 30
      assert enemy.velocity_y == 2.0
      assert enemy.curve_amplitude == 50.0
      assert enemy.curve_frequency == 0.1
      assert enemy.shot_interval == 1500
      assert enemy.shot_accuracy == 0.8
      assert enemy.behavior == :curved_shooter
      assert enemy.color == :red
      assert enemy.points == 10
      assert is_binary(enemy.id)
    end

    test "creates enemy with custom properties" do
      opts = [
        id: "test_enemy_1",
        health: 3,
        velocity_y: 4.0,
        shot_interval: 1000,
        behavior: :straight,
        color: :green,
        points: 20
      ]
      
      enemy = Enemy.new(150, 80, opts)
      
      assert enemy.x == 150
      assert enemy.y == 80
      assert enemy.id == "test_enemy_1"
      assert enemy.health == 3
      assert enemy.velocity_y == 4.0
      assert enemy.shot_interval == 1000
      assert enemy.behavior == :straight
      assert enemy.color == :green
      assert enemy.points == 20
    end
  end

  describe "movement behaviors" do
    test "curved_shooter behavior updates position with curve" do
      enemy = Enemy.new(400, 100, behavior: :curved_shooter, curve_amplitude: 50.0)
      delta_time = 0.1
      
      updated_enemy = Enemy.update_position(enemy, delta_time)
      
      assert updated_enemy.y == enemy.y + enemy.velocity_y * delta_time
      assert updated_enemy.movement_time == delta_time
      assert updated_enemy.angle != enemy.angle
      # X position should change due to curve (though exact value depends on sine calculation)
    end

    test "straight behavior moves in straight line" do
      enemy = Enemy.new(400, 100, behavior: :straight, velocity_x: 1.0, velocity_y: 2.0)
      delta_time = 0.5
      
      updated_enemy = Enemy.update_position(enemy, delta_time)
      
      assert updated_enemy.x == 400 + 1.0 * delta_time
      assert updated_enemy.y == 100 + 2.0 * delta_time
    end

    test "zigzag behavior alternates direction" do
      enemy = Enemy.new(400, 100, behavior: :zigzag, velocity_x: 2.0, velocity_y: 1.0)
      delta_time = 0.3
      
      updated_enemy = Enemy.update_position(enemy, delta_time)
      
      assert updated_enemy.y == 100 + 1.0 * delta_time
      assert updated_enemy.movement_time == delta_time
      # X direction depends on movement_time calculation
    end

    test "spinner behavior rotates while moving" do
      enemy = Enemy.new(400, 100, behavior: :spinner, velocity_x: 1.0, velocity_y: 2.0)
      delta_time = 0.2
      
      updated_enemy = Enemy.update_position(enemy, delta_time)
      
      assert updated_enemy.x == 400 + 1.0 * delta_time
      assert updated_enemy.y == 100 + 2.0 * delta_time
      assert updated_enemy.angle == enemy.angle + delta_time * 5.0
      assert updated_enemy.movement_time == delta_time
    end
  end

  describe "shooting mechanics" do
    test "can_shoot?/1 respects shot interval" do
      enemy = Enemy.new(400, 100)
      
      # Should be able to shoot initially
      assert Enemy.can_shoot?(enemy)
      
      # After recording a shot, should respect interval
      shot_enemy = Enemy.record_shot(enemy)
      refute Enemy.can_shoot?(shot_enemy)
      
      # Simulate interval period passing
      old_time = :erlang.monotonic_time(:millisecond) - 2000
      cooled_enemy = %{shot_enemy | last_shot_time: old_time}
      assert Enemy.can_shoot?(cooled_enemy)
    end

    test "record_shot/1 updates last shot time" do
      enemy = Enemy.new(400, 100)
      original_time = enemy.last_shot_time
      
      :timer.sleep(1)
      shot_enemy = Enemy.record_shot(enemy)
      
      assert shot_enemy.last_shot_time > original_time
    end

    test "calculate_shot_direction/4 aims toward player" do
      enemy = Enemy.new(400, 100)
      player_x = 500
      player_y = 300
      bullet_speed = 6.0
      
      {vel_x, vel_y} = Enemy.calculate_shot_direction(enemy, player_x, player_y, bullet_speed)
      
      # Should have velocity components pointing toward player
      assert vel_x > 0  # Moving right toward player
      assert vel_y > 0  # Moving down toward player
      
      # Total velocity should approximately equal bullet speed
      total_speed = :math.sqrt(vel_x * vel_x + vel_y * vel_y)
      assert abs(total_speed - bullet_speed) < 0.1
    end

    test "calculate_shot_direction/4 applies accuracy variance" do
      enemy = Enemy.new(400, 100, shot_accuracy: 0.5)  # Low accuracy
      player_x = 400  # Directly below enemy
      player_y = 300
      bullet_speed = 6.0
      
      # Generate multiple shots to test variance
      directions = for _ <- 1..10 do
        Enemy.calculate_shot_direction(enemy, player_x, player_y, bullet_speed)
      end
      
      # With low accuracy, shots should have some variance
      x_velocities = Enum.map(directions, &elem(&1, 0))
      assert Enum.any?(x_velocities, &(&1 != 0))  # Some shots should not be perfectly straight
    end
  end

  describe "health and damage" do
    test "take_damage/2 reduces health correctly" do
      enemy = Enemy.new(400, 100, health: 3)
      
      damaged_enemy = Enemy.take_damage(enemy, 1)
      assert damaged_enemy.health == 2
      
      more_damaged = Enemy.take_damage(damaged_enemy, 2)
      assert more_damaged.health == 0
      
      # Health cannot go below 0
      over_damaged = Enemy.take_damage(more_damaged, 5)
      assert over_damaged.health == 0
    end

    test "alive?/1 checks health correctly" do
      alive_enemy = Enemy.new(400, 100, health: 1)
      assert Enemy.alive?(alive_enemy)
      
      dead_enemy = Enemy.take_damage(alive_enemy, 1)
      refute Enemy.alive?(dead_enemy)
    end
  end

  describe "positioning and boundaries" do
    test "off_screen?/3 detects when enemy is outside boundaries" do
      game_width = 800
      game_height = 600
      
      # On screen
      on_screen = Enemy.new(400, 300)
      refute Enemy.off_screen?(on_screen, game_width, game_height)
      
      # Off left side
      off_left = Enemy.new(-50, 300)
      assert Enemy.off_screen?(off_left, game_width, game_height)
      
      # Off right side
      off_right = Enemy.new(850, 300)
      assert Enemy.off_screen?(off_right, game_width, game_height)
      
      # Off top
      off_top = Enemy.new(400, -50)
      assert Enemy.off_screen?(off_top, game_width, game_height)
      
      # Off bottom
      off_bottom = Enemy.new(400, 650)
      assert Enemy.off_screen?(off_bottom, game_width, game_height)
    end

    test "bounding_box/1 calculates correct bounding box" do
      enemy = Enemy.new(400, 200, width: 30, height: 30)
      
      {left, top, right, bottom} = Enemy.bounding_box(enemy)
      
      assert left == 385   # 400 - 15
      assert top == 185    # 200 - 15
      assert right == 415  # 400 + 15
      assert bottom == 215 # 200 + 15
    end

    test "bullet_spawn_position/1 calculates spawn position at bottom of enemy" do
      enemy = Enemy.new(400, 200, height: 30)
      
      {x, y} = Enemy.bullet_spawn_position(enemy)
      
      assert x == 400  # Same x as enemy
      assert y == 215  # 200 + 15 (bottom of enemy)
    end
  end

  describe "age/1" do
    test "calculates correct age" do
      enemy = Enemy.new(400, 100)
      
      # Immediately after creation, age should be very small
      age = Enemy.age(enemy)
      assert age >= 0
      assert age < 10  # Should be less than 10ms
      
      # Simulate older enemy
      old_spawn_time = :erlang.monotonic_time(:millisecond) - 5000
      old_enemy = %{enemy | spawn_time: old_spawn_time}
      old_age = Enemy.age(old_enemy)
      assert old_age >= 5000
    end
  end

  describe "integration with TestHelpers" do
    test "create_test_enemy works correctly" do
      enemy = TestHelpers.create_test_enemy()
      assert %Enemy{} = enemy
      assert enemy.x == 400.0
      assert enemy.y == 100.0
      
      custom_enemy = TestHelpers.create_test_enemy(x: 200, y: 50, health: 2)
      assert custom_enemy.x == 200
      assert custom_enemy.y == 50
      assert custom_enemy.health == 2
    end

    test "create_enemy_formation creates multiple enemies" do
      enemies = TestHelpers.create_enemy_formation(3, start_x: 100, spacing: 80)
      
      assert length(enemies) == 3
      assert Enum.at(enemies, 0).x == 100
      assert Enum.at(enemies, 1).x == 180
      assert Enum.at(enemies, 2).x == 260
    end
  end
end