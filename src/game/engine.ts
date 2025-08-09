export type Coord = { r: number; c: number };
export type Board = number[][]; // 0 = empty, >0 = tile type id

export type Path = Coord[]; // sequence of grid points (unpadded coordinates incl. outside points not included)

export function createBoard(rows: number, cols: number, kinds: number): Board {
  // Ensure even number of cells
  const total = rows * cols;
  if (total % 2 !== 0) {
    throw new Error("Board size must be even (rows * cols)");
  }
  // Fill pairs
  const ids: number[] = [];
  for (let i = 0; i < total / 2; i++) {
    const id = (i % kinds) + 1; // ids 1..kinds
    ids.push(id, id);
  }
  // Shuffle
  shuffle(ids);
  const board: Board = Array.from({ length: rows }, () => Array(cols).fill(0));
  let idx = 0;
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      board[r][c] = ids[idx++];
    }
  }
  return board;
}

function shuffle<T>(arr: T[]) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
}

function padBoard(board: Board): Board {
  const rows = board.length;
  const cols = board[0].length;
  const padded: Board = Array.from({ length: rows + 2 }, () => Array(cols + 2).fill(0));
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      padded[r + 1][c + 1] = board[r][c];
    }
  }
  // border remains 0 (empty) to allow paths to go around
  return padded;
}

function isInside(board: Board, p: Coord): boolean {
  return p.r >= 0 && p.r < board.length && p.c >= 0 && p.c < board[0].length;
}

// BFS with at most 2 turns (i.e., up to 3 straight segments)
// Returns path in original board coordinates (not padded), including both endpoints and intermediate turning points
export function findPath(board: Board, a: Coord, b: Coord): Path | null {
  if (!isInside(board, a) || !isInside(board, b)) return null;
  if (a.r === b.r && a.c === b.c) return null;
  const valA = board[a.r][a.c];
  const valB = board[b.r][b.c];
  if (valA === 0 || valB === 0 || valA !== valB) return null;

  const P = padBoard(board);
  const start: Coord = { r: a.r + 1, c: a.c + 1 };
  const end: Coord = { r: b.r + 1, c: b.c + 1 };
  const dirs = [
    { dr: -1, dc: 0 }, // up
    { dr: 1, dc: 0 }, // down
    { dr: 0, dc: -1 }, // left
    { dr: 0, dc: 1 }, // right
  ];

  type Node = { r: number; c: number; dir: number; turns: number };
  const rows = P.length;
  const cols = P[0].length;

  // visited[r][c][dir] = minimal turns used to reach
  const visited = new Array(rows)
    .fill(0)
    .map(() => new Array(cols).fill(0).map(() => new Array(4).fill(Infinity)));

  const queue: Node[] = [];
  const parent = new Map<string, string>(); // key: r,c,dir,turns -> prev key

  // Initialize by stepping out in all 4 directions from start without counting a turn yet
  for (let d = 0; d < 4; d++) {
    const nr = start.r + dirs[d].dr;
    const nc = start.c + dirs[d].dc;
    if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
    if (P[nr][nc] !== 0 && !(nr === end.r && nc === end.c)) continue;
    visited[nr][nc][d] = 0;
    queue.push({ r: nr, c: nc, dir: d, turns: 0 });
    parent.set(key(nr, nc, d, 0), key(start.r, start.c, -1, 0));
  }

  while (queue.length) {
    const cur = queue.shift()!;
    if (cur.r === end.r && cur.c === end.c) {
      // reconstruct path from end to start
      const pts: { r: number; c: number; dir: number; turns: number }[] = [];
      let k = key(cur.r, cur.c, cur.dir, cur.turns);
      while (parent.has(k)) {
        const [r, c, dir, turns] = parseKey(k);
        pts.push({ r, c, dir, turns });
        k = parent.get(k)!;
      }
      // include start
      const [sr, sc] = [start.r, start.c];
      const pathPadded = [{ r: sr, c: sc }, ...pts.map(p => ({ r: p.r, c: p.c }))];
      // compress to turning points (including start and end)
      const simplified = compressPath(pathPadded);
      // convert back to unpadded board coordinates
      const unpadded = simplified.map(p => ({ r: p.r - 1, c: p.c - 1 }));
      return unpadded;
    }

    for (let nd = 0; nd < 4; nd++) {
      const nr = cur.r + dirs[nd].dr;
      const nc = cur.c + dirs[nd].dc;
      if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
      if (P[nr][nc] !== 0 && !(nr === end.r && nc === end.c)) continue;
      const nturns = cur.dir === nd ? cur.turns : cur.turns + 1;
      if (nturns > 2) continue;
      if (visited[nr][nc][nd] <= nturns) continue;
      visited[nr][nc][nd] = nturns;
      queue.push({ r: nr, c: nc, dir: nd, turns: nturns });
      parent.set(key(nr, nc, nd, nturns), key(cur.r, cur.c, cur.dir, cur.turns));
    }
  }

  return null;
}

function key(r: number, c: number, dir: number, turns: number): string {
  return `${r},${c},${dir},${turns}`;
}
function parseKey(k: string): [number, number, number, number] {
  const [r, c, d, t] = k.split(",").map(Number);
  return [r, c, d, t];
}

function compressPath(points: Coord[]): Coord[] {
  if (points.length <= 2) return points;
  const res: Coord[] = [points[0]];
  for (let i = 1; i < points.length - 1; i++) {
    const prev = res[res.length - 1];
    const cur = points[i];
    const next = points[i + 1];
    const v1 = { r: cur.r - prev.r, c: cur.c - prev.c };
    const v2 = { r: next.r - cur.r, c: next.c - cur.c };
    // keep turning points
    if (v1.r !== v2.r || v1.c !== v2.c) {
      res.push(cur);
    }
  }
  res.push(points[points.length - 1]);
  return res;
}

export function removePair(board: Board, a: Coord, b: Coord): void {
  board[a.r][a.c] = 0;
  board[b.r][b.c] = 0;
}

export function hasAnyMoves(board: Board): boolean {
  return findAnyHint(board) !== null;
}

export function findAnyHint(board: Board): { a: Coord; b: Coord; path: Path } | null {
  const rows = board.length;
  const cols = board[0].length;
  for (let r1 = 0; r1 < rows; r1++) {
    for (let c1 = 0; c1 < cols; c1++) {
      const v = board[r1][c1];
      if (v === 0) continue;
      for (let r2 = r1; r2 < rows; r2++) {
        for (let c2 = r2 === r1 ? c1 + 1 : 0; c2 < cols; c2++) {
          if (board[r2][c2] !== v) continue;
          const path = findPath(board, { r: r1, c: c1 }, { r: r2, c: c2 });
          if (path) return { a: { r: r1, c: c1 }, b: { r: r2, c: c2 }, path };
        }
      }
    }
  }
  return null;
}

export function reshuffle(board: Board, maxTries = 20): void {
  const rows = board.length;
  const cols = board[0].length;
  const tiles: number[] = [];
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      const v = board[r][c];
      if (v !== 0) tiles.push(v);
    }
  }
  if (tiles.length % 2 !== 0) return; // shouldn't happen

  for (let attempt = 0; attempt < maxTries; attempt++) {
    shuffle(tiles);
    let idx = 0;
    for (let r = 0; r < rows; r++) {
      for (let c = 0; c < cols; c++) {
        if (board[r][c] !== 0) {
          board[r][c] = tiles[idx++];
        }
      }
    }
    if (hasAnyMoves(board)) return;
  }
}

