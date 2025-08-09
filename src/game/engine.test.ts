import { describe, it, expect } from 'vitest';
import { createBoard, findPath, Coord, removePair, hasAnyMoves, reshuffle, findAnyHint } from './engine';

function clone<T>(x: T): T { return JSON.parse(JSON.stringify(x)); }

describe('连连看核心逻辑', () => {
  it('生成棋盘为偶数配对', () => {
    const b = createBoard(6, 6, 6);
    const counts = new Map<number, number>();
    for (const v of b.flat()) counts.set(v, (counts.get(v) || 0) + 1);
    for (const [k, v] of counts) {
      expect(v % 2).toBe(0);
      expect(k).toBeGreaterThan(0);
    }
  });

  it('简单直线可连通（0拐点）', () => {
    const b = [
      [1, 1, 0],
      [0, 0, 0],
      [0, 0, 0],
    ];
    const path = findPath(b, { r: 0, c: 0 }, { r: 0, c: 1 });
    expect(path).toBeTruthy();
  });

  it('一次转弯（1拐点）', () => {
    const b = [
      [1, 0, 0],
      [0, 0, 1],
      [0, 0, 0],
    ];
    const path = findPath(b, { r: 0, c: 0 }, { r: 1, c: 2 });
    expect(path).toBeTruthy();
  });

  it('两次转弯（2拐点）', () => {
    const b = [
      [1, 0, 0, 0],
      [2, 2, 2, 2],
      [0, 0, 0, 1],
    ];
    const path = findPath(b, { r: 0, c: 0 }, { r: 2, c: 3 });
    expect(path).toBeTruthy();
  });

  it('阻挡导致不可连（内圈完全被阻挡）', () => {
    const b = [
      [2, 2, 2, 2, 2],
      [2, 1, 2, 1, 2],
      [2, 2, 2, 2, 2],
    ];
    const path = findPath(b as any, { r: 1, c: 1 }, { r: 1, c: 3 });
    expect(path).toBeNull();
  });

  it('消除、无解检测与重排', () => {
    const b = [
      [1, 1, 2, 2],
      [3, 3, 4, 4],
    ];
    const p = findPath(b, { r: 0, c: 0 }, { r: 0, c: 1 });
    expect(p).toBeTruthy();
    removePair(b as any, { r: 0, c: 0 }, { r: 0, c: 1 });
    if (!hasAnyMoves(b as any)) {
      reshuffle(b as any);
    }
    const hint = findAnyHint(b as any);
    expect(hint).not.toBeNull();
  });
});

