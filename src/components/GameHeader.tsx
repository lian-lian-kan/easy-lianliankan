import { useState, useEffect } from 'react';
import './GameHeader.css';
import ThemeSelector from './ThemeSelector';
import type { Theme } from '../themes/types';

type Props = {
  score: number;
  moves: number;
  remaining: number;
  message: string | null;
  onThemeChange: (theme: Theme) => void;
  onHint: () => void;
  onReset: () => void;
};

export default function GameHeader({
  score,
  moves,
  remaining,
  message,
  onThemeChange,
  onHint,
  onReset,
}: Props) {
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    // 延迟显示动画
    const timer = setTimeout(() => setIsVisible(true), 100);
    return () => clearTimeout(timer);
  }, []);

  return (
    <header className={`game-header ${isVisible ? 'game-header--visible' : ''}`}>
      <div className="game-header__container">
        {/* 游戏Logo区域 */}
        <div className="game-header__logo">
          <div className="game-logo">
            <div className="game-logo__icon">🎮</div>
            <div className="game-logo__dots">
              <span className="dot dot--1"></span>
              <span className="dot dot--2"></span>
              <span className="dot dot--3"></span>
            </div>
          </div>
        </div>

        {/* 游戏统计信息 */}
        <div className="game-header__stats">
          <div className="stat-card stat-card--score">
            <div className="stat-card__icon">🏆</div>
            <div className="stat-card__content">
              <div className="stat-card__label">分数</div>
              <div className="stat-card__value">{score}</div>
            </div>
          </div>

          <div className="stat-card stat-card--moves">
            <div className="stat-card__icon">👆</div>
            <div className="stat-card__content">
              <div className="stat-card__label">步数</div>
              <div className="stat-card__value">{moves}</div>
            </div>
          </div>

          <div className="stat-card stat-card--remaining">
            <div className="stat-card__icon">🎯</div>
            <div className="stat-card__content">
              <div className="stat-card__label">剩余</div>
              <div className="stat-card__value">{Math.floor(remaining / 2)}</div>
            </div>
          </div>
        </div>

        {/* 控制按钮区域 */}
        <div className="game-header__controls">
          <ThemeSelector onThemeChange={onThemeChange} />
          
          <button 
            className="control-button control-button--hint" 
            onClick={onHint}
            title="获取提示"
          >
            <span className="control-button__icon">💡</span>
            <span className="control-button__label">提示</span>
          </button>
          
          <button 
            className="control-button control-button--reset" 
            onClick={onReset}
            title="重新开始"
          >
            <span className="control-button__icon">🔄</span>
            <span className="control-button__label">重开</span>
          </button>
        </div>
      </div>

      {/* 消息提示 */}
      {message && (
        <div className="game-header__message">
          <div className="message-bubble">
            <span className="message-bubble__icon">ℹ️</span>
            <span className="message-bubble__text">{message}</span>
          </div>
        </div>
      )}
    </header>
  );
}
