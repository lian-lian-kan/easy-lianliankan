import { describe, it, expect, beforeEach, vi } from 'vitest';
import { EffectManager } from './EffectManager';
import type { EffectConfig } from './types';

describe('EffectManager', () => {
  let effectManager: EffectManager;
  let mockEffectConfig: EffectConfig;

  beforeEach(() => {
    effectManager = new EffectManager();
    mockEffectConfig = {
      id: 'test-effect',
      name: '测试特效',
      type: 'particle',
      duration: 500,
      styles: {
        primaryColor: '#ff0000',
        secondaryColor: '#00ff00',
        particleCount: 10,
        scale: 1.2,
        opacity: 0.8,
      },
    };
  });

  describe('播放特效', () => {
    it('应该能够播放特效', () => {
      const position = { x: 100, y: 100, width: 50, height: 50 };
      const effectId = effectManager.playEffect(mockEffectConfig, position);
      
      expect(effectId).toBeTruthy();
      expect(effectId).toMatch(/^effect-\d+$/);
      
      const activeEffects = effectManager.getActiveEffects();
      expect(activeEffects).toHaveLength(1);
      expect(activeEffects[0].id).toBe(effectId);
      expect(activeEffects[0].config).toBe(mockEffectConfig);
      expect(activeEffects[0].position).toEqual(position);
      expect(activeEffects[0].isPlaying).toBe(true);
    });

    it('应该触发特效开始事件', () => {
      const mockListener = vi.fn();
      effectManager.on('effectStart', mockListener);
      
      const position = { x: 100, y: 100, width: 50, height: 50 };
      effectManager.playEffect(mockEffectConfig, position);
      
      expect(mockListener).toHaveBeenCalledTimes(1);
      expect(mockListener).toHaveBeenCalledWith(
        expect.objectContaining({
          config: mockEffectConfig,
          position,
          isPlaying: true,
        })
      );
    });

    it('应该在特效结束时自动清理', async () => {
      const mockEndListener = vi.fn();
      effectManager.on('effectEnd', mockEndListener);
      
      const position = { x: 100, y: 100, width: 50, height: 50 };
      const shortConfig = { ...mockEffectConfig, duration: 50 };
      
      effectManager.playEffect(shortConfig, position);
      expect(effectManager.getActiveEffects()).toHaveLength(1);
      
      // 等待特效结束
      await new Promise(resolve => setTimeout(resolve, 100));
      
      expect(effectManager.getActiveEffects()).toHaveLength(0);
      expect(mockEndListener).toHaveBeenCalledTimes(1);
    });
  });

  describe('特效管理', () => {
    it('应该能够手动结束特效', () => {
      const mockEndListener = vi.fn();
      effectManager.on('effectEnd', mockEndListener);
      
      const position = { x: 100, y: 100, width: 50, height: 50 };
      const effectId = effectManager.playEffect(mockEffectConfig, position);
      
      expect(effectManager.getActiveEffects()).toHaveLength(1);
      
      effectManager.endEffect(effectId);
      
      expect(effectManager.getActiveEffects()).toHaveLength(0);
      expect(mockEndListener).toHaveBeenCalledTimes(1);
    });

    it('应该能够停止所有特效', () => {
      const position = { x: 100, y: 100, width: 50, height: 50 };
      
      effectManager.playEffect(mockEffectConfig, position);
      effectManager.playEffect({ ...mockEffectConfig, id: 'test-effect-2' }, position);
      effectManager.playEffect({ ...mockEffectConfig, id: 'test-effect-3' }, position);
      
      expect(effectManager.getActiveEffects()).toHaveLength(3);
      
      effectManager.stopAllEffects();
      
      expect(effectManager.getActiveEffects()).toHaveLength(0);
    });

    it('应该能够同时播放多个特效', () => {
      const position1 = { x: 100, y: 100, width: 50, height: 50 };
      const position2 = { x: 200, y: 200, width: 50, height: 50 };
      
      const effect1 = effectManager.playEffect(mockEffectConfig, position1);
      const effect2 = effectManager.playEffect({ ...mockEffectConfig, id: 'test-effect-2' }, position2);
      
      const activeEffects = effectManager.getActiveEffects();
      expect(activeEffects).toHaveLength(2);
      
      const effectIds = activeEffects.map(e => e.id);
      expect(effectIds).toContain(effect1);
      expect(effectIds).toContain(effect2);
    });
  });

  describe('事件系统', () => {
    it('应该能够添加和移除事件监听器', () => {
      const mockListener = vi.fn();
      
      effectManager.on('effectStart', mockListener);
      
      const position = { x: 100, y: 100, width: 50, height: 50 };
      effectManager.playEffect(mockEffectConfig, position);
      
      expect(mockListener).toHaveBeenCalledTimes(1);
      
      effectManager.off('effectStart', mockListener);
      effectManager.playEffect({ ...mockEffectConfig, id: 'test-effect-2' }, position);
      
      expect(mockListener).toHaveBeenCalledTimes(1); // 没有再次调用
    });

    it('应该处理监听器中的错误', () => {
      const errorListener = vi.fn(() => {
        throw new Error('Test error');
      });
      const normalListener = vi.fn();
      
      effectManager.on('effectStart', errorListener);
      effectManager.on('effectStart', normalListener);
      
      const position = { x: 100, y: 100, width: 50, height: 50 };
      
      // 应该不会抛出错误，并且正常监听器仍然被调用
      expect(() => effectManager.playEffect(mockEffectConfig, position)).not.toThrow();
      expect(normalListener).toHaveBeenCalled();
    });
  });

  describe('资源清理', () => {
    it('应该清理所有资源', () => {
      const mockListener = vi.fn();
      effectManager.on('effectStart', mockListener);
      
      const position = { x: 100, y: 100, width: 50, height: 50 };
      effectManager.playEffect(mockEffectConfig, position);
      
      expect(effectManager.getActiveEffects()).toHaveLength(1);
      
      effectManager.destroy();
      
      expect(effectManager.getActiveEffects()).toHaveLength(0);
      
      // 事件监听器应该被清理
      effectManager.playEffect({ ...mockEffectConfig, id: 'test-effect-2' }, position);
      expect(mockListener).toHaveBeenCalledTimes(1); // 没有再次调用
    });
  });
});
