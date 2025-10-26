// LocalStorage統合管理クラス
// ハイスコア、統計データ、プレイ履歴の永続化を担当

class StorageManager {
  constructor() {
    // LocalStorageキー定義
    this.keys = {
      highScore: 'shooter_game_high_score',
      gameStats: 'shooter_game_statistics',
      playHistory: 'shooter_game_play_history',
      settings: 'shooter_game_settings',
      metadata: 'shooter_game_metadata',
      backups: 'shooter_game_backups'
    };
    
    // デフォルトデータ構造
    this.defaults = {
      highScore: 0,
      gameStats: {
        totalGamesPlayed: 0,
        totalScore: 0,
        totalPlayTime: 0,
        totalEnemiesDefeated: 0,
        totalShotsFired: 0,
        totalShotsHit: 0,
        totalDamageTaken: 0,
        bestAccuracy: 0.0,
        longestSurvivalTime: 0,
        updatedAt: new Date().toISOString()
      },
      playHistory: [],
      },
      settings: {
        soundEnabled: true,
        musicEnabled: true,
        difficulty: 'normal',
        controlScheme: 'mouse'
      },
      metadata: {
        version: '1.0.0',
        created: new Date().toISOString(),
        lastUpdated: new Date().toISOString(),
        dataIntegrity: true,
        totalSessions: 0,
        lastBackup: null
      },
      backups: []
    };

    // データ同期設定
    this.syncConfig = {
      version: '1.0.0',
      autoBackupInterval: 10, // 10セッション毎
      maxBackups: 5,
      integrityCheckInterval: 1000 * 60 * 5, // 5分毎
      migrationSupported: ['0.9.0', '1.0.0']
    };
    };
    
    this.initializeStorage();
    this.startDataSync();
  }

  // 初期化処理
  initializeStorage() {
    // 各データキーが存在しない場合、デフォルト値で初期化
    Object.keys(this.defaults).forEach(key => {
      if (!this.hasData(this.keys[key])) {
        this.setData(this.keys[key], this.defaults[key]);
      }
    });
  }

  // データ存在チェック
  hasData(key) {
    return localStorage.getItem(key) !== null;
  }

  // データ取得（JSON自動パース）
  getData(key) {
    try {
      const data = localStorage.getItem(key);
      return data ? JSON.parse(data) : null;
    } catch (error) {
      console.warn(`Failed to parse data for key "${key}":`, error);
      return null;
    }
  }

  // データ保存（JSON自動stringify）
  setData(key, value) {
    try {
      localStorage.setItem(key, JSON.stringify(value));
      return true;
    } catch (error) {
      console.error(`Failed to save data for key "${key}":`, error);
      return false;
    }
  }

  // ハイスコア取得
  getHighScore() {
    return this.getData(this.keys.highScore) || 0;
  }

  // ハイスコア更新（新記録の場合のみ）
  updateHighScore(newScore) {
    const currentHighScore = this.getHighScore();
    if (newScore > currentHighScore) {
      this.setData(this.keys.highScore, newScore);
      return true; // 新記録
    }
    return false; // 既存記録以下
  }

  // ゲーム統計取得
  getGameStatistics() {
    return this.getData(this.keys.gameStats) || this.defaults.gameStats;
  }

  // ゲーム統計更新（累積）
  updateGameStatistics(sessionData) {
    const currentStats = this.getGameStatistics();
    
    // 累積統計の更新
    const updatedStats = {
      totalGamesPlayed: currentStats.totalGamesPlayed + 1,
      totalScore: currentStats.totalScore + sessionData.finalScore,
      totalPlayTime: currentStats.totalPlayTime + (sessionData.playTime || 0),
      totalEnemiesDefeated: currentStats.totalEnemiesDefeated + (sessionData.enemiesDefeated || 0),
      totalShotsFired: currentStats.totalShotsFired + (sessionData.shotsFired || 0),
      totalShotsHit: currentStats.totalShotsHit + (sessionData.shotsHit || 0),
      totalDamageTaken: currentStats.totalDamageTaken + (sessionData.damageTaken || 0),
      bestAccuracy: Math.max(currentStats.bestAccuracy, sessionData.accuracy || 0),
      longestSurvivalTime: Math.max(currentStats.longestSurvivalTime, sessionData.playTime || 0),
      updatedAt: new Date().toISOString()
    };
    
    this.setData(this.keys.gameStats, updatedStats);
    return updatedStats;
  }

  // プレイ履歴取得（最新N件）
  getPlayHistory(limit = 50) {
    const history = this.getData(this.keys.playHistory) || [];
    return limit ? history.slice(-limit) : history;
  }

  // プレイセッション追加
  addPlaySession(sessionData) {
    const history = this.getPlayHistory();
    
    // 新セッション作成
    const session = {
      sessionId: this.generateSessionId(),
      timestamp: new Date().toISOString(),
      finalScore: sessionData.finalScore,
      baseScore: sessionData.baseScore,
      playTime: sessionData.playTime || 0,
      enemiesDefeated: sessionData.enemiesDefeated || 0,
      shotsFired: sessionData.shotsFired || 0,
      shotsHit: sessionData.shotsHit || 0,
      damageTaken: sessionData.damageTaken || 0,
      accuracy: sessionData.accuracy || 0.0,
      causeOfDeath: sessionData.causeOfDeath || 'unknown',
      difficultyLevel: sessionData.difficultyLevel || 'normal'
    };
    
    // 履歴に追加（最大100件保持）
    history.push(session);
    if (history.length > 100) {
      history.shift(); // 古い記録を削除
    }
    
    this.setData(this.keys.playHistory, history);
    return session;
  }

  // ゲーム終了時の総合処理
  processGameEnd(gameState) {
    // セッションデータ作成
    const sessionData = this.createSessionData(gameState);
    
    // ハイスコア更新チェック
    const isNewHighScore = this.updateHighScore(sessionData.finalScore);
    
    // 統計データ更新
    const updatedStats = this.updateGameStatistics(sessionData);
    
    // プレイ履歴追加
    const sessionRecord = this.addPlaySession(sessionData);
    
    return {
      sessionData,
      isNewHighScore,
      updatedStats,
      sessionRecord,
      highScore: this.getHighScore()
    };
  }

  // セッションデータ作成
  createSessionData(gameState) {
    const statistics = gameState.statistics || {};
    
    // 最終スコア計算（ボーナス込み）
    const finalScore = this.calculateFinalScore(gameState);
    
    return {
      finalScore: finalScore,
      baseScore: gameState.score || 0,
      playTime: gameState.playTime || 0,
      enemiesDefeated: statistics.enemiesDefeated || 0,
      shotsFired: statistics.shotsFired || 0,
      shotsHit: statistics.shotsHit || 0,
      damageTaken: statistics.damageTaken || 0,
      accuracy: this.calculateAccuracy(statistics),
      causeOfDeath: this.determineCauseOfDeath(gameState),
      difficultyLevel: 'normal'
    };
  }

  // 最終スコア計算
  calculateFinalScore(gameState) {
    const baseScore = gameState.score || 0;
    const statistics = gameState.statistics || {};
    
    // 時間ボーナス（最大1000点）
    const playTimeSeconds = gameState.playTime || 0;
    const timeBonus = Math.min(playTimeSeconds * 2, 1000);
    
    // 撃破ボーナス
    const enemiesDefeated = statistics.enemiesDefeated || 0;
    const defeatBonus = enemiesDefeated * 50;
    
    // 命中率ボーナス（最大500点）
    const accuracy = this.calculateAccuracy(statistics);
    const accuracyBonus = Math.floor(accuracy / 100 * 500);
    
    return baseScore + timeBonus + defeatBonus + accuracyBonus;
  }

  // 命中率計算
  calculateAccuracy(statistics) {
    const shotsFired = statistics.shotsFired || 0;
    const shotsHit = statistics.shotsHit || 0;
    
    if (shotsFired > 0) {
      return Math.round((shotsHit / shotsFired) * 100 * 100) / 100; // 小数点2桁
    }
    return 0.0;
  }

  // 死因判定
  determineCauseOfDeath(gameState) {
    if (gameState.player && gameState.player.health <= 0) {
      return 'enemy_fire';
    }
    return 'unknown';
  }

  // セッションID生成
  generateSessionId() {
    return Math.random().toString(36).substring(2, 14) + Date.now().toString(36);
  }

  // 統計サマリー取得
  getStatsSummary() {
    const stats = this.getGameStatistics();
    const history = this.getPlayHistory(10);
    
    return {
      totalGames: stats.totalGamesPlayed,
      averageScore: stats.totalGamesPlayed > 0 ? Math.round(stats.totalScore / stats.totalGamesPlayed) : 0,
      totalPlayTime: this.formatPlayTime(stats.totalPlayTime),
      bestAccuracy: stats.bestAccuracy,
      longestSurvival: this.formatPlayTime(stats.longestSurvivalTime),
      recentScores: history.map(session => session.finalScore).slice(-5),
      highScore: this.getHighScore()
    };
  }

  // 詳細プレイパターン分析
  getPlayPatternAnalysis() {
    const history = this.getPlayHistory();
    if (history.length === 0) return this.getEmptyAnalysis();

    const analysis = {
      // 基本統計
      totalSessions: history.length,
      averageSessionLength: this.calculateAverageSessionLength(history),
      improvementTrend: this.calculateImprovementTrend(history),
      
      // パフォーマンス分析
      bestPerformance: this.getBestPerformanceSession(history),
      consistencyScore: this.calculateConsistencyScore(history),
      difficultyProgression: this.analyzeDifficultyProgression(history),
      
      // プレイ頻度分析
      playFrequency: this.analyzePlayFrequency(history),
      streakAnalysis: this.analyzePlayStreaks(history),
      
      // スキル分析
      accuracyTrend: this.analyzeAccuracyTrend(history),
      survivalImprovement: this.analyzeSurvivalImprovement(history),
      scoreDistribution: this.analyzeScoreDistribution(history)
    };

    return analysis;
  }

  // 個人ベスト記録管理
  getPersonalBests() {
    const history = this.getPlayHistory();
    if (history.length === 0) return this.getEmptyPersonalBests();

    return {
      // スコア関連
      highestScore: Math.max(...history.map(s => s.finalScore)),
      highestBaseScore: Math.max(...history.map(s => s.baseScore)),
      bestAccuracy: Math.max(...history.map(s => s.accuracy)),
      
      // 生存時間関連
      longestSurvival: Math.max(...history.map(s => s.playTime)),
      shortestVictory: this.getShortestVictoryTime(history),
      
      // 戦闘関連
      mostEnemiesDefeated: Math.max(...history.map(s => s.enemiesDefeated)),
      bestEfficiency: this.calculateBestEfficiency(history), // スコア/時間
      leastDamageRun: Math.min(...history.map(s => s.damageTaken)),
      
      // 達成日時
      achievementDates: this.getAchievementDates(history),
      
      // 連続記録
      longestStreak: this.getLongestImprovementStreak(history),
      bestSession: this.getBestOverallSession(history)
    };
  }

  // 最近のプレイ傾向分析
  getRecentTrends(days = 7) {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - days);
    
    const recentHistory = this.getPlayHistory().filter(session => 
      new Date(session.timestamp) >= cutoffDate
    );

    if (recentHistory.length === 0) return this.getEmptyTrends();

    return {
      period: `${days}日間`,
      sessionCount: recentHistory.length,
      averageScore: this.calculateAverage(recentHistory, 'finalScore'),
      averageAccuracy: this.calculateAverage(recentHistory, 'accuracy'),
      averageSurvival: this.calculateAverage(recentHistory, 'playTime'),
      improvement: this.calculateRecentImprovement(recentHistory),
      playingStyle: this.analyzePlayingStyle(recentHistory),
      recommendations: this.generateRecommendations(recentHistory)
    };
  }

  // プライベートメソッド - 分析用ヘルパー関数

  getEmptyAnalysis() {
    return {
      totalSessions: 0,
      averageSessionLength: 0,
      improvementTrend: 'insufficient_data',
      bestPerformance: null,
      consistencyScore: 0,
      playFrequency: 'no_data',
      accuracyTrend: 'no_data',
      scoreDistribution: []
    };
  }

  getEmptyPersonalBests() {
    return {
      highestScore: 0,
      highestBaseScore: 0,
      bestAccuracy: 0,
      longestSurvival: 0,
      mostEnemiesDefeated: 0,
      bestEfficiency: 0,
      leastDamageRun: 0,
      achievementDates: {},
      longestStreak: 0,
      bestSession: null
    };
  }

  getEmptyTrends() {
    return {
      sessionCount: 0,
      averageScore: 0,
      averageAccuracy: 0,
      averageSurvival: 0,
      improvement: 'no_data',
      playingStyle: 'no_data',
      recommendations: []
    };
  }

  calculateAverageSessionLength(history) {
    const total = history.reduce((sum, session) => sum + session.playTime, 0);
    return Math.round(total / history.length);
  }

  calculateImprovementTrend(history, lookbackSessions = 10) {
    if (history.length < 5) return 'insufficient_data';
    
    const recent = history.slice(-lookbackSessions);
    const older = history.slice(-lookbackSessions * 2, -lookbackSessions);
    
    if (older.length === 0) return 'insufficient_data';
    
    const recentAvg = this.calculateAverage(recent, 'finalScore');
    const olderAvg = this.calculateAverage(older, 'finalScore');
    
    const improvement = (recentAvg - olderAvg) / olderAvg;
    
    if (improvement > 0.1) return 'improving';
    if (improvement < -0.1) return 'declining';
    return 'stable';
  }

  getBestPerformanceSession(history) {
    return history.reduce((best, session) => {
      const score = this.calculatePerformanceScore(session);
      const bestScore = best ? this.calculatePerformanceScore(best) : 0;
      return score > bestScore ? session : best;
    }, null);
  }

  calculatePerformanceScore(session) {
    // 総合パフォーマンススコア計算
    const scoreWeight = session.finalScore * 0.4;
    const accuracyWeight = session.accuracy * 10;
    const survivalWeight = session.playTime * 2;
    const efficiencyWeight = (session.enemiesDefeated / Math.max(session.playTime, 1)) * 100;
    
    return scoreWeight + accuracyWeight + survivalWeight + efficiencyWeight;
  }

  calculateConsistencyScore(history) {
    if (history.length < 3) return 0;
    
    const scores = history.map(s => s.finalScore);
    const mean = scores.reduce((a, b) => a + b, 0) / scores.length;
    const variance = scores.reduce((sum, score) => sum + Math.pow(score - mean, 2), 0) / scores.length;
    const stdDev = Math.sqrt(variance);
    
    // 一貫性スコア（0-100、低い方が一貫している）
    return Math.max(0, 100 - (stdDev / mean * 100));
  }

  analyzePlayFrequency(history) {
    if (history.length === 0) return 'no_data';
    
    const now = new Date();
    const daysSinceFirst = (now - new Date(history[0].timestamp)) / (1000 * 60 * 60 * 24);
    const sessionsPerDay = history.length / Math.max(daysSinceFirst, 1);
    
    if (sessionsPerDay > 3) return 'very_active';
    if (sessionsPerDay > 1) return 'active';
    if (sessionsPerDay > 0.3) return 'casual';
    return 'occasional';
  }

  analyzeAccuracyTrend(history) {
    if (history.length < 5) return 'insufficient_data';
    
    const recentAccuracy = history.slice(-5).reduce((sum, s) => sum + s.accuracy, 0) / 5;
    const olderAccuracy = history.slice(-10, -5).reduce((sum, s) => sum + s.accuracy, 0) / 5;
    
    const improvement = recentAccuracy - olderAccuracy;
    
    if (improvement > 5) return 'improving';
    if (improvement < -5) return 'declining';
    return 'stable';
  }

  analyzeScoreDistribution(history) {
    const scores = history.map(s => s.finalScore);
    const buckets = [0, 1000, 2500, 5000, 10000, 25000, 50000, Infinity];
    const distribution = buckets.slice(0, -1).map((min, i) => {
      const max = buckets[i + 1];
      const count = scores.filter(score => score >= min && score < max).length;
      return {
        range: max === Infinity ? `${min}+` : `${min}-${max}`,
        count: count,
        percentage: Math.round(count / scores.length * 100)
      };
    });
    
    return distribution.filter(bucket => bucket.count > 0);
  }

  calculateAverage(array, property) {
    if (array.length === 0) return 0;
    const sum = array.reduce((total, item) => total + (item[property] || 0), 0);
    return Math.round(sum / array.length);
  }

  getBestOverallSession(history) {
    return history.reduce((best, session) => {
      const currentScore = this.calculateOverallSessionScore(session);
      const bestScore = best ? this.calculateOverallSessionScore(best) : 0;
      return currentScore > bestScore ? session : best;
    }, null);
  }

  calculateOverallSessionScore(session) {
    // 総合評価スコア
    return session.finalScore * 0.5 + 
           session.accuracy * 20 + 
           session.playTime * 3 + 
           session.enemiesDefeated * 10;
  }

  // レコメンデーション生成
  generateRecommendations(recentHistory) {
    const recommendations = [];
    const avgAccuracy = this.calculateAverage(recentHistory, 'accuracy');
    const avgSurvival = this.calculateAverage(recentHistory, 'playTime');
    
    if (avgAccuracy < 60) {
      recommendations.push('射撃精度の向上を目指しましょう。敵をよく狙ってから撃つことを心がけてください。');
    }
    
    if (avgSurvival < 60) {
      recommendations.push('生存時間の延長を目標にしましょう。敵の動きを予測して避けることが重要です。');
    }
    
    const damageAvg = this.calculateAverage(recentHistory, 'damageTaken');
    if (damageAvg > 2) {
      recommendations.push('被ダメージを減らしましょう。無敵時間を有効活用して安全な位置取りを心がけてください。');
    }
    
    return recommendations;
  }

  // 連続改善記録の計算
  getLongestImprovementStreak(history) {
    if (history.length < 2) return 0;
    
    let maxStreak = 0;
    let currentStreak = 0;
    
    for (let i = 1; i < history.length; i++) {
      if (history[i].finalScore > history[i-1].finalScore) {
        currentStreak++;
        maxStreak = Math.max(maxStreak, currentStreak);
      } else {
        currentStreak = 0;
      }
    }
    
    return maxStreak;
  }

  // プレイ間隔分析
  analyzePlayStreaks(history) {
    if (history.length < 2) return { longestGap: 0, averageGap: 0, streaks: [] };
    
    const gaps = [];
    for (let i = 1; i < history.length; i++) {
      const gap = new Date(history[i].timestamp) - new Date(history[i-1].timestamp);
      gaps.push(gap / (1000 * 60 * 60 * 24)); // 日数に変換
    }
    
    return {
      longestGap: Math.max(...gaps),
      averageGap: gaps.reduce((a, b) => a + b, 0) / gaps.length,
      recentActivity: gaps.slice(-5).reduce((a, b) => a + b, 0) / Math.min(5, gaps.length)
    };
  }

  // 生存時間改善分析
  analyzeSurvivalImprovement(history) {
    if (history.length < 5) return 'insufficient_data';
    
    const recentAvg = history.slice(-5).reduce((sum, s) => sum + s.playTime, 0) / 5;
    const olderAvg = history.slice(-10, -5).reduce((sum, s) => sum + s.playTime, 0) / 5;
    
    if (olderAvg === 0) return 'insufficient_data';
    
    const improvement = (recentAvg - olderAvg) / olderAvg;
    
    if (improvement > 0.2) return 'significant_improvement';
    if (improvement > 0.05) return 'slight_improvement';
    if (improvement < -0.2) return 'declining';
    return 'stable';
  }

  // 難易度進行分析
  analyzeDifficultyProgression(history) {
    // 将来の難易度システム用の準備
    return {
      averageDifficulty: 'normal',
      progressionRate: 'steady',
      recommendation: 'maintain_current_level'
    };
  }

  // 最短勝利時間（仮想的な勝利条件）
  getShortestVictoryTime(history) {
    // 高スコアかつ短時間のセッション
    const victories = history.filter(s => s.finalScore > 10000);
    if (victories.length === 0) return null;
    
    return Math.min(...victories.map(s => s.playTime));
  }

  // 効率性計算
  calculateBestEfficiency(history) {
    if (history.length === 0) return 0;
    
    const efficiencies = history.map(session => {
      const timeInMinutes = Math.max(session.playTime / 60, 0.1);
      return session.finalScore / timeInMinutes;
    });
    
    return Math.max(...efficiencies);
  }

  // 達成日時記録
  getAchievementDates(history) {
    const achievements = {};
    let highestScore = 0;
    let bestAccuracy = 0;
    let longestTime = 0;
    
    history.forEach(session => {
      if (session.finalScore > highestScore) {
        highestScore = session.finalScore;
        achievements.highestScore = session.timestamp;
      }
      
      if (session.accuracy > bestAccuracy) {
        bestAccuracy = session.accuracy;
        achievements.bestAccuracy = session.timestamp;
      }
      
      if (session.playTime > longestTime) {
        longestTime = session.playTime;
        achievements.longestSurvival = session.timestamp;
      }
    });
    
    return achievements;
  }

  // 最近の改善度計算
  calculateRecentImprovement(recentHistory) {
    if (recentHistory.length < 3) return 'insufficient_data';
    
    const firstHalf = recentHistory.slice(0, Math.floor(recentHistory.length / 2));
    const secondHalf = recentHistory.slice(Math.floor(recentHistory.length / 2));
    
    const firstAvg = this.calculateAverage(firstHalf, 'finalScore');
    const secondAvg = this.calculateAverage(secondHalf, 'finalScore');
    
    const improvement = (secondAvg - firstAvg) / Math.max(firstAvg, 1);
    
    if (improvement > 0.15) return 'strong_improvement';
    if (improvement > 0.05) return 'moderate_improvement';
    if (improvement < -0.15) return 'declining';
    return 'stable';
  }

  // プレイスタイル分析
  analyzePlayingStyle(recentHistory) {
    if (recentHistory.length === 0) return 'no_data';
    
    const avgAccuracy = this.calculateAverage(recentHistory, 'accuracy');
    const avgSurvival = this.calculateAverage(recentHistory, 'playTime');
    const avgEnemies = this.calculateAverage(recentHistory, 'enemiesDefeated');
    
    // スタイル分類
    if (avgAccuracy > 75 && avgSurvival > 120) {
      return 'strategic_survivor'; // 戦略的・生存重視
    } else if (avgAccuracy > 70) {
      return 'precision_shooter'; // 精密射撃型
    } else if (avgEnemies > 20) {
      return 'aggressive_fighter'; // 積極戦闘型
    } else if (avgSurvival > 90) {
      return 'defensive_player'; // 守備的プレイヤー
    } else {
      return 'balanced_player'; // バランス型
    }
  }
}

  // 時間フォーマット（秒 → mm:ss）
  formatPlayTime(seconds) {
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = Math.floor(seconds % 60);
    return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`;
  }

  // データリセット（デバッグ用）
  resetAllData() {
    Object.values(this.keys).forEach(key => {
      localStorage.removeItem(key);
    });
    this.initializeStorage();
  }

  // データエクスポート（バックアップ用）
  exportData() {
    const exportData = {};
    Object.keys(this.keys).forEach(key => {
      exportData[key] = this.getData(this.keys[key]);
    });
    return JSON.stringify(exportData, null, 2);
  }

  // データインポート（復旧用）
  importData(jsonString) {
    try {
      const importData = JSON.parse(jsonString);
      Object.keys(this.keys).forEach(key => {
        if (importData[key] !== undefined) {
          this.setData(this.keys[key], importData[key]);
        }
      });
      return true;
    } catch (error) {
      console.error('Failed to import data:', error);
      return false;
    }
  }
}

// フック用にエクスポート
window.StorageManager = StorageManager;