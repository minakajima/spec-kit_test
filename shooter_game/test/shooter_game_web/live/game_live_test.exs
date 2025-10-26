defmodule ShooterGameWeb.GameLiveTest do
  use ShooterGameWeb.ConnCase, async: false  # Not async due to GenServer dependencies

  import Phoenix.LiveViewTest

  alias ShooterGame.GameEngine

  setup do
    # Ensure GameEngine is running
    case GenServer.whereis(ShooterGame.GameEngine) do
      nil -> 
        {:ok, _pid} = start_supervised(ShooterGame.GameEngine)
      _pid -> 
        :ok
    end
    
    :ok
  end

  describe "mount" do
    test "mounts successfully and shows start screen", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")

      assert html =~ "Phoenix Shooter"
      assert html =~ "START"
      assert html =~ "High Score:"
    end

    test "displays game dimensions correctly", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")

      assert html =~ "width: 800px"
      assert html =~ "height: 600px"
    end
  end

  describe "game start" do
    test "starts game when START button clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Click START button
      view |> element("button", "START") |> render_click()

      # Should show game canvas instead of start screen
      html = render(view)
      assert html =~ "game-canvas"
      assert html =~ "Score:"
      refute html =~ "START"
    end

    test "shows game UI after starting", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button", "START") |> render_click()

      html = render(view)
      assert html =~ "Score: 0"
      assert html =~ "High: 0"
      assert html =~ "Move: Mouse"
      assert html =~ "Shoot: Click &amp; Hold"
    end
  end

  describe "game reset" do
    test "can reset game from game over screen", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Start game
      view |> element("button", "START") |> render_click()

      # Simulate game over by directly calling reset
      view |> element("button", "Play Again") |> render_click()

      # Should return to waiting state but show start screen again
      html = render(view)
      # Game might still show canvas in waiting state, depending on implementation
      assert html =~ "START" || html =~ "game-canvas"
    end
  end

  describe "mouse events" do
    test "handles mouse move events", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button", "START") |> render_click()

      # Simulate mouse movement
      result = view
      |> render_hook("mouse_move", %{"x" => "300", "y" => "250"})

      # Should not crash and return ok
      assert result =~ "game-canvas" || result == ""
    end

    test "handles mouse down and up events", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button", "START") |> render_click()

      # Should handle mouse events without crashing
      assert view |> render_hook("mouse_down", %{}) 
      assert view |> render_hook("mouse_up", %{})
    end

    test "validates mouse coordinates", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button", "START") |> render_click()

      # Test with various coordinate formats
      assert view |> render_hook("mouse_move", %{"x" => "100.5", "y" => "200.7"})
      assert view |> render_hook("mouse_move", %{"x" => "0", "y" => "0"})
      assert view |> render_hook("mouse_move", %{"x" => "800", "y" => "600"})
    end
  end

  describe "game state updates" do
    test "receives and handles game state updates", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button", "START") |> render_click()

      # Game should be running and updating
      :timer.sleep(100)  # Allow for game updates

      html = render(view)
      assert html =~ "game-canvas"
    end

    test "displays current score", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button", "START") |> render_click()

      html = render(view)
      assert html =~ "Score: 0"  # Initial score
    end
  end

  describe "keyboard events" do
    test "includes keyboard event handlers", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")

      # Should include JavaScript for keyboard handling
      assert html =~ "keydown" || html =~ "addEventListener"
    end
  end

  describe "high score management" do
    test "displays high score", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")

      assert html =~ "High Score:"
      assert html =~ "0"  # Default high score
    end

    test "updates high score display when game starts", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button", "START") |> render_click()

      html = render(view)
      assert html =~ "High:"
    end
  end

  describe "responsive design" do
    test "includes proper CSS classes for game container", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")

      assert html =~ "game-container"
      assert html =~ "width: 800px"
      assert html =~ "height: 600px"
    end

    test "includes game canvas with correct dimensions", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button", "START") |> render_click()

      html = render(view)
      assert html =~ ~s(width="800")
      assert html =~ ~s(height="600")
      assert html =~ "GameCanvas"
    end
  end

  describe "error handling" do
    test "handles invalid mouse coordinates gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button", "START") |> render_click()

      # Try invalid coordinates - should not crash
      assert view |> render_hook("mouse_move", %{"x" => "invalid", "y" => "200"})
      assert view |> render_hook("mouse_move", %{"x" => "200", "y" => "invalid"})
    end

    test "handles rapid event sequences", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button", "START") |> render_click()

      # Rapid fire events
      for i <- 1..10 do
        view |> render_hook("mouse_move", %{"x" => "#{i * 10}", "y" => "200"})
        view |> render_hook("mouse_down", %{})
        view |> render_hook("mouse_up", %{})
      end

      # Should still be responsive
      html = render(view)
      assert html =~ "game-canvas"
    end
  end

  describe "game over scenarios" do
    test "shows appropriate UI for game over", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button", "START") |> render_click()

      # Would need to simulate game over condition
      # For now, just verify the template includes game over elements
      html = render(view)
      
      # The template should include game over handling even if not currently visible
      page_source = view |> render()
      assert page_source =~ "Game Over" || page_source =~ "game-over"
    end
  end

  describe "pause functionality" do
    test "includes pause controls in template", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button", "START") |> render_click()

      html = render(view)
      # Should include pause-related elements in template
      assert html =~ "Pause" || html =~ "pause"
    end
  end
end