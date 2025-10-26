defmodule ShooterGame.Game.CollisionTest do
  use ExUnit.Case, async: true
  
  alias ShooterGame.Game.{Collision, Player, Enemy, Bullet}
  alias ShooterGame.Game.TestHelpers

  describe "boxes_collide?/2" do
    test "detects collision between overlapping boxes" do
      box1 = {10, 10, 30, 30}  # left, top, right, bottom
      box2 = {20, 20, 40, 40}  # Overlaps with box1
      
      assert Collision.boxes_collide?(box1, box2)
      assert Collision.boxes_collide?(box2, box1)  # Commutative
    end

    test "detects no collision between separate boxes" do
      box1 = {10, 10, 30, 30}
      box2 = {40, 40, 60, 60}  # Completely separate
      
      refute Collision.boxes_collide?(box1, box2)
      refute Collision.boxes_collide?(box2, box1)
    end

    test "detects edge cases correctly" do
      box1 = {10, 10, 30, 30}
      box2 = {30, 30, 50, 50}  # Touching at corner
      
      refute Collision.boxes_collide?(box1, box2)  # Just touching, not overlapping
      
      box3 = {25, 25, 45, 45}  # Overlapping by 5 pixels
      assert Collision.boxes_collide?(box1, box3)
    end
  end

  describe "player_enemy_collision?/2" do
    test "detects collision when player and enemy overlap" do
      {player, enemy} = TestHelpers.create_collision_scenario(:player_enemy)
      
      assert Collision.player_enemy_collision?(player, enemy)
    end

    test "detects no collision when player and enemy are separate" do
      player = TestHelpers.create_test_player(x: 100, y: 100)
      enemy = TestHelpers.create_test_enemy(x: 700, y: 500)
      
      refute Collision.player_enemy_collision?(player, enemy)
    end

    test "detects collision based on actual bounding boxes" do
      # Create player and enemy that are close but not quite touching
      player = TestHelpers.create_test_player(x: 100, y: 100, width: 40, height: 40)
      enemy = TestHelpers.create_test_enemy(x: 135, y: 100, width: 30, height: 30)
      
      # They should be close enough to collide
      # Player box: 80-120, 80-120
      # Enemy box: 120-150, 85-115
      assert Collision.player_enemy_collision?(player, enemy)
      
      # Move enemy slightly further
      distant_enemy = %{enemy | x: 145}  # Enemy box now: 130-160, 85-115
      refute Collision.player_enemy_collision?(player, distant_enemy)
    end
  end

  describe "bullet_player_collision?/2" do
    test "detects collision when enemy bullet hits player" do
      {bullet, player} = TestHelpers.create_collision_scenario(:bullet_player)
      
      assert Collision.bullet_player_collision?(bullet, player)
    end

    test "ignores player bullets hitting player" do
      player = TestHelpers.create_test_player(x: 400, y: 300)
      player_bullet = TestHelpers.create_test_bullet(x: 400, y: 300, owner_type: :player)
      
      refute Collision.bullet_player_collision?(player_bullet, player)
    end

    test "detects no collision when enemy bullet and player are separate" do
      player = TestHelpers.create_test_player(x: 100, y: 100)
      enemy_bullet = TestHelpers.create_test_bullet(x: 700, y: 500, owner_type: :enemy)
      
      refute Collision.bullet_player_collision?(enemy_bullet, player)
    end
  end

  describe "bullet_enemy_collision?/2" do
    test "detects collision when player bullet hits enemy" do
      {bullet, enemy} = TestHelpers.create_collision_scenario(:bullet_enemy)
      
      assert Collision.bullet_enemy_collision?(bullet, enemy)
    end

    test "ignores enemy bullets hitting enemy" do
      enemy = TestHelpers.create_test_enemy(x: 400, y: 200)
      enemy_bullet = TestHelpers.create_test_bullet(x: 400, y: 200, owner_type: :enemy)
      
      refute Collision.bullet_enemy_collision?(enemy_bullet, enemy)
    end

    test "detects no collision when player bullet and enemy are separate" do
      enemy = TestHelpers.create_test_enemy(x: 100, y: 100)
      player_bullet = TestHelpers.create_test_bullet(x: 700, y: 500, owner_type: :player)
      
      refute Collision.bullet_enemy_collision?(player_bullet, enemy)
    end
  end

  describe "find_bullet_enemy_collisions/2" do
    test "finds all player bullets that hit enemies" do
      enemies = [
        TestHelpers.create_test_enemy(x: 200, y: 100, id: "enemy_1"),
        TestHelpers.create_test_enemy(x: 400, y: 150, id: "enemy_2"),
        TestHelpers.create_test_enemy(x: 600, y: 200, id: "enemy_3")
      ]
      
      bullets = [
        TestHelpers.create_test_bullet(x: 200, y: 100, owner_type: :player, id: "bullet_1"),  # Hits enemy_1
        TestHelpers.create_test_bullet(x: 400, y: 150, owner_type: :player, id: "bullet_2"),  # Hits enemy_2
        TestHelpers.create_test_bullet(x: 100, y: 50, owner_type: :player, id: "bullet_3"),   # Hits nothing
        TestHelpers.create_test_bullet(x: 600, y: 200, owner_type: :enemy, id: "bullet_4")    # Enemy bullet (ignored)
      ]
      
      collisions = Collision.find_bullet_enemy_collisions(bullets, enemies)
      
      assert length(collisions) == 2
      collision_ids = Enum.map(collisions, fn {bullet, enemy} -> {bullet.id, enemy.id} end)
      assert {"bullet_1", "enemy_1"} in collision_ids
      assert {"bullet_2", "enemy_2"} in collision_ids
    end

    test "ignores dead enemies" do
      dead_enemy = TestHelpers.create_test_enemy(x: 200, y: 100, health: 0)
      bullet = TestHelpers.create_test_bullet(x: 200, y: 100, owner_type: :player)
      
      collisions = Collision.find_bullet_enemy_collisions([bullet], [dead_enemy])
      
      assert collisions == []
    end
  end

  describe "find_bullet_player_collisions/2" do
    test "finds all enemy bullets that hit player" do
      player = TestHelpers.create_test_player(x: 400, y: 300)
      
      bullets = [
        TestHelpers.create_test_bullet(x: 400, y: 300, owner_type: :enemy, id: "bullet_1"),  # Hits player
        TestHelpers.create_test_bullet(x: 405, y: 305, owner_type: :enemy, id: "bullet_2"),  # Hits player
        TestHelpers.create_test_bullet(x: 100, y: 100, owner_type: :enemy, id: "bullet_3"),  # Misses player
        TestHelpers.create_test_bullet(x: 400, y: 300, owner_type: :player, id: "bullet_4")  # Player bullet (ignored)
      ]
      
      colliding_bullets = Collision.find_bullet_player_collisions(bullets, player)
      
      assert length(colliding_bullets) == 2
      collision_ids = Enum.map(colliding_bullets, & &1.id)
      assert "bullet_1" in collision_ids
      assert "bullet_2" in collision_ids
    end

    test "returns empty list for dead player" do
      dead_player = TestHelpers.create_test_player(x: 400, y: 300, health: 0)
      bullet = TestHelpers.create_test_bullet(x: 400, y: 300, owner_type: :enemy)
      
      colliding_bullets = Collision.find_bullet_player_collisions([bullet], dead_player)
      
      assert colliding_bullets == []
    end
  end

  describe "find_player_enemy_collisions/2" do
    test "finds all enemies colliding with player" do
      player = TestHelpers.create_test_player(x: 400, y: 300)
      
      enemies = [
        TestHelpers.create_test_enemy(x: 400, y: 300, id: "enemy_1"),  # Collides with player
        TestHelpers.create_test_enemy(x: 405, y: 305, id: "enemy_2"),  # Collides with player
        TestHelpers.create_test_enemy(x: 100, y: 100, id: "enemy_3"),  # Does not collide
        TestHelpers.create_test_enemy(x: 400, y: 300, health: 0, id: "enemy_4")  # Dead enemy
      ]
      
      colliding_enemies = Collision.find_player_enemy_collisions(enemies, player)
      
      assert length(colliding_enemies) == 2
      collision_ids = Enum.map(colliding_enemies, & &1.id)
      assert "enemy_1" in collision_ids
      assert "enemy_2" in collision_ids
      refute "enemy_4" in collision_ids  # Dead enemy should not be included
    end

    test "returns empty list for dead player" do
      dead_player = TestHelpers.create_test_player(x: 400, y: 300, health: 0)
      enemy = TestHelpers.create_test_enemy(x: 400, y: 300)
      
      colliding_enemies = Collision.find_player_enemy_collisions([enemy], dead_player)
      
      assert colliding_enemies == []
    end
  end

  describe "point_in_box?/3" do
    test "detects point inside bounding box" do
      box = {10, 10, 30, 30}  # 20x20 box
      
      assert Collision.point_in_box?(20, 20, box)  # Center
      assert Collision.point_in_box?(10, 10, box)  # Top-left corner
      assert Collision.point_in_box?(30, 30, box)  # Bottom-right corner
      assert Collision.point_in_box?(25, 15, box)  # Inside
    end

    test "detects point outside bounding box" do
      box = {10, 10, 30, 30}
      
      refute Collision.point_in_box?(5, 20, box)   # Left of box
      refute Collision.point_in_box?(35, 20, box)  # Right of box
      refute Collision.point_in_box?(20, 5, box)   # Above box
      refute Collision.point_in_box?(20, 35, box)  # Below box
    end
  end

  describe "circle_box_collision?/4" do
    test "detects collision between circle and box" do
      box = {10, 10, 30, 30}  # 20x20 box
      
      # Circle center inside box
      assert Collision.circle_box_collision?(20, 20, 5, box)
      
      # Circle overlapping box edge
      assert Collision.circle_box_collision?(35, 20, 10, box)  # Right side
      assert Collision.circle_box_collision?(20, 5, 8, box)    # Top side
    end

    test "detects no collision between separate circle and box" do
      box = {10, 10, 30, 30}
      
      # Circle too far away
      refute Collision.circle_box_collision?(50, 20, 5, box)
      refute Collision.circle_box_collision?(20, 50, 5, box)
      
      # Circle too small to reach box
      refute Collision.circle_box_collision?(35, 20, 2, box)
    end
  end

  describe "distance_between/2" do
    test "calculates correct distance between entities" do
      player = TestHelpers.create_test_player(x: 0, y: 0)
      enemy = TestHelpers.create_test_enemy(x: 3, y: 4)
      
      distance = Collision.distance_between(player, enemy)
      assert abs(distance - 5.0) < 0.001  # 3-4-5 triangle
    end

    test "calculates zero distance for same position" do
      player = TestHelpers.create_test_player(x: 100, y: 200)
      enemy = TestHelpers.create_test_enemy(x: 100, y: 200)
      
      distance = Collision.distance_between(player, enemy)
      assert abs(distance) < 0.001
    end
  end

  describe "overlap_area/2" do
    test "calculates overlap area for colliding boxes" do
      box1 = {10, 10, 30, 30}  # 20x20 box
      box2 = {20, 20, 40, 40}  # 20x20 box, overlaps by 10x10
      
      {width, height} = Collision.overlap_area(box1, box2)
      
      assert width == 10.0
      assert height == 10.0
    end

    test "returns zero area for non-colliding boxes" do
      box1 = {10, 10, 30, 30}
      box2 = {40, 40, 60, 60}
      
      {width, height} = Collision.overlap_area(box1, box2)
      
      assert width == 0.0
      assert height == 0.0
    end
  end

  describe "within_bounds?/4" do
    test "checks if entity is within screen bounds" do
      player = TestHelpers.create_test_player(x: 400, y: 300)
      
      assert Collision.within_bounds?(player, 800, 600)
      
      # Near edges but still within bounds
      edge_player = TestHelpers.create_test_player(x: 20, y: 20)
      assert Collision.within_bounds?(edge_player, 800, 600)
    end

    test "checks if entity is outside screen bounds" do
      # Outside left
      outside_player = TestHelpers.create_test_player(x: -50, y: 300)
      refute Collision.within_bounds?(outside_player, 800, 600)
      
      # Outside right
      outside_player2 = TestHelpers.create_test_player(x: 850, y: 300)
      refute Collision.within_bounds?(outside_player2, 800, 600)
    end

    test "respects margin parameter" do
      # Player just outside normal bounds
      player = TestHelpers.create_test_player(x: -10, y: 300)
      
      refute Collision.within_bounds?(player, 800, 600, 0)    # No margin
      assert Collision.within_bounds?(player, 800, 600, 50)   # 50 pixel margin
    end
  end
end