
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
  const size = Math.min(86, Math.floor((window.innerWidth - 24) / cols)); // tile size in px
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

