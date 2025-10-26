// 統計ダッシュボードフック
// StorageManagerから詳細データを取得して視覚化表示

const StatsDashboard = {
  mounted() {
    console.log('Stats Dashboard mounted');
    
    // StorageManager初期化
    this.storageManager = new StorageManager();
    
    // 初期データ読み込み
    this.loadDashboardData();
    
    // イベントリスナー設定
    this.setupEventListeners();
    
    // 定期更新（30秒ごと）
    this.updateInterval = setInterval(() => {
      this.loadDashboardData();
    }, 30000);
  },

  destroyed() {
    if (this.updateInterval) {
      clearInterval(this.updateInterval);
    }
  },

  loadDashboardData() {
    try {
      // 基本統計データ
      const stats = this.storageManager.getGameStatistics();
      const summary = this.storageManager.getStatsSummary();
      
      // プレイパターン分析
      const analysis = this.storageManager.getPlayPatternAnalysis();
      
      // 個人ベスト記録
      const personalBests = this.storageManager.getPersonalBests();
      
      // 最近の傾向
      const recentTrends = this.storageManager.getRecentTrends(7);
      
      // プレイ履歴
      const recentHistory = this.storageManager.getPlayHistory(10);
      
      // データ同期状況
      const syncStatus = this.storageManager.getSyncStatus ? 
        this.storageManager.getSyncStatus() : null;
      
      // UIを更新
      this.updateBasicStats(summary, stats);
      this.updateAnalysis(analysis, recentTrends);
      this.updatePersonalBests(personalBests);
      this.updateRecentHistory(recentHistory);
      this.updateRecommendations(recentTrends.recommendations);
      this.updateSyncStatus(syncStatus);
      
    } catch (error) {
      console.error('Failed to load dashboard data:', error);
      this.showErrorState();
    }
  },

  updateBasicStats(summary, stats) {
    // 基本統計カードの更新
    this.updateElement('high-score', summary.highScore.toLocaleString());
    this.updateElement('total-games', stats.totalGamesPlayed.toLocaleString());
    
    // 平均命中率計算
    const avgAccuracy = stats.totalShotsFired > 0 ? 
      ((stats.totalShotsHit / stats.totalShotsFired) * 100).toFixed(1) : '0.0';
    this.updateElement('avg-accuracy', `${avgAccuracy}%`);
    
    // 総プレイ時間フォーマット
    this.updateElement('total-playtime', this.formatTotalTime(stats.totalPlayTime));
  },

  updateAnalysis(analysis, trends) {
    // プレイスタイル
    const styleMap = {
      'strategic_survivor': '戦略的生存型',
      'precision_shooter': '精密射撃型',
      'aggressive_fighter': '積極戦闘型',
      'defensive_player': '守備的プレイヤー',
      'balanced_player': 'バランス型',
      'no_data': 'データ不足'
    };
    this.updateElement('play-style', styleMap[trends.playingStyle] || 'Unknown');
    
    // 改善傾向
    const trendMap = {
      'strong_improvement': '大幅向上',
      'moderate_improvement': '順調に向上',
      'stable': '安定',
      'declining': '低下傾向',
      'insufficient_data': 'データ不足'
    };
    this.updateElement('improvement-trend', trendMap[analysis.improvementTrend] || 'Unknown');
    
    // 一貫性スコア
    this.updateElement('consistency-score', `${Math.round(analysis.consistencyScore || 0)}/100`);
  },

  updatePersonalBests(bests) {
    this.updateElement('best-score', bests.highestScore.toLocaleString());
    this.updateElement('best-accuracy', `${bests.bestAccuracy.toFixed(1)}%`);
    this.updateElement('longest-survival', this.formatTime(bests.longestSurvival));
    this.updateElement('most-enemies', bests.mostEnemiesDefeated.toString());
  },

  updateRecentHistory(history) {
    const tbody = document.getElementById('recent-history');
    if (!tbody) return;
    
    tbody.innerHTML = '';
    
    // 最新10件を逆順で表示
    const recentSessions = history.slice(-10).reverse();
    
    recentSessions.forEach(session => {
      const row = document.createElement('tr');
      row.className = 'border-b border-gray-700 hover:bg-gray-700';
      
      const date = new Date(session.timestamp);
      const formattedDate = date.toLocaleDateString('ja-JP', {
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      });
      
      row.innerHTML = `
        <td class="py-2">${formattedDate}</td>
        <td class="py-2 text-right font-mono">${session.finalScore.toLocaleString()}</td>
        <td class="py-2 text-right">${session.accuracy.toFixed(1)}%</td>
        <td class="py-2 text-right">${this.formatTime(session.playTime)}</td>
        <td class="py-2 text-right">${session.enemiesDefeated}</td>
      `;
      
      tbody.appendChild(row);
    });
    
    if (recentSessions.length === 0) {
      tbody.innerHTML = '<tr><td colspan="5" class="py-4 text-center text-gray-400">プレイ履歴がありません</td></tr>';
    }
  },

  updateRecommendations(recommendations) {
    const container = document.getElementById('recommendations');
    if (!container) return;
    
    container.innerHTML = '';
    
    if (recommendations.length === 0) {
      container.innerHTML = '<p class="text-gray-400">素晴らしいプレイです！このまま継続してください。</p>';
      return;
    }
    
    recommendations.forEach(rec => {
      const item = document.createElement('div');
      item.className = 'flex items-start space-x-3 p-3 bg-blue-900 bg-opacity-50 rounded-lg';
      item.innerHTML = `
        <svg class="w-5 h-5 text-blue-400 mt-0.5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"/>
        </svg>
        <p class="text-sm text-gray-300">${rec}</p>
      `;
      container.appendChild(item);
    });
  },

  setupEventListeners() {
    // データエクスポート
    const exportBtn = document.getElementById('export-data');
    if (exportBtn) {
      exportBtn.addEventListener('click', () => {
        this.exportData();
      });
    }
    
    // データインポート
    const importBtn = document.getElementById('import-data');
    const importFile = document.getElementById('import-file');
    
    if (importBtn && importFile) {
      importBtn.addEventListener('click', () => {
        importFile.click();
      });
      
      importFile.addEventListener('change', (e) => {
        this.importData(e.target.files[0]);
      });
    }
    
    // データリセット
    const resetBtn = document.getElementById('reset-data');
    if (resetBtn) {
      resetBtn.addEventListener('click', () => {
        this.resetData();
      });
    }
    
    // データ同期関連ボタン
    const createBackupBtn = document.getElementById('create-backup');
    if (createBackupBtn) {
      createBackupBtn.addEventListener('click', () => {
        this.createManualBackup();
      });
    }
    
    const viewBackupsBtn = document.getElementById('view-backups');
    if (viewBackupsBtn) {
      viewBackupsBtn.addEventListener('click', () => {
        this.toggleBackupList();
      });
    }
    
    const integrityCheckBtn = document.getElementById('integrity-check');
    if (integrityCheckBtn) {
      integrityCheckBtn.addEventListener('click', () => {
        this.performIntegrityCheck();
      });
    }
  },

  exportData() {
    try {
      const data = this.storageManager.exportData();
      const blob = new Blob([data], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      
      const a = document.createElement('a');
      a.href = url;
      a.download = `shooter_game_data_${new Date().toISOString().split('T')[0]}.json`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
      
      this.showNotification('データをエクスポートしました', 'success');
    } catch (error) {
      console.error('Export failed:', error);
      this.showNotification('エクスポートに失敗しました', 'error');
    }
  },

  importData(file) {
    if (!file) return;
    
    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const success = this.storageManager.importData(e.target.result);
        if (success) {
          this.showNotification('データをインポートしました', 'success');
          this.loadDashboardData(); // データ再読み込み
        } else {
          this.showNotification('インポートに失敗しました', 'error');
        }
      } catch (error) {
        console.error('Import failed:', error);
        this.showNotification('インポートに失敗しました', 'error');
      }
    };
    reader.readAsText(file);
  },

  resetData() {
    if (confirm('全てのデータを削除しますか？この操作は取り消せません。')) {
      try {
        this.storageManager.resetAllData();
        this.showNotification('データをリセットしました', 'success');
        this.loadDashboardData(); // データ再読み込み
      } catch (error) {
        console.error('Reset failed:', error);
        this.showNotification('リセットに失敗しました', 'error');
      }
    }
  },

  // ユーティリティメソッド

  updateElement(id, value) {
    const element = document.getElementById(id);
    if (element) {
      element.textContent = value;
    }
  },

  formatTime(seconds) {
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = Math.floor(seconds % 60);
    return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`;
  },

  formatTotalTime(seconds) {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    
    if (hours > 0) {
      return `${hours}h ${minutes}m`;
    } else {
      return `${minutes}m`;
    }
  },

  showNotification(message, type = 'info') {
    // 簡単な通知表示（将来的にはより洗練された通知システムに置き換え）
    const color = type === 'success' ? 'bg-green-600' : type === 'error' ? 'bg-red-600' : 'bg-blue-600';
    
    const notification = document.createElement('div');
    notification.className = `fixed top-4 right-4 ${color} text-white px-6 py-3 rounded-lg shadow-lg z-50 transition-opacity`;
    notification.textContent = message;
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
      notification.style.opacity = '0';
      setTimeout(() => {
        document.body.removeChild(notification);
      }, 300);
    }, 3000);
  },

  showErrorState() {
    const cards = ['high-score', 'total-games', 'avg-accuracy', 'total-playtime'];
    cards.forEach(id => this.updateElement(id, 'Error'));
    
    this.showNotification('統計データの読み込みに失敗しました', 'error');
  },

  // データ同期状況の更新
  updateSyncStatus(syncStatus) {
    if (!syncStatus) return;
    
    this.updateElement('data-version', syncStatus.version);
    this.updateElement('last-updated', this.formatDateTime(syncStatus.lastUpdated));
    this.updateElement('backup-count', `${syncStatus.backupCount}/5`);
    
    const integrityElement = document.getElementById('data-integrity');
    if (integrityElement) {
      if (syncStatus.dataIntegrity) {
        integrityElement.textContent = '正常';
        integrityElement.className = 'px-2 py-1 rounded text-sm bg-green-600 text-white';
      } else {
        integrityElement.textContent = '要確認';
        integrityElement.className = 'px-2 py-1 rounded text-sm bg-red-600 text-white';
      }
    }
  },

  // 手動バックアップ作成
  createManualBackup() {
    if (this.storageManager.createBackup) {
      const backupId = this.storageManager.createBackup('manual');
      if (backupId) {
        this.showNotification(`バックアップを作成しました: ${backupId}`, 'success');
        this.loadDashboardData(); // 同期状況を更新
      } else {
        this.showNotification('バックアップの作成に失敗しました', 'error');
      }
    } else {
      this.showNotification('バックアップ機能が利用できません', 'error');
    }
  },

  // バックアップ一覧表示切り替え
  toggleBackupList() {
    const backupList = document.getElementById('backup-list');
    const backupItems = document.getElementById('backup-items');
    
    if (!backupList || !backupItems) return;
    
    if (backupList.classList.contains('hidden')) {
      // バックアップ一覧を表示
      if (this.storageManager.getBackups) {
        const backups = this.storageManager.getBackups();
        this.renderBackupList(backups, backupItems);
        backupList.classList.remove('hidden');
      }
    } else {
      backupList.classList.add('hidden');
    }
  },

  // バックアップ一覧のレンダリング
  renderBackupList(backups, container) {
    container.innerHTML = '';
    
    if (backups.length === 0) {
      container.innerHTML = '<p class="text-gray-400 text-sm">バックアップがありません</p>';
      return;
    }
    
    backups.forEach(backup => {
      const item = document.createElement('div');
      item.className = 'flex items-center justify-between p-3 bg-gray-700 rounded-lg';
      
      const date = new Date(backup.timestamp);
      const formattedDate = date.toLocaleString('ja-JP');
      const sizeKB = Math.round(backup.size / 1024);
      
      item.innerHTML = `
        <div>
          <div class="text-white font-mono text-sm">${backup.id}</div>
          <div class="text-gray-400 text-xs">${formattedDate} (${backup.reason})</div>
          <div class="text-gray-500 text-xs">${sizeKB}KB</div>
        </div>
        <button class="bg-green-600 hover:bg-green-700 px-3 py-1 rounded text-sm transition-colors" 
                onclick="statsDashboard.restoreBackup('${backup.id}')">
          復元
        </button>
      `;
      
      container.appendChild(item);
    });
  },

  // バックアップからの復元
  restoreBackup(backupId) {
    if (confirm(`バックアップ ${backupId} からデータを復元しますか？現在のデータは失われます。`)) {
      if (this.storageManager.restoreFromBackup) {
        const success = this.storageManager.restoreFromBackup(backupId);
        if (success) {
          this.showNotification('データを復元しました', 'success');
          this.loadDashboardData(); // データを再読み込み
        } else {
          this.showNotification('復元に失敗しました', 'error');
        }
      } else {
        this.showNotification('復元機能が利用できません', 'error');
      }
    }
  },

  // 整合性チェック実行
  performIntegrityCheck() {
    if (this.storageManager.performIntegrityCheck) {
      const result = this.storageManager.performIntegrityCheck();
      if (result) {
        this.showNotification('データの整合性に問題ありません', 'success');
      } else {
        this.showNotification('データの整合性に問題があります。自動修復を実行しました。', 'warning');
      }
      this.loadDashboardData(); // 同期状況を更新
    } else {
      this.showNotification('整合性チェック機能が利用できません', 'error');
    }
  },

  // 日時フォーマット
  formatDateTime(isoString) {
    if (!isoString || isoString === 'unknown') return '不明';
    
    try {
      const date = new Date(isoString);
      return date.toLocaleString('ja-JP', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      });
    } catch (error) {
      return '不明';
    }
  }
};

// グローバル参照用（バックアップ復元ボタン用）
window.statsDashboard = null;

const StatsDashboardHook = {
  ...StatsDashboard,
  
  mounted() {
    StatsDashboard.mounted.call(this);
    window.statsDashboard = this; // グローバル参照設定
  },
  
  destroyed() {
    StatsDashboard.destroyed.call(this);
    window.statsDashboard = null; // グローバル参照クリア
  }
};

export default StatsDashboardHook;