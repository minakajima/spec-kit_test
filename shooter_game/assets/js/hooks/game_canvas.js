// Game Canvas JavaScript Hook for Phoenix LiveView
// Handles client-side rendering at 60fps and mouse input capture

const GameCanvas = {
  mounted() {
    this.canvas = this.el;
    this.ctx = this.canvas.getContext('2d');
    this.gameState = null;
    this.animationId = null;
    this.mouseX = 0;
    this.mouseY = 0;
    this.isMouseDown = false;
    this.lastFrameTime = 0;
    this.fps = 0;
    this.frameCount = 0;
    this.fpsUpdateTime = 0;
    
    // Input state
    this.keys = new Set();
    this.shootTimer = 0;
    this.shootDelay = 100; // milliseconds between shots
    
    // Visual effects
    this.particles = [];
    this.explosions = [];
    this.cameraShake = { x: 0, y: 0, intensity: 0 };
    
    // Combat UI effects
    this.damageFlash = { active: false, intensity: 0, startTime: 0, duration: 300 };
    this.healthBarAnimation = { target: 1.0, current: 1.0, speed: 0.05 };
    this.hitEffects = [];
    this.screenEffects = { pulse: { active: false, intensity: 0, startTime: 0, duration: 300 }, flashColor: 'red' };
    
    // Performance monitoring
    this.inputThrottle = {};
    
    // LocalStorage data management
    this.storageManager = new StorageManager();
    this.loadHighScore();
    
    // Setup enhanced event listeners
    this.setupMouseEvents();
    this.setupKeyboardEvents();
    this.setupTouchEvents();
    this.setupWindowEvents();
    
    // Start render loop
    this.startRenderLoop();
    
    console.log('Enhanced GameCanvas hook mounted');
  },

  updated() {
    // Update game state from LiveView with performance optimization
    const gameStateJson = this.el.dataset.gameState;
    if (gameStateJson) {
      try {
        const newGameState = JSON.parse(gameStateJson);
        
        // Only update if state actually changed
        if (!this.gameState || JSON.stringify(this.gameState) !== gameStateJson) {
          const previousStatus = this.gameState?.status;
          this.gameState = newGameState;
          
          // Handle status changes
          if (previousStatus !== this.gameState.status) {
            this.handleStatusChange(previousStatus, this.gameState.status);
          }
          
          // Update high score if needed
          if (this.gameState.score > this.getHighScore()) {
            this.saveHighScore(this.gameState.score);
          }
          
          // Add effects for specific events
          this.processGameEvents();
        }
      } catch (e) {
        console.error('Failed to parse game state:', e);
      }
    }
  },
  
  handleStatusChange(from, to) {
    if (from === 'playing' && to === 'game_over') {
      // Add explosion effect at player position
      if (this.gameState.player) {
        this.addExplosion(this.gameState.player.x, this.gameState.player.y, 2);
      }
      
      // ゲーム終了時のデータ処理・統計更新
      this.gameEndData = this.processGameEndData(this.gameState);
      
      // 新記録の場合、特別なエフェクト
      if (this.gameEndData.isNewHighScore) {
        this.triggerNewHighScoreEffect();
      }
    }
  },
  
  processGameEvents() {
    if (!this.gameState || !this.previousGameState) return;
    
    // Check for player damage
    if (this.gameState.player && this.previousGameState.player) {
      if (this.gameState.player.health < this.previousGameState.player.health) {
        this.triggerDamageFlash();
        this.updateHealthBarTarget();
        this.addHitEffect(this.gameState.player.x, this.gameState.player.y);
      }
    }
    
    // Check for enemy hits
    if (this.gameState.enemies && this.previousGameState.enemies) {
      const prevEnemyCount = this.previousGameState.enemies.length;
      const currentEnemyCount = this.gameState.enemies.length;
      
      if (currentEnemyCount < prevEnemyCount) {
        // Enemy was destroyed
        const lastEnemy = this.previousGameState.enemies[0];
        if (lastEnemy) {
          this.addExplosion(lastEnemy.x, lastEnemy.y, 1.2);
        }
      }
    }
    
    // Store current state for next comparison
    this.previousGameState = JSON.parse(JSON.stringify(this.gameState));
  },

  handleEvent(event, payload) {
    if (event === "game_state_update" && payload.game_state) {
      const previousStatus = this.gameState?.status;
      this.gameState = payload.game_state;
      
      // Handle status changes
      if (previousStatus && previousStatus !== this.gameState.status) {
        this.handleStatusChange(previousStatus, this.gameState.status);
      }
      
      // Update health bar animation
      if (this.gameState.player) {
        const healthRatio = this.gameState.player.health / this.gameState.player.max_health;
        this.healthBarAnimation.target = healthRatio;
      }
    }
  },

  destroyed() {
    // Clean up animation frame
    if (this.animationId) {
      cancelAnimationFrame(this.animationId);
      this.animationId = null;
    }
    
    // Clean up event listeners
    this.canvas.removeEventListener('mousemove', this.handleMouseMove);
    this.canvas.removeEventListener('mousedown', this.handleMouseDown);
    this.canvas.removeEventListener('mouseup', this.handleMouseUp);
    this.canvas.removeEventListener('mouseleave', this.handleMouseLeave);
    this.canvas.removeEventListener('contextmenu', this.preventContextMenu);
    
    document.removeEventListener('keydown', this.handleKeyDown);
    document.removeEventListener('keyup', this.handleKeyUp);
    
    window.removeEventListener('blur', this.handleWindowBlur);
    document.removeEventListener('visibilitychange', this.handleVisibilityChange);
    
    // Clear collections
    this.particles = [];
    this.explosions = [];
    this.keys.clear();
    this.inputThrottle = {};
    
    console.log('Enhanced GameCanvas hook destroyed');
  },

  setupMouseEvents() {
    this.handleMouseMove = (e) => {
      const rect = this.canvas.getBoundingClientRect();
      this.mouseX = e.clientX - rect.left;
      this.mouseY = e.clientY - rect.top;
      
      // Throttled mouse position updates
      this.pushEventThrottled('mouse_move', { 
        x: this.mouseX.toString(), 
        y: this.mouseY.toString() 
      }, 16); // ~60fps
    };

    this.handleMouseDown = (e) => {
      e.preventDefault();
      this.isMouseDown = true;
      this.pushEvent('mouse_down', {});
      this.handleShooting();
    };

    this.handleMouseUp = (e) => {
      e.preventDefault();
      this.isMouseDown = false;
      this.pushEvent('mouse_up', {});
    };

    this.handleMouseLeave = (e) => {
      this.isMouseDown = false;
      this.pushEvent('mouse_up', {});
    };

    this.canvas.addEventListener('mousemove', this.handleMouseMove);
    this.canvas.addEventListener('mousedown', this.handleMouseDown);
    this.canvas.addEventListener('mouseup', this.handleMouseUp);
    this.canvas.addEventListener('mouseleave', this.handleMouseLeave);
    
    // Prevent context menu
    this.canvas.addEventListener('contextmenu', (e) => {
      e.preventDefault();
    });
  },

  setupKeyboardEvents() {
    this.handleKeyDown = (e) => {
      const key = e.key.toLowerCase();
      
      // Prevent default for game keys
      if ([' ', 'escape', 'p', 'r'].includes(key)) {
        e.preventDefault();
      }
      
      if (!this.keys.has(key)) {
        this.keys.add(key);
        this.handleKeyPress(key);
      }
    };
    
    this.handleKeyUp = (e) => {
      this.keys.delete(e.key.toLowerCase());
    };

    document.addEventListener('keydown', this.handleKeyDown);
    document.addEventListener('keyup', this.handleKeyUp);
  },
  
  setupTouchEvents() {
    this.canvas.addEventListener('touchstart', (e) => {
      e.preventDefault();
      const touch = e.touches[0];
      const rect = this.canvas.getBoundingClientRect();
      this.mouseX = touch.clientX - rect.left;
      this.mouseY = touch.clientY - rect.top;
      this.isMouseDown = true;
      
      this.pushEvent('mouse_move', { 
        x: this.mouseX.toString(), 
        y: this.mouseY.toString() 
      });
      this.pushEvent('mouse_down', {});
      this.handleShooting();
    });
    
    this.canvas.addEventListener('touchmove', (e) => {
      e.preventDefault();
      const touch = e.touches[0];
      const rect = this.canvas.getBoundingClientRect();
      this.mouseX = touch.clientX - rect.left;
      this.mouseY = touch.clientY - rect.top;
      
      this.pushEventThrottled('mouse_move', { 
        x: this.mouseX.toString(), 
        y: this.mouseY.toString() 
      }, 16);
    });
    
    this.canvas.addEventListener('touchend', (e) => {
      e.preventDefault();
      this.isMouseDown = false;
      this.pushEvent('mouse_up', {});
    });
  },
  
  setupWindowEvents() {
    // Pause game when window loses focus
    window.addEventListener('blur', () => {
      if (this.gameState?.status === 'playing') {
        this.pushEvent('toggle_pause', {});
      }
    });
    
    // Handle visibility change
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'hidden' && this.gameState?.status === 'playing') {
        this.pushEvent('toggle_pause', {});
      }
    });
  },
  
  handleKeyPress(key) {
    if (!this.gameState) return;
    
    switch (key) {
      case ' ':
      case 'p':
        this.pushEvent('toggle_pause', {});
        break;
      case 'escape':
        if (this.gameState.status === 'playing') {
          this.pushEvent('toggle_pause', {});
        } else if (this.gameState.status === 'paused') {
          this.pushEvent('toggle_pause', {});
        } else if (this.gameState.status === 'game_over') {
          this.pushEvent('restart_game', {});
        }
        break;
      case 'r':
        if (this.gameState.status !== 'playing') {
          this.pushEvent('restart_game', {});
        }
        break;
    }
  },
  
  handleShooting() {
    const now = Date.now();
    if (now - this.shootTimer > this.shootDelay) {
      this.pushEvent('player_shoot', {});
      this.shootTimer = now;
      this.addMuzzleFlash();
    }
  },
  
  pushEventThrottled(event, payload, delay) {
    const now = Date.now();
    const key = event;
    
    if (!this.inputThrottle[key] || now - this.inputThrottle[key] > delay) {
      this.pushEvent(event, payload);
      this.inputThrottle[key] = now;
    }
  },

  startRenderLoop() {
    const render = (currentTime = 0) => {
      // Calculate FPS
      const deltaTime = currentTime - this.lastFrameTime;
      this.lastFrameTime = currentTime;
      
      this.frameCount++;
      if (currentTime - this.fpsUpdateTime > 1000) {
        this.fps = this.frameCount;
        this.frameCount = 0;
        this.fpsUpdateTime = currentTime;
      }
      
      // Handle continuous shooting
      if (this.isMouseDown && this.gameState?.status === 'playing') {
        this.handleShooting();
      }
      
      // Update visual effects
      this.updateParticles(deltaTime);
      this.updateExplosions(deltaTime);
      this.updateCameraShake(deltaTime);
      this.updateCombatEffects(deltaTime);
      
      // Render game
      this.renderGame();
      
      this.animationId = requestAnimationFrame(render);
    };
    
    render();
  },

  renderGame() {
    // Apply camera shake
    this.ctx.save();
    this.ctx.translate(this.cameraShake.x, this.cameraShake.y);
    
    // Clear canvas with gradient background
    const gradient = this.ctx.createLinearGradient(0, 0, 0, this.canvas.height);
    gradient.addColorStop(0, '#000411');
    gradient.addColorStop(0.5, '#001122');
    gradient.addColorStop(1, '#000411');
    this.ctx.fillStyle = gradient;
    this.ctx.fillRect(-10, -10, this.canvas.width + 20, this.canvas.height + 20);
    
    if (!this.gameState) {
      this.ctx.restore();
      return;
    }
    
    // Render stars background
    this.renderStarField();
    
    // Render visual effects (background)
    this.renderExplosions();
    
    // Render game entities
    this.renderPlayer();
    this.renderEnemies();
    this.renderBullets();
    
    // Render visual effects (foreground)
    this.renderParticles();
    
    this.ctx.restore();
    
    // Render combat effects
    this.renderCombatEffects();
    
    // Render UI elements (no camera shake)
    this.renderUI();
    this.renderDebugInfo();
  },

  renderStarField() {
    // Performance optimized star field with reduced calculations
    if (!this.starField) {
      this.generateStarField();
    }
    
    const time = Date.now() * 0.0005;
    this.ctx.fillStyle = '#ffffff';
    
    // Generate pseudo-random stars based on time
    for (let i = 0; i < 100; i++) {
      const x = (i * 37.5 + time * 10) % this.canvas.width;
      const y = (i * 41.7 + time * 15) % this.canvas.height;
      const size = Math.sin(i * 0.1) * 0.5 + 1;
      
      this.ctx.globalAlpha = 0.3 + Math.sin(i * 0.05 + time) * 0.2;
      this.ctx.fillRect(x, y, size, size);
    }
    
    this.ctx.globalAlpha = 1.0;
  },

  renderPlayer() {
    if (!this.gameState.player || this.gameState.player.health <= 0) return;
    
    const player = this.gameState.player;
    
    this.ctx.save();
    this.ctx.translate(player.x, player.y);
    this.ctx.rotate(player.angle || 0);
    
    // Player ship (triangle)
    this.ctx.fillStyle = this.getPlayerColor(player.color);
    this.ctx.beginPath();
    this.ctx.moveTo(0, -player.height / 2);
    this.ctx.lineTo(-player.width / 2, player.height / 2);
    this.ctx.lineTo(player.width / 2, player.height / 2);
    this.ctx.closePath();
    this.ctx.fill();
    
    // Player ship outline
    this.ctx.strokeStyle = '#ffffff';
    this.ctx.lineWidth = 1;
    this.ctx.stroke();
    
    // Firing effect
    if (player.firing) {
      this.ctx.fillStyle = '#ffff00';
      this.ctx.globalAlpha = 0.7;
      this.ctx.fillRect(-2, player.height / 2, 4, 8);
      this.ctx.globalAlpha = 1.0;
    }
    
    this.ctx.restore();
  },

  renderEnemies() {
    if (!this.gameState.enemies) return;
    
    this.gameState.enemies.forEach(enemy => {
      if (enemy.health <= 0) return;
      
      this.ctx.save();
      this.ctx.translate(enemy.x, enemy.y);
      this.ctx.rotate(enemy.angle || 0);
      
      // Enemy ship (rectangle with pointed front)
      this.ctx.fillStyle = this.getEnemyColor(enemy.color);
      this.ctx.beginPath();
      this.ctx.moveTo(0, enemy.height / 2);
      this.ctx.lineTo(-enemy.width / 2, -enemy.height / 2);
      this.ctx.lineTo(enemy.width / 2, -enemy.height / 2);
      this.ctx.closePath();
      this.ctx.fill();
      
      // Enemy ship outline
      this.ctx.strokeStyle = '#ffffff';
      this.ctx.lineWidth = 1;
      this.ctx.stroke();
      
      this.ctx.restore();
    });
  },

  renderBullets() {
    if (!this.gameState.bullets) return;
    
    this.gameState.bullets.forEach(bullet => {
      this.ctx.fillStyle = this.getBulletColor(bullet.color);
      
      // Render bullet with trail effect
      if (bullet.trail_length > 0) {
        this.ctx.globalAlpha = 0.3;
        for (let i = 1; i <= bullet.trail_length; i++) {
          const trailX = bullet.x - bullet.velocity_x * i * 0.1;
          const trailY = bullet.y - bullet.velocity_y * i * 0.1;
          this.ctx.fillRect(trailX - bullet.width/2, trailY - bullet.height/2, 
                          bullet.width, bullet.height);
        }
        this.ctx.globalAlpha = 1.0;
      }
      
      // Main bullet
      this.ctx.fillRect(bullet.x - bullet.width/2, bullet.y - bullet.height/2, 
                       bullet.width, bullet.height);
    });
  },

  renderUI() {
    if (!this.gameState) return;
    
    // HUD elements
    this.ctx.font = '16px monospace';
    this.ctx.fillStyle = '#ffffff';
    this.ctx.textAlign = 'start';
    
    // Score display
    this.ctx.fillStyle = '#60a5fa';
    this.ctx.font = 'bold 20px monospace';
    this.ctx.fillText(`SCORE: ${this.gameState.score.toString().padStart(8, '0')}`, 20, 30);
    
    // High score
    const highScore = this.getHighScore();
    this.ctx.fillStyle = '#fbbf24';
    this.ctx.font = 'bold 16px monospace';
    this.ctx.fillText(`HIGH: ${highScore.toString().padStart(8, '0')}`, 20, 55);
    
    // Player health bar
    if (this.gameState.player) {
      const barWidth = 200;
      const barHeight = 8;
      const x = this.canvas.width / 2 - barWidth / 2;
      const y = this.canvas.height - 40;
      
      // Background
      this.ctx.fillStyle = 'rgba(255, 255, 255, 0.1)';
      this.ctx.fillRect(x, y, barWidth, barHeight);
      
      // Health fill with animation
      const currentHealthPercent = this.healthBarAnimation.current;
      const fillWidth = barWidth * currentHealthPercent;
      
      if (currentHealthPercent > 0.6) {
        this.ctx.fillStyle = '#10b981';
      } else if (currentHealthPercent > 0.3) {
        this.ctx.fillStyle = '#fbbf24';
      } else {
        this.ctx.fillStyle = '#ef4444';
      }
      
      this.ctx.fillRect(x, y, fillWidth, barHeight);
      
      // Health text
      this.ctx.fillStyle = '#94a3b8';
      this.ctx.font = '12px monospace';
      this.ctx.textAlign = 'center';
      this.ctx.fillText('HEALTH', this.canvas.width / 2, y + 20);
      this.ctx.textAlign = 'start';
    }
    
    // Render crosshair at mouse position if game is playing
    if (this.gameState.status === 'playing') {
      this.ctx.strokeStyle = 'rgba(255, 255, 255, 0.8)';
      this.ctx.lineWidth = 2;
      this.ctx.globalAlpha = 0.7;
      
      const size = 12;
      this.ctx.beginPath();
      this.ctx.moveTo(this.mouseX - size, this.mouseY);
      this.ctx.lineTo(this.mouseX + size, this.mouseY);
      this.ctx.moveTo(this.mouseX, this.mouseY - size);
      this.ctx.lineTo(this.mouseX, this.mouseY + size);
      this.ctx.stroke();
      
      // Center dot
      this.ctx.fillStyle = '#ff4444';
      this.ctx.beginPath();
      this.ctx.arc(this.mouseX, this.mouseY, 2, 0, Math.PI * 2);
      this.ctx.fill();
      
      this.ctx.globalAlpha = 1.0;
    }
    
    // Game status overlays
    if (this.gameState.status === 'paused') {
      this.ctx.fillStyle = 'rgba(0, 0, 0, 0.8)';
      this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
      
      this.ctx.fillStyle = '#fbbf24';
      this.ctx.font = 'bold 48px monospace';
      this.ctx.textAlign = 'center';
      this.ctx.fillText('PAUSED', this.canvas.width / 2, this.canvas.height / 2 - 20);
      
      this.ctx.fillStyle = '#e2e8f0';
      this.ctx.font = '18px monospace';
      this.ctx.fillText('Press SPACE to continue', this.canvas.width / 2, this.canvas.height / 2 + 30);
      this.ctx.fillText('Press ESC to resume', this.canvas.width / 2, this.canvas.height / 2 + 55);
      this.ctx.textAlign = 'start';
    } else if (this.gameState.status === 'game_over') {
      this.ctx.fillStyle = 'rgba(0, 0, 0, 0.9)';
      this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
      
      this.ctx.fillStyle = '#ef4444';
      this.ctx.font = 'bold 48px monospace';
      this.ctx.textAlign = 'center';
      this.ctx.fillText('GAME OVER', this.canvas.width / 2, this.canvas.height / 2 - 80);
      
      // 最終スコア表示（ボーナス込み）
      if (this.gameEndData) {
        this.ctx.fillStyle = '#fbbf24';
        this.ctx.font = 'bold 32px monospace';
        this.ctx.fillText(`${this.gameEndData.sessionData.finalScore.toString().padStart(8, '0')}`, this.canvas.width / 2, this.canvas.height / 2 - 30);
        
        // 新記録判定
        if (this.gameEndData.isNewHighScore) {
          this.ctx.fillStyle = '#10b981';
          this.ctx.font = 'bold 20px monospace';
          this.ctx.fillText('★ NEW HIGH SCORE! ★', this.canvas.width / 2, this.canvas.height / 2 + 5);
        }
        
        // ボーナス詳細表示
        const bonusTotal = this.gameEndData.sessionData.finalScore - this.gameEndData.sessionData.baseScore;
        if (bonusTotal > 0) {
          this.ctx.fillStyle = '#60a5fa';
          this.ctx.font = '14px monospace';
          this.ctx.fillText(`Base: ${this.gameEndData.sessionData.baseScore} + Bonus: ${bonusTotal}`, this.canvas.width / 2, this.canvas.height / 2 + 25);
        }
        
        // 統計情報表示
        this.ctx.fillStyle = '#94a3b8';
        this.ctx.font = '12px monospace';
        this.ctx.fillText(`Accuracy: ${this.gameEndData.sessionData.accuracy.toFixed(1)}% | Time: ${this.formatTime(this.gameEndData.sessionData.playTime)}`, this.canvas.width / 2, this.canvas.height / 2 + 45);
      } else {
        // フォールバック表示
        this.ctx.fillStyle = '#fbbf24';
        this.ctx.font = 'bold 32px monospace';
        this.ctx.fillText(`${this.gameState.score.toString().padStart(8, '0')}`, this.canvas.width / 2, this.canvas.height / 2 - 30);
      }
      
      this.ctx.fillStyle = '#94a3b8';
      this.ctx.font = '16px monospace';
      this.ctx.fillText('Press R to restart', this.canvas.width / 2, this.canvas.height / 2 + 70);
      this.ctx.fillText('Press ESC to restart', this.canvas.width / 2, this.canvas.height / 2 + 90);
      this.ctx.textAlign = 'start';
    }
  },
  
  renderCombatEffects() {
    // Damage flash effect (full screen)
    if (this.damageFlash.active) {
      this.ctx.save();
      this.ctx.fillStyle = `rgba(255, 0, 0, ${this.damageFlash.intensity * 0.3})`;
      this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
      this.ctx.restore();
    }
    
    // Hit effects (expanding circles at impact points)
    this.hitEffects.forEach(effect => {
      this.ctx.save();
      this.ctx.globalAlpha = effect.opacity;
      this.ctx.strokeStyle = '#ff4444';
      this.ctx.lineWidth = 3;
      
      this.ctx.beginPath();
      this.ctx.arc(effect.x, effect.y, effect.size, 0, Math.PI * 2);
      this.ctx.stroke();
      
      // Inner pulse
      this.ctx.strokeStyle = '#ffffff';
      this.ctx.lineWidth = 1;
      this.ctx.beginPath();
      this.ctx.arc(effect.x, effect.y, effect.size * 0.6, 0, Math.PI * 2);
      this.ctx.stroke();
      
      this.ctx.restore();
    });
    
    // Screen pulse effect
    if (this.screenEffects.pulse.active) {
      this.ctx.save();
      const gradient = this.ctx.createRadialGradient(
        this.canvas.width / 2, this.canvas.height / 2, 0,
        this.canvas.width / 2, this.canvas.height / 2, Math.max(this.canvas.width, this.canvas.height) / 2
      );
      gradient.addColorStop(0, `rgba(255, 255, 255, ${this.screenEffects.pulse.intensity * 0.1})`);
      gradient.addColorStop(1, 'rgba(255, 255, 255, 0)');
      
      this.ctx.fillStyle = gradient;
      this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
      this.ctx.restore();
    }
  },

  renderDebugInfo() {
    // Performance info (top-right corner)
    this.ctx.fillStyle = 'rgba(0, 0, 0, 0.5)';
    this.ctx.fillRect(this.canvas.width - 120, 10, 110, 80);
    
    this.ctx.fillStyle = '#94a3b8';
    this.ctx.font = '12px monospace';
    this.ctx.textAlign = 'right';
    
    this.ctx.fillText(`FPS: ${this.fps}`, this.canvas.width - 15, 30);
    this.ctx.fillText(`Particles: ${this.particles.length}`, this.canvas.width - 15, 45);
    this.ctx.fillText(`Explosions: ${this.explosions.length}`, this.canvas.width - 15, 60);
    this.ctx.fillText(`Shake: ${this.cameraShake.intensity.toFixed(1)}`, this.canvas.width - 15, 75);
    
    this.ctx.textAlign = 'start';
  },

  getPlayerColor(color) {
    switch (color) {
      case 'blue': return '#4444ff';
      case 'red': return '#ff4444';
      case 'green': return '#44ff44';
      default: return '#4444ff';
    }
  },

  getEnemyColor(color) {
    switch (color) {
      case 'red': return '#ff4444';
      case 'green': return '#44ff44';
      case 'purple': return '#ff44ff';
      default: return '#ff4444';
    }
  },

  getBulletColor(color) {
    switch (color) {
      case 'yellow': return '#ffff44';
      case 'red': return '#ff4444';
      case 'blue': return '#4444ff';
      case 'green': return '#44ff44';
      case 'white': return '#ffffff';
      case 'orange': return '#ff8844';
      default: return '#ffff44';
    }
  },

  // Visual Effects
  addMuzzleFlash() {
    if (!this.gameState?.player) return;
    
    const player = this.gameState.player;
    this.particles.push({
      x: player.x,
      y: player.y - 15,
      vx: (Math.random() - 0.5) * 4,
      vy: -Math.random() * 3 - 2,
      life: 1.0,
      maxLife: 200,
      color: '#ffff00',
      size: 3
    });
  },
  
  addExplosion(x, y, intensity = 1) {
    this.explosions.push({
      x: x,
      y: y,
      radius: 0,
      maxRadius: 30 * intensity,
      life: 1.0,
      maxLife: 500,
      intensity: intensity
    });
    
    // Add particle effects
    for (let i = 0; i < 8 * intensity; i++) {
      const angle = (i / (8 * intensity)) * Math.PI * 2;
      const speed = Math.random() * 5 + 2;
      this.particles.push({
        x: x,
        y: y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        life: 1.0,
        maxLife: 300 + Math.random() * 200,
        color: `hsl(${Math.random() * 60 + 15}, 100%, 60%)`,
        size: Math.random() * 4 + 2
      });
    }
    
    // Camera shake
    this.cameraShake.intensity = Math.max(this.cameraShake.intensity, intensity * 8);
  },

  triggerDamageFlash() {
    this.damageFlash.active = true;
    this.damageFlash.intensity = 1.0;
    this.damageFlash.startTime = Date.now();
    
    // Trigger screen pulse effect
    this.screenEffects.pulse.active = true;
    this.screenEffects.pulse.intensity = 0.6;
    this.screenEffects.pulse.startTime = Date.now();
  },

  updateHealthBarTarget() {
    if (this.gameState && this.gameState.player) {
      this.healthBarAnimation.target = this.gameState.player.health / this.gameState.player.max_health;
    }
  },

  addHitEffect(x, y) {
    this.hitEffects.push({
      x: x,
      y: y,
      startTime: Date.now(),
      duration: 300,
      size: 0,
      maxSize: 40,
      opacity: 1.0
    });
  },
  
  updateParticles(deltaTime) {
    this.particles = this.particles.filter(particle => {
      particle.life -= deltaTime / particle.maxLife;
      particle.x += particle.vx;
      particle.y += particle.vy;
      particle.vy += 0.1; // gravity
      particle.size *= 0.98; // shrink
      
      return particle.life > 0 && particle.size > 0.1;
    });
  },

  updateCombatEffects(deltaTime) {
    const now = Date.now();
    
    // Update damage flash
    if (this.damageFlash.active) {
      const elapsed = now - this.damageFlash.startTime;
      if (elapsed >= this.damageFlash.duration) {
        this.damageFlash.active = false;
      } else {
        const progress = elapsed / this.damageFlash.duration;
        this.damageFlash.intensity = Math.max(0, 1.0 - progress);
      }
    }
    
    // Update health bar animation
    const diff = this.healthBarAnimation.target - this.healthBarAnimation.current;
    if (Math.abs(diff) > 0.001) {
      this.healthBarAnimation.current += diff * this.healthBarAnimation.speed * deltaTime / 16.67;
    }
    
    // Update hit effects
    this.hitEffects = this.hitEffects.filter(effect => {
      const elapsed = now - effect.startTime;
      if (elapsed >= effect.duration) {
        return false;
      }
      
      const progress = elapsed / effect.duration;
      effect.size = effect.maxSize * Math.sin(progress * Math.PI);
      effect.opacity = 1.0 - progress;
      
      return true;
    });
    
    // Update screen effects
    if (this.screenEffects.pulse.active) {
      const elapsed = now - this.screenEffects.pulse.startTime;
      if (elapsed >= this.screenEffects.pulse.duration) {
        this.screenEffects.pulse.active = false;
      } else {
        const progress = elapsed / this.screenEffects.pulse.duration;
        this.screenEffects.pulse.intensity = 0.6 * (1.0 - progress);
      }
    }
  },
  
  updateExplosions(deltaTime) {
    this.explosions = this.explosions.filter(explosion => {
      explosion.life -= deltaTime / explosion.maxLife;
      explosion.radius = (1 - explosion.life) * explosion.maxRadius;
      
      return explosion.life > 0;
    });
  },
  
  updateCameraShake(deltaTime) {
    if (this.cameraShake.intensity > 0) {
      this.cameraShake.intensity -= deltaTime * 0.01;
      if (this.cameraShake.intensity < 0) this.cameraShake.intensity = 0;
      
      this.cameraShake.x = (Math.random() - 0.5) * this.cameraShake.intensity;
      this.cameraShake.y = (Math.random() - 0.5) * this.cameraShake.intensity;
    } else {
      this.cameraShake.x = 0;
      this.cameraShake.y = 0;
    }
  },
  
  renderParticles() {
    this.particles.forEach(particle => {
      this.ctx.save();
      this.ctx.globalAlpha = particle.life;
      this.ctx.fillStyle = particle.color;
      this.ctx.beginPath();
      this.ctx.arc(particle.x, particle.y, particle.size, 0, Math.PI * 2);
      this.ctx.fill();
      this.ctx.restore();
    });
  },
  
  renderExplosions() {
    this.explosions.forEach(explosion => {
      this.ctx.save();
      this.ctx.globalAlpha = explosion.life * 0.8;
      
      // Outer ring
      this.ctx.strokeStyle = '#ff4444';
      this.ctx.lineWidth = 3;
      this.ctx.beginPath();
      this.ctx.arc(explosion.x, explosion.y, explosion.radius, 0, Math.PI * 2);
      this.ctx.stroke();
      
      // Inner glow
      this.ctx.fillStyle = '#ffaa00';
      this.ctx.globalAlpha = explosion.life * 0.3;
      this.ctx.beginPath();
      this.ctx.arc(explosion.x, explosion.y, explosion.radius * 0.6, 0, Math.PI * 2);
      this.ctx.fill();
      
      this.ctx.restore();
    });
  },

  // LocalStorage data management with StorageManager
  loadHighScore() {
    return this.storageManager.getHighScore();
  },

  getHighScore() {
    return this.storageManager.getHighScore();
  },

  saveHighScore(score) {
    return this.storageManager.updateHighScore(score);
  },

  // ゲーム終了時の包括的データ処理（同期機能付き）
  processGameEndData(gameState) {
    // データ同期システムを使用した処理
    const result = this.storageManager.processGameEndWithSync 
      ? this.storageManager.processGameEndWithSync(gameState)
      : this.storageManager.processGameEnd(gameState);
    
    // ゲーム終了画面で使用する統計情報を追加
    if (result.isNewHighScore) {
      console.log('🎉 New High Score!', result.sessionData.finalScore);
    }
    
    // データ同期状況のログ
    if (result.dataIntegrity === false) {
      console.warn('Data integrity issues detected during game end');
    }
    
    if (result.backupCreated) {
      console.log('📦 Auto backup created');
    }
    
    return result;
  },

  // 統計サマリー取得
  getStatsSummary() {
    return this.storageManager.getStatsSummary();
  },

  // 詳細プレイ分析取得
  getPlayAnalysis() {
    return this.storageManager.getPlayPatternAnalysis();
  },

  // 個人ベスト記録取得
  getPersonalBests() {
    return this.storageManager.getPersonalBests();
  },

  // 最近の傾向分析
  getRecentTrends(days = 7) {
    return this.storageManager.getRecentTrends(days);
  },

  // 時間フォーマット（秒 → mm:ss）
  formatTime(seconds) {
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = Math.floor(seconds % 60);
    return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`;
  },

  // 新記録エフェクト
  triggerNewHighScoreEffect() {
    // 金色パーティクル爆発
    for (let i = 0; i < 50; i++) {
      this.particles.push({
        x: this.canvas.width / 2,
        y: this.canvas.height / 2,
        vx: (Math.random() - 0.5) * 12,
        vy: (Math.random() - 0.5) * 12,
        life: 1.0,
        maxLife: 600 + Math.random() * 400,
        color: `hsl(${Math.random() * 60 + 30}, 100%, 70%)`, // 金色系
        size: Math.random() * 6 + 3
      });
    }
    
    // 強力なカメラシェイク
    this.cameraShake.intensity = 25;
    
    // 画面フラッシュ（金色）
    this.screenEffects.pulse.active = true;
    this.screenEffects.pulse.intensity = 0.8;
    this.screenEffects.pulse.startTime = Date.now();
    this.screenEffects.flashColor = 'gold';
  },
  
  // Performance Optimizations
  generateStarField() {
    this.starField = [];
    const starCount = 50; // Reduced from potential higher count
    
    for (let i = 0; i < starCount; i++) {
      this.starField.push({
        x: Math.random() * this.canvas.width,
        y: Math.random() * this.canvas.height,
        size: Math.random() * 2 + 0.5,
        speed: Math.random() * 0.5 + 0.1,
        opacity: Math.random() * 0.8 + 0.2
      });
    }
  },
  
  optimizedRenderStars() {
    if (!this.starField) return;
    
    this.ctx.fillStyle = '#ffffff';
    
    this.starField.forEach(star => {
      // Move star
      star.y += star.speed;
      if (star.y > this.canvas.height) {
        star.y = -5;
        star.x = Math.random() * this.canvas.width;
      }
      
      // Render with opacity variation
      this.ctx.globalAlpha = star.opacity * (0.5 + 0.5 * Math.sin(Date.now() * 0.001 + star.x * 0.01));
      this.ctx.fillRect(star.x, star.y, star.size, star.size);
    });
    
    this.ctx.globalAlpha = 1.0;
  },
  
  // Memory management for particles
  optimizeParticles() {
    // Limit particle count for performance
    if (this.particles.length > 100) {
      this.particles = this.particles.slice(-80); // Keep newest 80
    }
    
    if (this.explosions.length > 10) {
      this.explosions = this.explosions.slice(-8); // Keep newest 8
    }
  },
  
  // Throttled event processing
  shouldProcessFrame() {
    // Skip frames if FPS is too low
    return this.fps > 30 || this.frameCount % 2 === 0;
  }
};

export default GameCanvas;