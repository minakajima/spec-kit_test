// データ同期システム拡張
// StorageManagerにデータ整合性、バージョン管理、自動バックアップ機能を追加

// 既存のStorageManagerクラスに追加メソッドを定義
StorageManager.prototype.startDataSync = function() {
  console.log('Data sync system initialized');
  
  // データ整合性チェック開始
  this.performIntegrityCheck();
  
  // 定期的な整合性チェック
  this.integrityInterval = setInterval(() => {
    this.performIntegrityCheck();
  }, this.syncConfig?.integrityCheckInterval || 300000); // 5分毎
  
  // メタデータ初期化
  this.initializeMetadata();
};

// データ整合性チェック
StorageManager.prototype.performIntegrityCheck = function() {
  try {
    const integrity = {
      highScore: this.validateHighScore(),
      gameStats: this.validateGameStats(),
      playHistory: this.validatePlayHistory(),
      settings: this.validateSettings(),
      timestamp: new Date().toISOString()
    };
    
    const hasIssues = Object.values(integrity).some(check => check !== true);
    
    if (hasIssues) {
      console.warn('Data integrity issues detected:', integrity);
      this.handleIntegrityIssues(integrity);
    }
    
    return !hasIssues;
  } catch (error) {
    console.error('Integrity check failed:', error);
    return false;
  }
};

// 個別データ検証
StorageManager.prototype.validateHighScore = function() {
  const highScore = this.getHighScore();
  return typeof highScore === 'number' && highScore >= 0;
};

StorageManager.prototype.validateGameStats = function() {
  const stats = this.getGameStatistics();
  const required = ['totalGamesPlayed', 'totalScore', 'totalPlayTime'];
  
  return required.every(field => 
    typeof stats[field] === 'number' && stats[field] >= 0
  );
};

StorageManager.prototype.validatePlayHistory = function() {
  const history = this.getPlayHistory();
  
  if (!Array.isArray(history)) return false;
  
  // 最新10件の基本検証
  return history.slice(-10).every(session => 
    session.sessionId && 
    session.timestamp && 
    typeof session.finalScore === 'number'
  );
};

StorageManager.prototype.validateSettings = function() {
  const settings = this.getData(this.keys.settings);
  return settings && typeof settings === 'object';
};

// 整合性問題の対処
StorageManager.prototype.handleIntegrityIssues = function(integrity) {
  const fixes = [];
  
  if (!integrity.highScore) {
    this.setData(this.keys.highScore, 0);
    fixes.push('highScore reset to 0');
  }
  
  if (!integrity.gameStats) {
    this.setData(this.keys.gameStats, this.defaults.gameStats);
    fixes.push('gameStats reset to defaults');
  }
  
  if (!integrity.playHistory) {
    this.setData(this.keys.playHistory, []);
    fixes.push('playHistory reset to empty array');
  }
  
  if (!integrity.settings) {
    this.setData(this.keys.settings, this.defaults.settings);
    fixes.push('settings reset to defaults');
  }
  
  console.log('Data integrity fixes applied:', fixes);
  
  // 修復後の自動バックアップ
  this.createBackup('integrity_fix');
};

// メタデータ管理
StorageManager.prototype.initializeMetadata = function() {
  let metadata = this.getData(this.keys.metadata);
  
  if (!metadata) {
    metadata = {
      version: '1.0.0',
      created: new Date().toISOString(),
      lastUpdated: new Date().toISOString(),
      dataIntegrity: true,
      totalSessions: 0,
      lastBackup: null,
      migrationHistory: []
    };
    
    this.setData(this.keys.metadata, metadata);
  }
  
  // バージョンチェック・マイグレーション
  this.checkVersionMigration(metadata);
  
  return metadata;
};

// バージョンマイグレーション
StorageManager.prototype.checkVersionMigration = function(metadata) {
  const currentVersion = '1.0.0';
  const dataVersion = metadata.version || '0.9.0';
  
  if (dataVersion !== currentVersion) {
    console.log(`Data migration required: ${dataVersion} -> ${currentVersion}`);
    
    const migrationResult = this.performMigration(dataVersion, currentVersion);
    
    if (migrationResult.success) {
      metadata.version = currentVersion;
      metadata.lastUpdated = new Date().toISOString();
      metadata.migrationHistory.push({
        from: dataVersion,
        to: currentVersion,
        timestamp: new Date().toISOString(),
        changes: migrationResult.changes
      });
      
      this.setData(this.keys.metadata, metadata);
      console.log('Migration completed successfully');
    } else {
      console.error('Migration failed:', migrationResult.error);
    }
  }
};

// データマイグレーション実行
StorageManager.prototype.performMigration = function(fromVersion, toVersion) {
  try {
    const changes = [];
    
    // バージョン0.9.0 -> 1.0.0のマイグレーション例
    if (fromVersion === '0.9.0' && toVersion === '1.0.0') {
      // 古い統計データ形式を新形式に変換
      const oldStats = this.getData('old_shooter_stats');
      if (oldStats) {
        const newStats = this.convertOldStats(oldStats);
        this.setData(this.keys.gameStats, newStats);
        localStorage.removeItem('old_shooter_stats');
        changes.push('Converted old statistics format');
      }
      
      // プレイ履歴にaccuracyフィールド追加
      const history = this.getPlayHistory();
      const updatedHistory = history.map(session => {
        if (!session.accuracy && session.shotsFired > 0) {
          session.accuracy = (session.shotsHit / session.shotsFired) * 100;
          changes.push('Added accuracy calculation to history');
        }
        return session;
      });
      
      this.setData(this.keys.playHistory, updatedHistory);
    }
    
    return { success: true, changes };
    
  } catch (error) {
    return { success: false, error: error.message };
  }
};

// 自動バックアップシステム
StorageManager.prototype.shouldCreateBackup = function() {
  const metadata = this.getData(this.keys.metadata);
  if (!metadata) return true;
  
  const sessionsSinceBackup = metadata.totalSessions % 10; // 10セッション毎
  return sessionsSinceBackup === 0;
};

StorageManager.prototype.createBackup = function(reason = 'scheduled') {
  try {
    const backup = {
      id: this.generateBackupId(),
      timestamp: new Date().toISOString(),
      reason: reason,
      version: '1.0.0',
      data: {
        highScore: this.getData(this.keys.highScore),
        gameStats: this.getData(this.keys.gameStats),
        playHistory: this.getData(this.keys.playHistory),
        settings: this.getData(this.keys.settings)
      }
    };
    
    // 既存バックアップ取得
    const backups = this.getData(this.keys.backups) || [];
    
    // 新しいバックアップ追加
    backups.push(backup);
    
    // 最大5つまで保持（古いものから削除）
    if (backups.length > 5) {
      backups.shift();
    }
    
    this.setData(this.keys.backups, backups);
    
    // メタデータ更新
    const metadata = this.getData(this.keys.metadata);
    if (metadata) {
      metadata.lastBackup = backup.timestamp;
      this.setData(this.keys.metadata, metadata);
    }
    
    console.log(`Backup created: ${backup.id} (${reason})`);
    return backup.id;
    
  } catch (error) {
    console.error('Backup creation failed:', error);
    return null;
  }
};

StorageManager.prototype.generateBackupId = function() {
  const timestamp = Date.now().toString(36);
  const random = Math.random().toString(36).substring(2, 8);
  return `backup_${timestamp}_${random}`;
};

// バックアップ復元
StorageManager.prototype.restoreFromBackup = function(backupId) {
  try {
    const backups = this.getData(this.keys.backups) || [];
    const backup = backups.find(b => b.id === backupId);
    
    if (!backup) {
      throw new Error(`Backup not found: ${backupId}`);
    }
    
    // データ復元
    Object.keys(backup.data).forEach(key => {
      if (this.keys[key]) {
        this.setData(this.keys[key], backup.data[key]);
      }
    });
    
    // メタデータ更新
    const metadata = this.getData(this.keys.metadata) || {};
    metadata.lastRestored = new Date().toISOString();
    metadata.restoredFrom = backupId;
    this.setData(this.keys.metadata, metadata);
    
    console.log(`Data restored from backup: ${backupId}`);
    return true;
    
  } catch (error) {
    console.error('Backup restore failed:', error);
    return false;
  }
};

// バックアップ一覧取得
StorageManager.prototype.getBackups = function() {
  const backups = this.getData(this.keys.backups) || [];
  
  return backups.map(backup => ({
    id: backup.id,
    timestamp: backup.timestamp,
    reason: backup.reason,
    version: backup.version,
    size: JSON.stringify(backup.data).length
  }));
};

// セッション終了時の処理拡張
StorageManager.prototype.processGameEndWithSync = function(gameState) {
  // 基本的なゲーム終了処理
  const result = this.processGameEnd(gameState);
  
  // メタデータ更新
  this.updateSessionMetadata();
  
  // 自動バックアップチェック
  if (this.shouldCreateBackup()) {
    this.createBackup('auto_session_interval');
  }
  
  // データ整合性チェック
  const integrityOk = this.performIntegrityCheck();
  
  return {
    ...result,
    dataIntegrity: integrityOk,
    backupCreated: this.shouldCreateBackup()
  };
};

StorageManager.prototype.updateSessionMetadata = function() {
  const metadata = this.getData(this.keys.metadata);
  if (metadata) {
    metadata.totalSessions = (metadata.totalSessions || 0) + 1;
    metadata.lastUpdated = new Date().toISOString();
    this.setData(this.keys.metadata, metadata);
  }
};

// データ同期状況取得
StorageManager.prototype.getSyncStatus = function() {
  const metadata = this.getData(this.keys.metadata);
  const backups = this.getBackups();
  
  return {
    version: metadata?.version || 'unknown',
    lastUpdated: metadata?.lastUpdated || 'unknown',
    totalSessions: metadata?.totalSessions || 0,
    lastBackup: metadata?.lastBackup || 'none',
    backupCount: backups.length,
    dataIntegrity: metadata?.dataIntegrity !== false,
    syncEnabled: true
  };
};

// クリーンアップ
StorageManager.prototype.cleanup = function() {
  if (this.integrityInterval) {
    clearInterval(this.integrityInterval);
  }
};

console.log('Data sync extensions loaded');