defmodule ShooterGameWeb.GameLive do
  @moduledoc """
  Phoenix LiveView for the main game interface.
  Handles real-time game rendering and user interactions.
  """

  use ShooterGameWeb, :live_view
  
  alias ShooterGame.GameEngine
  alias ShooterGame.Game.GameState

  @game_width 800
  @game_height 600

  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to game state updates
      GameEngine.subscribe()
    end

    socket = 
      socket
      |> assign(:game_state, nil)
      |> assign(:game_width, @game_width)
      |> assign(:game_height, @game_height)
      |> assign(:high_score, get_high_score())
      |> assign(:page_title, "Shooter Game")

    {:ok, socket}
  end

  def handle_event("start_game", _params, socket) do
    GameEngine.start_game()
    {:noreply, socket}
  end

  def handle_event("reset_game", _params, socket) do
    GameEngine.reset_game()
    {:noreply, socket}
  end

  def handle_event("mouse_move", %{"x" => x, "y" => y}, socket) do
    # Convert string coordinates to numbers
    {x_num, ""} = Float.parse(x)
    {y_num, ""} = Float.parse(y)
    
    GameEngine.update_player_position(x_num, y_num)
    {:noreply, socket}
  end

  def handle_event("mouse_down", _params, socket) do
    GameEngine.set_player_firing(true)
    {:noreply, socket}
  end

  def handle_event("mouse_up", _params, socket) do
    GameEngine.set_player_firing(false)
    {:noreply, socket}
  end

  def handle_event("toggle_pause", _params, socket) do
    if socket.assigns.game_state do
      new_paused = socket.assigns.game_state.status != :paused
      GameEngine.set_paused(new_paused)
    end
    {:noreply, socket}
  end

  def handle_event("return_to_menu", _params, socket) do
    GameEngine.reset_game()
    {:noreply, assign(socket, :game_state, nil)}
  end

  def handle_info({:game_state_update, game_state}, socket) do
    # Update high score if current score is higher
    new_high_score = if game_state && game_state.score > socket.assigns.high_score do
      save_high_score(game_state.score)
      game_state.score
    else
      socket.assigns.high_score
    end

    socket = 
      socket
      |> assign(:game_state, game_state)
      |> assign(:high_score, new_high_score)
      |> push_event("game_state_update", %{game_state: game_state})

    {:noreply, socket}
  end

  # Helper functions for rendering

  defp format_score(score) do
    score
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end

  defp format_time(milliseconds) when is_integer(milliseconds) do
    seconds = div(milliseconds, 1000)
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    
    "#{String.pad_leading(Integer.to_string(minutes), 2, "0")}:#{String.pad_leading(Integer.to_string(remaining_seconds), 2, "0")}"
  end

  defp format_time(_), do: "00:00"

  defp enemy_count(%{enemies: enemies}), do: length(enemies)
  defp enemy_count(_), do: 0

  defp bullet_count(%{bullets: bullets}), do: length(bullets)
  defp bullet_count(_), do: 0

  defp game_duration(%{start_time: start_time, end_time: end_time}) when start_time > 0 and end_time > 0 do
    end_time - start_time
  end

  defp game_duration(%{start_time: start_time}) when start_time > 0 do
    :erlang.monotonic_time(:millisecond) - start_time
  end

  defp game_duration(_), do: 0

  defp calculate_enemies_defeated(game_state) do
    # This would be tracked in actual game state, for now calculate roughly from score
    div(game_state.score, 10)  # Assuming 10 points per enemy
  end

  def render(assigns) do
    ~H"""
    <div class="game-container" 
         style={"width: #{@game_width}px; height: #{@game_height}px;"}
         role="application"
         aria-label="Phoenix Shooter Game"
         tabindex="0">
      <%= if @game_state == nil or @game_state.status == :waiting do %>
        <div class="start-screen" role="main">
          <div class="start-screen-content">
            <div class="game-title">
              <h1 class="title-main" id="game-title">Phoenix Shooter</h1>
              <div class="title-subtitle">Vertical Scrolling Action</div>
            </div>
            
            <div class="game-instructions" 
                 role="list" 
                 aria-labelledby="instructions-heading">
              <h2 id="instructions-heading" class="sr-only">ゲームの操作方法</h2>
              <div class="instruction-item" role="listitem">
                <div class="instruction-icon" aria-hidden="true">🖱️</div>
                <div class="instruction-text">Mouse to move your ship</div>
              </div>
              <div class="instruction-item" role="listitem">
                <div class="instruction-icon" aria-hidden="true">🔫</div>
                <div class="instruction-text">Click & hold to shoot</div>
              </div>
              <div class="instruction-item" role="listitem">
                <div class="instruction-icon" aria-hidden="true">⏸️</div>
                <div class="instruction-text">Press P to pause</div>
              </div>
            </div>
            
            <div class="high-score-display" 
                 role="region" 
                 aria-labelledby="high-score-heading">
              <div class="high-score-label" id="high-score-heading">High Score</div>
              <div class="high-score-value" 
                   aria-describedby="high-score-heading"><%= @high_score %></div>
            </div>
            
            <button phx-click="start_game" 
                    class="start-button"
                    aria-describedby="game-title"
                    autofocus>
              <span class="start-button-text">START GAME</span>
              <div class="start-button-hint">Press to begin</div>
            </button>
          </div>
          
          <div class="start-screen-background" aria-hidden="true">
            <div class="stars-layer"></div>
            <div class="nebula-layer"></div>
          </div>
        </div>
      <% else %>
        <div class="game-area" role="main">
          <!-- Game Canvas -->
          <canvas 
            id="game-canvas" 
            width={@game_width} 
            height={@game_height}
            phx-hook="GameCanvas"
            phx-update="ignore"
            data-game-state={Jason.encode!(@game_state)}
            class="game-canvas"
            role="img"
            aria-label="ゲーム画面"
            aria-describedby="game-status"
          ></canvas>
          
          <!-- Screen Reader Game Status -->
          <div id="game-status" class="sr-only" aria-live="polite" aria-atomic="true">
            <%= cond do %>
              <% @game_state.status == :playing -> %>
                ゲームプレイ中。スコア: <%= @game_state.score %>。
                プレイヤー体力: <%= @game_state.player.health %>/<%= @game_state.player.max_health %>。
              <% @game_state.status == :paused -> %>
                ゲーム一時停止中。
              <% @game_state.status == :game_over -> %>
                ゲーム終了。最終スコア: <%= @game_state.score %>。
              <% true -> %>
                ゲーム準備中。
            <% end %>
          </div>
          
          <!-- Game UI Overlay -->
          <div class="game-ui-overlay">
            <!-- Top UI Bar -->
            <div class="top-ui-bar">
              <div class="score-section">
                <div class="current-score">
                  <div class="score-label">SCORE</div>
                  <div class="score-value"><%= format_score(@game_state.score) %></div>
                </div>
                <div class="high-score">
                  <div class="high-score-label">HIGH</div>
                  <div class="high-score-value"><%= format_score(@high_score) %></div>
                </div>
              </div>
              
              <div class="game-stats">
                <div class="stat-item">
                  <div class="stat-icon">👾</div>
                  <div class="stat-value"><%= enemy_count(@game_state) %></div>
                </div>
                <div class="stat-item">
                  <div class="stat-icon">💥</div>
                  <div class="stat-value"><%= bullet_count(@game_state) %></div>
                </div>
                <div class="stat-item">
                  <div class="stat-icon">⏱️</div>
                  <div class="stat-value"><%= format_time(game_duration(@game_state)) %></div>
                </div>
              </div>
              
              <div class="controls-section">
                <button phx-click="toggle_pause" 
                        class="pause-button" 
                        title="Pause (P)"
                        aria-label={if @game_state.status == :paused, do: "Resume game", else: "Pause game"}
                        aria-pressed={@game_state.status == :paused}>
                  <%= if @game_state.status == :paused do %>⏵<% else %>⏸️<% end %>
                </button>
                <button phx-click="reset_game" 
                        class="reset-button" 
                        title="Reset Game"
                        aria-label="Reset game">🔄</button>
              </div>
            </div>
            
            <!-- Player Health Bar -->
            <%= if @game_state.player && @game_state.player.health > 0 do %>
              <div class="health-bar-container">
                <div class="health-bar">
                  <div class="health-fill" style={"width: #{@game_state.player.health * 100}%"}></div>
                </div>
                <div class="health-text">SHIELD</div>
              </div>
            <% end %>
            
            <!-- Game Over Screen -->
            <%= if @game_state.status == :game_over do %>
              <div class="game-over-overlay" role="dialog" aria-labelledby="game-over-title">
                <div class="game-over-content">
                  <h2 class="game-over-title" id="game-over-title">GAME OVER</h2>
                  
                  <div class="final-stats" role="region" aria-labelledby="final-stats-heading">
                    <h3 id="final-stats-heading" class="sr-only">最終結果</h3>
                    <div class="final-score">
                      <div class="final-score-label">Final Score</div>
                      <div class="final-score-value" 
                           aria-label="最終スコア"><%= format_score(@game_state.score) %></div>
                    </div>
                    
                    <%= if @game_state.score == @high_score && @high_score > 0 do %>
                      <div class="new-high-score" 
                           role="alert" 
                           aria-live="assertive">
                        <div class="new-high-score-text">🏆 NEW HIGH SCORE! 🏆</div>
                        <div class="celebration-effect" aria-hidden="true"></div>
                      </div>
                    <% end %>
                    
                    <div class="game-stats-final">
                      <div class="stat-final">
                        <span class="stat-label">Time Survived:</span>
                        <span class="stat-value"><%= format_time(game_duration(@game_state)) %></span>
                      </div>
                      <div class="stat-final">
                        <span class="stat-label">Enemies Defeated:</span>
                        <span class="stat-value"><%= calculate_enemies_defeated(@game_state) %></span>
                      </div>
                    </div>
                  </div>
                  
                  <div class="game-over-actions">
                    <button phx-click="reset_game" 
                            class="play-again-button"
                            autofocus
                            aria-describedby="game-over-title">
                      <span>Play Again</span>
                      <div class="button-glow" aria-hidden="true"></div>
                    </button>
                    <button phx-click="return_to_menu" 
                            class="menu-button"
                            aria-label="Return to main menu">Main Menu</button>
                  </div>
                </div>
                
                <div class="game-over-background">
                  <div class="explosion-effect"></div>
                </div>
              </div>
            <% end %>
            
            <!-- Pause Screen -->
            <%= if @game_state.status == :paused do %>
              <div class="pause-overlay">
                <div class="pause-content">
                  <h2 class="pause-title">PAUSED</h2>
                  
                  <div class="pause-stats">
                    <div>Score: <%= format_score(@game_state.score) %></div>
                    <div>Time: <%= format_time(game_duration(@game_state)) %></div>
                  </div>
                  
                  <div class="pause-actions">
                    <button phx-click="toggle_pause" class="resume-button">
                      <span>Resume</span>
                      <div class="resume-hint">Press P or click to continue</div>
                    </button>
                    <button phx-click="reset_game" class="restart-from-pause">Restart</button>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
        
        <!-- Bottom Controls Help -->
        <div class="controls-help">
          <div class="control-group">
            <div class="control-item">
              <span class="control-key">Mouse</span>
              <span class="control-desc">Move Ship</span>
            </div>
            <div class="control-item">
              <span class="control-key">Click</span>
              <span class="control-desc">Shoot</span>
            </div>
            <div class="control-item">
              <span class="control-key">P</span>
              <span class="control-desc">Pause</span>
            </div>
          </div>
        </div>
      <% end %>
    </div>

    <script>
      // Keyboard controls
      document.addEventListener('keydown', function(e) {
        if (e.key === 'p' || e.key === 'P') {
          // Toggle pause
          window.dispatchEvent(new CustomEvent('phx:toggle_pause', {}));
        }
      });

      // Prevent context menu on canvas
      document.addEventListener('DOMContentLoaded', function() {
        const canvas = document.getElementById('game-canvas');
        if (canvas) {
          canvas.addEventListener('contextmenu', function(e) {
            e.preventDefault();
          });
        }
      });
    </script>
    """
  end

  # Private functions for high score management using LocalStorage (via JavaScript)

  defp get_high_score do
    # Default high score - will be updated by JavaScript hook
    0
  end

  defp save_high_score(score) do
    # High score saving will be handled by JavaScript hook
    # This is just a placeholder for the Elixir side
    score
  end
end