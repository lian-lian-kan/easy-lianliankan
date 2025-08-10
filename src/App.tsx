import { useEffect, useMemo, useState } from 'react';
import './App.css';
import BoardView from './components/Board';
import GitHubIcon from './components/GitHubIcon';
import GameHeader from './components/GameHeader';
import EffectLayer from './components/EffectLayer';
import type { Board, Coord } from './game/engine';
import { createBoard, findPath, removePair, reshuffle, findAnyHint } from './game/engine';
import type { Theme } from './themes/types';
import { themeManager } from './themes/ThemeManager';
import { effectManager } from './effects/EffectManager';
import { audioManager } from './audio/AudioManager';
import type { EffectInstance } from './effects/types';

const ROWS = 12;
const COLS = 8;
const KINDS = 10;

function App() {
  const [board, setBoard] = useState<Board>(() => createBoard(ROWS, COLS, KINDS));
  const [selected, setSelected] = useState<Coord | null>(null);
  const [score, setScore] = useState(0);
  const [moves, setMoves] = useState(0);
  const [message, setMessage] = useState<string | null>(null);
  const [, setCurrentTheme] = useState<Theme>(themeManager.getCurrentTheme());
  const [activeEffects, setActiveEffects] = useState<EffectInstance[]>([]);

  // auto-reshuffle if deadlocked on mount
  useEffect(() => {
    if (!findAnyHint(board)) {
      const copy = board.map(r => [...r]);
      reshuffle(copy);
      setBoard(copy);
    }
  }, []);

  // 初始化音效系统
  useEffect(() => {
    const initAudio = async () => {
      const currentTheme = themeManager.getCurrentTheme();
      if (currentTheme.audio) {
        try {
          await audioManager.preloadAudio(currentTheme.audio.eliminateSound);
          if (currentTheme.audio.selectSound) {
            await audioManager.preloadAudio(currentTheme.audio.selectSound);
          }
          if (currentTheme.audio.hintSound) {
            await audioManager.preloadAudio(currentTheme.audio.hintSound);
          }
          if (currentTheme.audio.winSound) {
            await audioManager.preloadAudio(currentTheme.audio.winSound);
          }
        } catch (error) {
          console.warn('Failed to preload audio:', error);
        }
      }
    };
    initAudio();
  }, []);

  // 监听特效事件
  useEffect(() => {
    const handleEffectStart = (effect: EffectInstance) => {
      setActiveEffects(prev => [...prev, effect]);
    };

    const handleEffectEnd = (effect: EffectInstance) => {
      setActiveEffects(prev => prev.filter(e => e.id !== effect.id));
    };

    effectManager.on('effectStart', handleEffectStart);
    effectManager.on('effectEnd', handleEffectEnd);

    return () => {
      effectManager.off('effectStart', handleEffectStart);
      effectManager.off('effectEnd', handleEffectEnd);
    };
  }, []);

  const remaining = useMemo(() => board.flat().filter(v => v !== 0).length, [board]);

  function onSelect(p: Coord) {
    if (!selected) {
      setSelected(p);
      return;
    }
    if (p.r === selected.r && p.c === selected.c) {
      setSelected(null);
      return;
    }
    setMoves(m => m + 1);
    const path = findPath(board, selected, p);
    if (path) {
      const next = board.map(r => [...r]);
      removePair(next, selected, p);
      setBoard(next);
      setScore(s => s + 10);
      setSelected(null);

      // 触发消除特效和音效
      triggerEliminateEffects([selected, p]);
      // auto win check
      if (next.flat().every(v => v === 0)) {
        setMessage('恭喜通关！');
      } else if (!findAnyHint(next)) {
        reshuffle(next);
        setBoard(next);
        setMessage('无解，已自动重排');
        setTimeout(() => setMessage(null), 1000);
      }
    } else {
      // if same kind but blocked OR different, just switch selection
      setSelected(p);
    }
  }

  function onReset() {
    setBoard(createBoard(ROWS, COLS, KINDS));
    setSelected(null);
    setScore(0);
    setMoves(0);
    setMessage(null);
  }

  function onHint() {
    const hint = findAnyHint(board);
    if (!hint) {
      const copy = board.map(r => [...r]);
      reshuffle(copy);
      setBoard(copy);
      setMessage('无解，已重排');
      setTimeout(() => setMessage(null), 1000);
      return;
    }
    setSelected(hint.a);
    setMessage('已为你选择一个可消点');
    setTimeout(() => setMessage(null), 800);
  }

  function onThemeChange(theme: Theme) {
    setCurrentTheme(theme);
    // 主题切换时强制重新渲染棋盘
    setBoard(board => [...board.map(row => [...row])]);

    // 预加载新主题的音效
    if (theme.audio) {
      audioManager.preloadAudio(theme.audio.eliminateSound).catch(console.warn);
      if (theme.audio.selectSound) {
        audioManager.preloadAudio(theme.audio.selectSound).catch(console.warn);
      }
      if (theme.audio.hintSound) {
        audioManager.preloadAudio(theme.audio.hintSound).catch(console.warn);
      }
      if (theme.audio.winSound) {
        audioManager.preloadAudio(theme.audio.winSound).catch(console.warn);
      }
    }
  }

  // 触发消除特效和音效
  function triggerEliminateEffects(coords: Coord[]) {
    const currentTheme = themeManager.getCurrentTheme();

    coords.forEach(coord => {
      // 计算特效位置
      const boardElement = document.querySelector('.board-container');
      const tileElements = boardElement?.querySelectorAll('.board-tile');
      if (tileElements) {
        const tileIndex = coord.r * COLS + coord.c;
        const tileElement = tileElements[tileIndex] as HTMLElement;
        if (tileElement) {
          const rect = tileElement.getBoundingClientRect();
          const position = {
            x: rect.left,
            y: rect.top,
            width: rect.width,
            height: rect.height,
          };

          // 播放特效
          if (currentTheme.effects?.eliminateEffect) {
            effectManager.playEffect(currentTheme.effects.eliminateEffect, position);
          }
        }
      }
    });

    // 播放音效
    if (currentTheme.audio?.eliminateSound) {
      audioManager.playAudio(currentTheme.audio.eliminateSound.id);
    }
  }

  return (
    <div className="app-container">
      <GitHubIcon repoUrl="https://github.com/lian-lian-kan/demo" />
      <GameHeader
        score={score}
        moves={moves}
        remaining={remaining}
        message={message}
        onThemeChange={onThemeChange}
        onHint={onHint}
        onReset={onReset}
      />
      <BoardView board={board} selected={selected} onSelect={onSelect} />
      <EffectLayer
        effects={activeEffects}
        onEffectEnd={(effectId) => effectManager.endEffect(effectId)}
      />
    </div>
  );
}

export default App;
