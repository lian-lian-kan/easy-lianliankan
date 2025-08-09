import React from 'react';
import type { Board, Coord } from '../game/engine';

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
      style={{
        display: 'grid',
        gridTemplateColumns: `repeat(${cols}, ${size}px)`,
        gap: 6,
        padding: 12,
        justifyContent: 'center',
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
              style={{
                width: size,
                height: size,
                borderRadius: 8,
                border: sel ? '2px solid #ff7a00' : '1px solid #ddd',
                background: v === 0 ? '#f6f7f9' : tileColor(v),
                color: v === 0 ? '#aaa' : '#222',
                fontWeight: 700,
                fontSize: size * 0.32,
                boxShadow: v !== 0 ? '0 2px 6px rgba(0,0,0,.1)' : 'none',
                touchAction: 'manipulation',
              }}
            >
              {v !== 0 ? v : ''}
            </button>
          );
        })
      )}
    </div>
  );
}

function tileColor(v: number): string {
  const palette = ['#ffd6e7', '#d6fff2', '#e8ffd6', '#d6e5ff', '#fff8d6', '#e1d6ff', '#d6fff9', '#ffd6d6'];
  return palette[(v - 1) % palette.length];
}

