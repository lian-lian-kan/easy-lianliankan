import { useEffect, useState } from 'react';
import './Board.css';
import type { Board, Coord } from '../game/engine';
import { getTileIcon, getTileColor } from '../utils/tileIcons';

type Props = {
  board: Board;
  selected: Coord | null;
  onSelect: (p: Coord) => void;
};

export default function BoardView({ board, selected, onSelect }: Props) {
  const rows = board.length;
  const cols = board[0].length;
  
  // 响应式窗口尺寸状态
  const [windowSize, setWindowSize] = useState({
    width: typeof window !== 'undefined' ? window.innerWidth : 375,
    height: typeof window !== 'undefined' ? window.innerHeight : 812
  });

  useEffect(() => {
    const handleResize = () => {
      setWindowSize({
        width: window.innerWidth,
        height: window.innerHeight
      });
    };

    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  // 改进的瓦片大小计算逻辑
  const calculateTileSize = () => {
    const padding = 24; // 总padding
    const gap = 6; // 瓦片间隙
    const headerHeight = 120; // 大概的header高度
    const availableWidth = windowSize.width - padding;
    const availableHeight = windowSize.height - headerHeight - padding;
    
    // 基于宽度计算的瓦片大小
    const sizeByWidth = Math.floor((availableWidth - (cols - 1) * gap) / cols);
    // 基于高度计算的瓦片大小
    const sizeByHeight = Math.floor((availableHeight - (rows - 1) * gap) / rows);
    
    // 取较小值，确保棋盘能完全显示在屏幕内
    const size = Math.min(sizeByWidth, sizeByHeight, 60); // 最大60px
    return Math.max(size, 24); // 最小24px
  };

  const size = calculateTileSize();
  
  return (
    <div
      className="board-container"
      style={{
        gridTemplateColumns: `repeat(${cols}, ${size}px)`,
      }}
    >
      {Array.from({ length: rows }).map((_, r) =>
        Array.from({ length: cols }).map((__, c) => {
          const v = board[r][c];
          const sel = selected && selected.r === r && selected.c === c;
          return (
            <button
              key={`${r}-${c}`}
              onClick={() => v !== 0 && onSelect({ r, c })}
              className={`board-tile ${v !== 0 ? 'board-tile--active' : ''} ${sel ? 'board-tile--selected' : ''}`}
              style={{
                width: size,
                height: size,
                background: v === 0 ? '#f6f7f9' : getTileColor(v),
                fontSize: size * 0.5,
              }}
            >
              {v !== 0 ? getTileIcon(v) : ''}
            </button>
          );
        })
      )}
    </div>
  );
}
