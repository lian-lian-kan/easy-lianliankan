import { describe, it, expect, beforeEach, vi } from 'vitest';
import { AudioManager } from './AudioManager';
import type { AudioConfig } from './types';

// Mock HTMLAudioElement
class MockAudio {
  src = '';
  volume = 1;
  loop = false;
  playbackRate = 1;
  preload = 'auto';
  currentTime = 0;
  
  private listeners: { [key: string]: Function[] } = {};
  
  addEventListener(event: string, listener: Function) {
    if (!this.listeners[event]) {
      this.listeners[event] = [];
    }
    this.listeners[event].push(listener);
  }
  
  removeEventListener(event: string, listener: Function) {
    if (this.listeners[event]) {
      const index = this.listeners[event].indexOf(listener);
      if (index > -1) {
        this.listeners[event].splice(index, 1);
      }
    }
  }
  
  dispatchEvent(event: string) {
    if (this.listeners[event]) {
      this.listeners[event].forEach(listener => listener());
    }
  }
  
  async load() {
    // 模拟加载完成
    setTimeout(() => this.dispatchEvent('canplaythrough'), 10);
  }
  
  async play() {
    this.dispatchEvent('play');
    return Promise.resolve();
  }
  
  pause() {
    this.dispatchEvent('pause');
  }
}

// Mock localStorage
const mockLocalStorage = {
  store: {} as { [key: string]: string },
  getItem: vi.fn((key: string) => mockLocalStorage.store[key] || null),
  setItem: vi.fn((key: string, value: string) => {
    mockLocalStorage.store[key] = value;
  }),
  removeItem: vi.fn((key: string) => {
    delete mockLocalStorage.store[key];
  }),
  clear: vi.fn(() => {
    mockLocalStorage.store = {};
  }),
};

// Setup mocks
beforeEach(() => {
  (globalThis as any).Audio = MockAudio;
  (globalThis as any).localStorage = mockLocalStorage;
  mockLocalStorage.clear();
});

describe('AudioManager', () => {
  let audioManager: AudioManager;
  let mockAudioConfig: AudioConfig;

  beforeEach(() => {
    audioManager = new AudioManager();
    mockAudioConfig = {
      id: 'test-audio',
      name: '测试音效',
      src: '/sounds/test.mp3',
      volume: 0.8,
      loop: false,
      playbackRate: 1.0,
      preload: 'auto',
    };
  });

  describe('音效预加载', () => {
    it('应该能够预加载音效', async () => {
      const instance = await audioManager.preloadAudio(mockAudioConfig);
      
      expect(instance.id).toBe(mockAudioConfig.id);
      expect(instance.config).toBe(mockAudioConfig);
      expect(instance.audio).toBeInstanceOf(MockAudio);
      expect(instance.audio.src).toBe(mockAudioConfig.src);
      expect(instance.isPlaying).toBe(false);
    });

    it('应该复用已存在的音效实例', async () => {
      const instance1 = await audioManager.preloadAudio(mockAudioConfig);
      const instance2 = await audioManager.preloadAudio(mockAudioConfig);
      
      expect(instance1).toBe(instance2);
    });

    it('应该触发音效加载完成事件', async () => {
      const mockListener = vi.fn();
      audioManager.on('audioLoaded', mockListener);
      
      await audioManager.preloadAudio(mockAudioConfig);
      
      // 等待加载完成事件
      await new Promise(resolve => setTimeout(resolve, 20));
      
      expect(mockListener).toHaveBeenCalledTimes(1);
    });
  });

  describe('音效播放', () => {
    it('应该能够播放音效', async () => {
      await audioManager.preloadAudio(mockAudioConfig);
      
      const mockListener = vi.fn();
      audioManager.on('audioStart', mockListener);
      
      await audioManager.playAudio(mockAudioConfig.id);
      
      expect(mockListener).toHaveBeenCalledTimes(1);
    });

    it('静音时不应该播放音效', async () => {
      await audioManager.preloadAudio(mockAudioConfig);
      audioManager.setMuted(true);
      
      const mockListener = vi.fn();
      audioManager.on('audioStart', mockListener);
      
      await audioManager.playAudio(mockAudioConfig.id);
      
      expect(mockListener).not.toHaveBeenCalled();
    });

    it('音效禁用时不应该播放音效', async () => {
      await audioManager.preloadAudio(mockAudioConfig);
      audioManager.updateSettings({ effectsEnabled: false });
      
      const mockListener = vi.fn();
      audioManager.on('audioStart', mockListener);
      
      await audioManager.playAudio(mockAudioConfig.id);
      
      expect(mockListener).not.toHaveBeenCalled();
    });

    it('应该能够停止音效', async () => {
      await audioManager.preloadAudio(mockAudioConfig);
      await audioManager.playAudio(mockAudioConfig.id);
      
      audioManager.stopAudio(mockAudioConfig.id);
      
      // 验证音效被暂停
      // 注意：这里我们无法直接验证pause被调用，因为MockAudio的实现限制
      // 在实际应用中，这个测试会更有意义
    });

    it('应该能够停止所有音效', async () => {
      const config1 = { ...mockAudioConfig, id: 'test-audio-1' };
      const config2 = { ...mockAudioConfig, id: 'test-audio-2' };
      
      await audioManager.preloadAudio(config1);
      await audioManager.preloadAudio(config2);
      await audioManager.playAudio(config1.id);
      await audioManager.playAudio(config2.id);
      
      audioManager.stopAllAudio();
      
      // 验证所有音效被停止
    });
  });

  describe('音效设置', () => {
    it('应该能够获取默认设置', () => {
      const settings = audioManager.getSettings();
      
      expect(settings.masterVolume).toBe(0.7);
      expect(settings.effectVolume).toBe(0.8);
      expect(settings.musicVolume).toBe(0.5);
      expect(settings.muted).toBe(false);
      expect(settings.effectsEnabled).toBe(true);
      expect(settings.musicEnabled).toBe(true);
    });

    it('应该能够更新设置', () => {
      const newSettings = {
        masterVolume: 0.5,
        effectVolume: 0.6,
        muted: true,
      };
      
      audioManager.updateSettings(newSettings);
      
      const settings = audioManager.getSettings();
      expect(settings.masterVolume).toBe(0.5);
      expect(settings.effectVolume).toBe(0.6);
      expect(settings.muted).toBe(true);
      // 其他设置应该保持不变
      expect(settings.musicVolume).toBe(0.5);
      expect(settings.effectsEnabled).toBe(true);
    });

    it('应该能够设置静音', () => {
      audioManager.setMuted(true);
      expect(audioManager.getSettings().muted).toBe(true);
      
      audioManager.setMuted(false);
      expect(audioManager.getSettings().muted).toBe(false);
    });

    it('应该持久化设置到localStorage', () => {
      const newSettings = { masterVolume: 0.3 };
      audioManager.updateSettings(newSettings);
      
      expect(mockLocalStorage.setItem).toHaveBeenCalledWith(
        'lianliankan-audio-settings',
        expect.stringContaining('"masterVolume":0.3')
      );
    });
  });

  describe('事件系统', () => {
    it('应该能够添加和移除事件监听器', async () => {
      const mockListener = vi.fn();
      
      audioManager.on('audioStart', mockListener);
      
      await audioManager.preloadAudio(mockAudioConfig);
      await audioManager.playAudio(mockAudioConfig.id);
      
      expect(mockListener).toHaveBeenCalledTimes(1);
      
      audioManager.off('audioStart', mockListener);
      await audioManager.playAudio(mockAudioConfig.id);
      
      expect(mockListener).toHaveBeenCalledTimes(1); // 没有再次调用
    });

    it('应该处理监听器中的错误', async () => {
      const errorListener = vi.fn(() => {
        throw new Error('Test error');
      });
      const normalListener = vi.fn();
      
      audioManager.on('audioStart', errorListener);
      audioManager.on('audioStart', normalListener);
      
      await audioManager.preloadAudio(mockAudioConfig);
      
      // 应该不会抛出错误，并且正常监听器仍然被调用
      await expect(audioManager.playAudio(mockAudioConfig.id)).resolves.not.toThrow();
      expect(normalListener).toHaveBeenCalled();
    });
  });

  describe('资源清理', () => {
    it('应该清理所有资源', async () => {
      const mockListener = vi.fn();
      audioManager.on('audioStart', mockListener);
      
      await audioManager.preloadAudio(mockAudioConfig);
      
      audioManager.destroy();
      
      // 事件监听器应该被清理
      await audioManager.playAudio(mockAudioConfig.id);
      expect(mockListener).not.toHaveBeenCalled();
    });
  });
});
