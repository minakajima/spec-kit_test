defmodule ShooterGameWeb.StatsLive do
  @moduledoc """
  統計ダッシュボードLiveView
  プレイ履歴、実績、スコアトレンド、パフォーマンス指標の視覚化表示
  """
  use ShooterGameWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Statistics Dashboard")}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 text-white">
      <!-- ナビゲーション -->
      <nav class="bg-gray-800 border-b border-gray-700">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-16">
            <div class="flex items-center">
              <.link navigate="/" class="text-xl font-bold text-white hover:text-blue-400">
                Phoenix Shooter
              </.link>
            </div>
            <div class="flex items-center space-x-4">
              <.link navigate="/game" class="bg-blue-600 hover:bg-blue-700 px-4 py-2 rounded-lg transition-colors">
                プレイする
              </.link>
            </div>
          </div>
        </div>
      </nav>

      <!-- メインコンテンツ -->
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-white mb-2">統計ダッシュボード</h1>
          <p class="text-gray-400">あなたのプレイデータと進歩を確認できます</p>
        </div>

        <!-- 統計コンテナ -->
        <div id="stats-dashboard" phx-hook="StatsDashboard" class="space-y-8">
          <!-- 基本統計カード -->
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-sm text-gray-400">ハイスコア</p>
                  <p id="high-score" class="text-2xl font-bold text-yellow-400">-</p>
                </div>
                <div class="p-2 bg-yellow-500 bg-opacity-20 rounded-lg">
                  <svg class="w-6 h-6 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
                  </svg>
                </div>
              </div>
            </div>

            <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-sm text-gray-400">総プレイ数</p>
                  <p id="total-games" class="text-2xl font-bold text-blue-400">-</p>
                </div>
                <div class="p-2 bg-blue-500 bg-opacity-20 rounded-lg">
                  <svg class="w-6 h-6 text-blue-400" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M13 6a3 3 0 11-6 0 3 3 0 016 0zM18 8a2 2 0 11-4 0 2 2 0 014 0zM14 15a4 4 0 00-8 0v3h8v-3z"/>
                  </svg>
                </div>
              </div>
            </div>

            <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-sm text-gray-400">平均命中率</p>
                  <p id="avg-accuracy" class="text-2xl font-bold text-green-400">-</p>
                </div>
                <div class="p-2 bg-green-500 bg-opacity-20 rounded-lg">
                  <svg class="w-6 h-6 text-green-400" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
                  </svg>
                </div>
              </div>
            </div>

            <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-sm text-gray-400">総プレイ時間</p>
                  <p id="total-playtime" class="text-2xl font-bold text-purple-400">-</p>
                </div>
                <div class="p-2 bg-purple-500 bg-opacity-20 rounded-lg">
                  <svg class="w-6 h-6 text-purple-400" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clip-rule="evenodd"/>
                  </svg>
                </div>
              </div>
            </div>
          </div>

          <!-- パフォーマンス分析 -->
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
            <!-- プレイスタイル分析 -->
            <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
              <h2 class="text-xl font-bold text-white mb-4">プレイスタイル分析</h2>
              <div id="play-style-analysis" class="space-y-4">
                <div class="flex items-center justify-between">
                  <span class="text-gray-400">現在のスタイル</span>
                  <span id="play-style" class="px-3 py-1 bg-blue-600 text-white rounded-full text-sm">-</span>
                </div>
                <div class="flex items-center justify-between">
                  <span class="text-gray-400">改善傾向</span>
                  <span id="improvement-trend" class="px-3 py-1 bg-green-600 text-white rounded-full text-sm">-</span>
                </div>
                <div class="flex items-center justify-between">
                  <span class="text-gray-400">一貫性スコア</span>
                  <span id="consistency-score" class="text-white font-bold">-</span>
                </div>
              </div>
            </div>

            <!-- 個人ベスト -->
            <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
              <h2 class="text-xl font-bold text-white mb-4">個人ベスト記録</h2>
              <div id="personal-bests" class="space-y-3">
                <div class="flex items-center justify-between">
                  <span class="text-gray-400">最高スコア</span>
                  <span id="best-score" class="text-yellow-400 font-bold">-</span>
                </div>
                <div class="flex items-center justify-between">
                  <span class="text-gray-400">最高命中率</span>
                  <span id="best-accuracy" class="text-green-400 font-bold">-</span>
                </div>
                <div class="flex items-center justify-between">
                  <span class="text-gray-400">最長生存時間</span>
                  <span id="longest-survival" class="text-blue-400 font-bold">-</span>
                </div>
                <div class="flex items-center justify-between">
                  <span class="text-gray-400">最多撃破数</span>
                  <span id="most-enemies" class="text-red-400 font-bold">-</span>
                </div>
              </div>
            </div>
          </div>

          <!-- 最近のプレイ履歴 -->
          <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
            <h2 class="text-xl font-bold text-white mb-4">最近のプレイ履歴</h2>
            <div class="overflow-x-auto">
              <table class="w-full text-sm">
                <thead>
                  <tr class="border-b border-gray-700">
                    <th class="text-left py-2 text-gray-400">日時</th>
                    <th class="text-right py-2 text-gray-400">スコア</th>
                    <th class="text-right py-2 text-gray-400">命中率</th>
                    <th class="text-right py-2 text-gray-400">生存時間</th>
                    <th class="text-right py-2 text-gray-400">撃破数</th>
                  </tr>
                </thead>
                <tbody id="recent-history" class="text-white">
                  <!-- JavaScriptで動的に生成 -->
                </tbody>
              </table>
            </div>
          </div>

          <!-- レコメンデーション -->
          <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
            <h2 class="text-xl font-bold text-white mb-4">改善アドバイス</h2>
            <div id="recommendations" class="space-y-2">
              <!-- JavaScriptで動的に生成 -->
            </div>
          </div>

          <!-- データ同期状況 -->
          <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
            <h2 class="text-xl font-bold text-white mb-4">データ同期状況</h2>
            <div id="sync-status" class="space-y-3">
              <div class="flex items-center justify-between">
                <span class="text-gray-400">データバージョン</span>
                <span id="data-version" class="text-white font-mono">-</span>
              </div>
              <div class="flex items-center justify-between">
                <span class="text-gray-400">最終更新</span>
                <span id="last-updated" class="text-white text-sm">-</span>
              </div>
              <div class="flex items-center justify-between">
                <span class="text-gray-400">バックアップ数</span>
                <span id="backup-count" class="text-white">-</span>
              </div>
              <div class="flex items-center justify-between">
                <span class="text-gray-400">データ整合性</span>
                <span id="data-integrity" class="px-2 py-1 rounded text-sm">-</span>
              </div>
            </div>
          </div>

          <!-- バックアップ管理 -->
          <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
            <h2 class="text-xl font-bold text-white mb-4">バックアップ管理</h2>
            <div class="space-y-4">
              <div class="flex flex-wrap gap-3">
                <button id="create-backup" class="bg-purple-600 hover:bg-purple-700 px-4 py-2 rounded-lg transition-colors">
                  手動バックアップ作成
                </button>
                <button id="view-backups" class="bg-indigo-600 hover:bg-indigo-700 px-4 py-2 rounded-lg transition-colors">
                  バックアップ一覧表示
                </button>
              </div>
              <div id="backup-list" class="hidden">
                <h3 class="text-lg font-semibold text-white mb-2">利用可能なバックアップ</h3>
                <div id="backup-items" class="space-y-2 max-h-48 overflow-y-auto">
                  <!-- JavaScriptで動的生成 -->
                </div>
              </div>
            </div>
          </div>

          <!-- データ管理 -->
          <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
            <h2 class="text-xl font-bold text-white mb-4">データ管理</h2>
            <div class="flex flex-wrap gap-4">
              <button id="export-data" class="bg-blue-600 hover:bg-blue-700 px-4 py-2 rounded-lg transition-colors">
                データエクスポート
              </button>
              <button id="import-data" class="bg-green-600 hover:bg-green-700 px-4 py-2 rounded-lg transition-colors">
                データインポート
              </button>
              <button id="integrity-check" class="bg-yellow-600 hover:bg-yellow-700 px-4 py-2 rounded-lg transition-colors">
                整合性チェック
              </button>
              <button id="reset-data" class="bg-red-600 hover:bg-red-700 px-4 py-2 rounded-lg transition-colors">
                データリセット
              </button>
            </div>
            <input type="file" id="import-file" accept=".json" class="hidden">
          </div>
        </div>
      </div>
    </div>
    """
  end
end