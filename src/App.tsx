import { useEffect, useMemo, useState } from 'react';
import './App.css';
import BoardView from './components/Board';
import GitHubIcon from './components/GitHubIcon';
import ThemeSelector from './components/ThemeSelector';
import type { Board, Coord } from './game/engine';
import { createBoard, findPath, removePair, reshuffle, findAnyHint } from './game/engine';
import type { Theme } from './themes/types';
import { themeManager } from './themes/ThemeManager';

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

  // auto-reshuffle if deadlocked on mount
  useEffect(() => {
    if (!findAnyHint(board)) {
      const copy = board.map(r => [...r]);
      reshuffle(copy);
      setBoard(copy);
    }
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
      setMessage('消除了一个配对！');
      setTimeout(() => setMessage(null), 800);
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
  }

  return (
    <div className="app-container">
      <GitHubIcon repoUrl="https://github.com/lian-lian-kan/demo" />
      <header className="app-header">
        <h2 className="app-title">连连看</h2>
        <div className="app-stats">
          <span>分数：{score}</span>
          <span>步数：{moves}</span>
          <span>剩余：{Math.floor(remaining / 2)} 对</span>
          <div className="app-controls">
            <ThemeSelector onThemeChange={onThemeChange} />
            <button className="app-button" onClick={onHint}>提示</button>
            <button className="app-button" onClick={onReset}>重开</button>
          </div>
        </div>
        {message && (
          <div className="app-message">{message}</div>
        )}
      </header>
      <BoardView board={board} selected={selected} onSelect={onSelect} />
    </div>
  );
}

export default App;
