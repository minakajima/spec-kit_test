defmodule ShooterGame.Game.BulletTest do
  use ExUnit.Case, async: true
  
  alias ShooterGame.Game.Bullet
  alias ShooterGame.Game.TestHelpers

  describe "new_player_bullet/3" do
    test "creates player bullet with upward velocity" do
      bullet = Bullet.new_player_bullet(400, 300)
      
      assert bullet.x == 400
      assert bullet.y == 300
      assert bullet.velocity_x == 0.0
      assert bullet.velocity_y == -8.0
      assert bullet.owner_type == :player
      assert bullet.owner_id == nil
      assert bullet.color == :yellow
      assert is_binary(bullet.id)
    end

    test "creates player bullet with player ID" do
      bullet = Bullet.new_player_bullet(400, 300, "player_123")
      
      assert bullet.owner_id == "player_123"
      assert bullet.owner_type == :player
    end
  end

  describe "new_enemy_bullet/5" do
    test "creates enemy bullet with specified direction" do
      bullet = Bullet.new_enemy_bullet(200, 150, 3.0, 5.0, "enemy_456")
      
      assert bullet.x == 200
      assert bullet.y == 150
      assert bullet.velocity_x == 3.0
      assert bullet.velocity_y == 5.0
      assert bullet.owner_type == :enemy
      assert bullet.owner_id == "enemy_456"
      assert bullet.color == :red
      assert bullet.width == 3
      assert bullet.height == 6
    end
  end

  describe "new/6" do
    test "creates bullet with custom properties" do
      opts = [
        id: "custom_bullet",
        owner_id: "test_owner",
        damage: 2,
        width: 6,
        height: 10,
        color: :blue,
        trail_length: 3,
        piercing: true,
        lifetime: 3000
      ]
      
      bullet = Bullet.new(100, 200, 2.0, -4.0, :player, opts)
      
      assert bullet.x == 100
      assert bullet.y == 200
      assert bullet.velocity_x == 2.0
      assert bullet.velocity_y == -4.0
      assert bullet.owner_type == :player
      assert bullet.id == "custom_bullet"
      assert bullet.owner_id == "test_owner"
      assert bullet.damage == 2
      assert bullet.width == 6
      assert bullet.height == 10
      assert bullet.color == :blue
      assert bullet.trail_length == 3
      assert bullet.piercing == true
      assert bullet.lifetime == 3000
    end
  end

  describe "update_position/2" do
    test "updates bullet position based on velocity" do
      bullet = Bullet.new_player_bullet(400, 300)
      delta_time = 0.1
      
      updated_bullet = Bullet.update_position(bullet, delta_time)
      
      assert updated_bullet.x == 400.0  # No x movement
      assert updated_bullet.y == 299.2  # 300 + (-8.0 * 0.1)
    end

    test "updates position with diagonal movement" do
      bullet = Bullet.new_enemy_bullet(200, 150, 6.0, 4.0, "enemy_1")
      delta_time = 0.5
      
      updated_bullet = Bullet.update_position(bullet, delta_time)
      
      assert updated_bullet.x == 203.0  # 200 + (6.0 * 0.5)
      assert updated_bullet.y == 152.0  # 150 + (4.0 * 0.5)
    end
  end

  describe "boundary and lifecycle checks" do
    test "off_screen?/3 detects when bullet is outside boundaries" do
      game_width = 800
      game_height = 600
      
      # On screen
      on_screen = Bullet.new_player_bullet(400, 300)
      refute Bullet.off_screen?(on_screen, game_width, game_height)
      
      # Off left side
      off_left = Bullet.new_player_bullet(-10, 300)
      assert Bullet.off_screen?(off_left, game_width, game_height)
      
      # Off right side
      off_right = Bullet.new_player_bullet(810, 300)
      assert Bullet.off_screen?(off_right, game_width, game_height)
      
      # Off top (player bullets)
      off_top = Bullet.new_player_bullet(400, -10)
      assert Bullet.off_screen?(off_top, game_width, game_height)
      
      # Off bottom (enemy bullets)
      off_bottom = Bullet.new_enemy_bullet(400, 610, 0.0, 2.0, "enemy_1")
      assert Bullet.off_screen?(off_bottom, game_width, game_height)
    end

    test "expired?/1 checks bullet lifetime" do
      bullet = Bullet.new_player_bullet(400, 300)
      
      # Fresh bullet should not be expired
      refute Bullet.expired?(bullet)
      
      # Simulate old bullet
      old_spawn_time = :erlang.monotonic_time(:millisecond) - 6000
      old_bullet = %{bullet | spawn_time: old_spawn_time}
      assert Bullet.expired?(old_bullet)
    end
  end

  describe "bounding_box/1" do
    test "calculates correct bounding box" do
      bullet = Bullet.new_player_bullet(400, 300)  # width: 4, height: 8
      
      {left, top, right, bottom} = Bullet.bounding_box(bullet)
      
      assert left == 398   # 400 - 2
      assert top == 296    # 300 - 4
      assert right == 402  # 400 + 2
      assert bottom == 304 # 300 + 4
    end
  end

  describe "collision targeting" do
    test "can_hit?/2 determines valid targets" do
      player_bullet = Bullet.new_player_bullet(400, 300)
      enemy_bullet = Bullet.new_enemy_bullet(200, 150, 2.0, 3.0, "enemy_1")
      
      # Player bullets can hit enemies
      assert Bullet.can_hit?(player_bullet, :enemy)
      refute Bullet.can_hit?(player_bullet, :player)
      
      # Enemy bullets can hit players
      assert Bullet.can_hit?(enemy_bullet, :player)
      refute Bullet.can_hit?(enemy_bullet, :enemy)
    end

    test "fired_by?/3 identifies bullet ownership" do
      player_bullet = Bullet.new_player_bullet(400, 300, "player_123")
      enemy_bullet = Bullet.new_enemy_bullet(200, 150, 2.0, 3.0, "enemy_456")
      
      assert Bullet.fired_by?(player_bullet, :player, "player_123")
      refute Bullet.fired_by?(player_bullet, :player, "wrong_id")
      refute Bullet.fired_by?(player_bullet, :enemy, "player_123")
      
      assert Bullet.fired_by?(enemy_bullet, :enemy, "enemy_456")
      refute Bullet.fired_by?(enemy_bullet, :enemy, "wrong_id")
      refute Bullet.fired_by?(enemy_bullet, :player, "enemy_456")
    end
  end

  describe "special bullet types" do
    test "create_homing_bullet/5 creates bullet aimed at target" do
      bullet = Bullet.create_homing_bullet(100, 100, 200, 300, "enemy_1")
      
      assert bullet.owner_type == :enemy
      assert bullet.owner_id == "enemy_1"
      assert bullet.color == :orange
      
      # Should have velocity components pointing toward target
      assert bullet.velocity_x > 0  # Moving right toward target
      assert bullet.velocity_y > 0  # Moving down toward target
    end

    test "create_homing_bullet/5 with custom options" do
      opts = [speed: 8.0, color: :purple, trail_length: 5]
      bullet = Bullet.create_homing_bullet(100, 100, 200, 300, "enemy_1", opts)
      
      assert bullet.color == :purple
      assert bullet.trail_length == 5
      
      # Check speed is approximately correct
      speed = :math.sqrt(bullet.velocity_x * bullet.velocity_x + bullet.velocity_y * bullet.velocity_y)
      assert abs(speed - 8.0) < 0.1
    end

    test "create_spread_bullets/6 creates multiple bullets in spread pattern" do
      bullets = Bullet.create_spread_bullets(400, 200, 0.0, 6.0, "enemy_1", 3, :math.pi() / 4)
      
      assert length(bullets) == 3
      assert Enum.all?(bullets, &(&1.owner_id == "enemy_1"))
      assert Enum.all?(bullets, &(&1.owner_type == :enemy))
      
      # Bullets should have different directions
      velocities_x = Enum.map(bullets, & &1.velocity_x)
      assert Enum.uniq(velocities_x) |> length() > 1
    end

    test "create_spread_bullets/6 with single bullet" do
      bullets = Bullet.create_spread_bullets(400, 200, 0.0, 6.0, "enemy_1", 1, :math.pi() / 4)
      
      assert length(bullets) == 1
      bullet = hd(bullets)
      assert bullet.velocity_x == 0.0
      assert bullet.velocity_y == 6.0
    end
  end

  describe "age/1 and has_trail?/1" do
    test "age/1 calculates correct age" do
      bullet = Bullet.new_player_bullet(400, 300)
      
      age = Bullet.age(bullet)
      assert age >= 0
      assert age < 10  # Should be less than 10ms
      
      # Simulate older bullet
      old_spawn_time = :erlang.monotonic_time(:millisecond) - 2000
      old_bullet = %{bullet | spawn_time: old_spawn_time}
      old_age = Bullet.age(old_bullet)
      assert old_age >= 2000
    end

    test "has_trail?/1 checks trail effect" do
      no_trail = Bullet.new_player_bullet(400, 300)
      refute Bullet.has_trail?(no_trail)
      
      with_trail = Bullet.new(400, 300, 0.0, -8.0, :player, trail_length: 3)
      assert Bullet.has_trail?(with_trail)
    end
  end

  describe "integration with TestHelpers" do
    test "create_test_bullet works correctly" do
      bullet = TestHelpers.create_test_bullet()
      assert %Bullet{} = bullet
      assert bullet.x == 400.0
      assert bullet.y == 300.0
      assert bullet.owner_type == :player
      
      custom_bullet = TestHelpers.create_test_bullet(x: 200, velocity_y: -10.0, owner_type: :enemy)
      assert custom_bullet.x == 200
      assert custom_bullet.velocity_y == -10.0
      assert custom_bullet.owner_type == :enemy
    end

    test "create_bullet_barrage creates multiple bullets" do
      bullets = TestHelpers.create_bullet_barrage(5, start_x: 300, spread: 100)
      
      assert length(bullets) == 5
      x_positions = Enum.map(bullets, & &1.x)
      assert Enum.uniq(x_positions) |> length() > 1  # Should have different x positions
    end
  end
end