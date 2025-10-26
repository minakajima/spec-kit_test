defmodule ShooterGameWeb.HealthController do
  use ShooterGameWeb, :controller

  def check(conn, _params) do
    # Basic health check - could be expanded to check database, external services, etc.
    status = %{
      status: "ok",
      timestamp: DateTime.utc_now(),
      game_engine: game_engine_status(),
      version: Application.spec(:shooter_game, :vsn) || "unknown"
    }

    json(conn, status)
  end

  defp game_engine_status do
    case GenServer.whereis(ShooterGame.GameEngine) do
      nil -> "not_running"
      pid when is_pid(pid) -> "running"
    end
  end
end