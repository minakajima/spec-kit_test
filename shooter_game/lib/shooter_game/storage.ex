defmodule ShooterGame.Storage do
  @moduledoc """
  LocalStorage統合モジュール
  ハイスコア、ゲーム統計、プレイ履歴の永続化を管理
  """

  # データスキーマ定義
  @high_score_key "shooter_game_high_score"
  @game_stats_key "shooter_game_statistics" 
  @play_history_key "shooter_game_play_history"
  @settings_key "shooter_game_settings"

  @doc """
  ゲーム終了時のスコアデータ処理
  ハイスコア更新、統計更新、プレイ履歴追加
  """
  def process_game_end(game_state, session_data) do
    final_score = calculate_final_score(game_state)
    
    # 各種データ更新処理
    high_score_updated = update_high_score(final_score)
    stats_updated = update_game_statistics(game_state, session_data)
    history_added = add_play_session(game_state, session_data, final_score)
    
    %{
      final_score: final_score,
      high_score_updated: high_score_updated,
      new_high_score: high_score_updated,
      session_id: generate_session_id(),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  @doc """
  最終スコア計算（ボーナス込み）
  """
  def calculate_final_score(game_state) do
    base_score = game_state.score
    
    # 時間ボーナス（長時間プレイ報酬）
    play_time_seconds = game_state.play_time || 0
    time_bonus = min(play_time_seconds * 2, 1000)
    
    # 撃破ボーナス
    enemies_defeated = get_in(game_state, [:statistics, :enemies_defeated]) || 0
    defeat_bonus = enemies_defeated * 50
    
    # 命中率ボーナス
    shots_fired = get_in(game_state, [:statistics, :shots_fired]) || 1
    shots_hit = get_in(game_state, [:statistics, :shots_hit]) || 0
    accuracy = shots_hit / max(shots_fired, 1)
    accuracy_bonus = trunc(accuracy * 500)
    
    base_score + time_bonus + defeat_bonus + accuracy_bonus
  end

  @doc """
  ハイスコア更新処理
  """
  def update_high_score(new_score) do
    # JavaScript側でLocalStorage処理を実行
    # 戻り値: 新記録かどうかのブール値
    # この実装では常にtrueを返し、実際の処理はJavaScript側で行う
    true
  end

  @doc """
  ゲーム統計データ更新
  """
  def update_game_statistics(game_state, session_data) do
    current_stats = %{
      total_games_played: 1,
      total_score: game_state.score,
      total_play_time: game_state.play_time || 0,
      total_enemies_defeated: get_in(game_state, [:statistics, :enemies_defeated]) || 0,
      total_shots_fired: get_in(game_state, [:statistics, :shots_fired]) || 0,
      total_shots_hit: get_in(game_state, [:statistics, :shots_hit]) || 0,
      total_damage_taken: get_in(game_state, [:statistics, :damage_taken]) || 0,
      best_accuracy: 0.0,
      longest_survival_time: game_state.play_time || 0,
      updated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    # JavaScript側で累積統計を更新
    current_stats
  end

  @doc """
  プレイセッション履歴追加
  """
  def add_play_session(game_state, session_data, final_score) do
    session = %{
      session_id: generate_session_id(),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      final_score: final_score,
      base_score: game_state.score,
      play_time: game_state.play_time || 0,
      enemies_defeated: get_in(game_state, [:statistics, :enemies_defeated]) || 0,
      shots_fired: get_in(game_state, [:statistics, :shots_fired]) || 0,
      shots_hit: get_in(game_state, [:statistics, :shots_hit]) || 0,
      damage_taken: get_in(game_state, [:statistics, :damage_taken]) || 0,
      accuracy: calculate_accuracy(game_state),
      cause_of_death: determine_death_cause(game_state),
      difficulty_level: "normal" # 将来の難易度システム用
    }
    
    session
  end

  @doc """
  命中率計算
  """
  def calculate_accuracy(game_state) do
    shots_fired = get_in(game_state, [:statistics, :shots_fired]) || 0
    shots_hit = get_in(game_state, [:statistics, :shots_hit]) || 0
    
    if shots_fired > 0 do
      (shots_hit / shots_fired * 100) |> Float.round(2)
    else
      0.0
    end
  end

  @doc """
  死因判定
  """
  def determine_death_cause(game_state) do
    cond do
      game_state.player.health <= 0 -> "enemy_fire"
      true -> "unknown"
    end
  end

  # プライベート関数

  defp generate_session_id do
    :crypto.strong_rand_bytes(8)
    |> Base.encode64()
    |> String.replace(["+", "/", "="], "")
    |> String.slice(0, 12)
  end
end