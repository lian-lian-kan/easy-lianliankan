import { describe, it, expect, beforeEach, vi } from 'vitest';
import { ThemeManager } from './ThemeManager';
import type { ThemeStorage } from './types';
import { themeConfig } from './themes';

// Mock storage implementation for testing
class MockThemeStorage implements ThemeStorage {
  private storage = new Map<string, string>();

  getStoredThemeId(): string | null {
    return this.storage.get('lianliankan-theme') || null;
  }

  setStoredThemeId(themeId: string): void {
    this.storage.set('lianliankan-theme', themeId);
  }

  clearStoredThemeId(): void {
    this.storage.delete('lianliankan-theme');
  }

  // Helper method for testing
  clear(): void {
    this.storage.clear();
  }
}

describe('ThemeManager', () => {
  let mockStorage: MockThemeStorage;
  let themeManager: ThemeManager;

  beforeEach(() => {
    mockStorage = new MockThemeStorage();
    mockStorage.clear();
    themeManager = new ThemeManager(mockStorage);
  });

  describe('初始化', () => {
    it('应该使用默认主题初始化', () => {
      const currentTheme = themeManager.getCurrentTheme();
      expect(currentTheme.id).toBe(themeConfig.defaultTheme);
    });

    it('应该从存储中恢复主题', () => {
      mockStorage.setStoredThemeId('car');
      const newManager = new ThemeManager(mockStorage);
      expect(newManager.getCurrentTheme().id).toBe('car');
    });

    it('存储中的无效主题ID应该回退到默认主题', () => {
      mockStorage.setStoredThemeId('invalid-theme');
      const newManager = new ThemeManager(mockStorage);
      expect(newManager.getCurrentTheme().id).toBe(themeConfig.defaultTheme);
    });
  });

  describe('主题切换', () => {
    it('应该能够切换到有效主题', () => {
      const result = themeManager.setTheme('car');
      expect(result).toBe(true);
      expect(themeManager.getCurrentTheme().id).toBe('car');
    });

    it('应该拒绝无效的主题ID', () => {
      const result = themeManager.setTheme('invalid-theme');
      expect(result).toBe(false);
      expect(themeManager.getCurrentTheme().id).toBe(themeConfig.defaultTheme);
    });

    it('应该将主题保存到存储', () => {
      themeManager.setTheme('people');
      expect(mockStorage.getStoredThemeId()).toBe('people');
    });

    it('应该触发主题变更事件', () => {
      const mockListener = vi.fn();
      themeManager.on('themeChanged', mockListener);
      
      themeManager.setTheme('cosmetic');
      
      expect(mockListener).toHaveBeenCalledTimes(1);
      expect(mockListener).toHaveBeenCalledWith(
        expect.objectContaining({ id: 'cosmetic' })
      );
    });

    it('相同主题不应该触发事件', () => {
      const mockListener = vi.fn();
      themeManager.on('themeChanged', mockListener);
      
      const currentThemeId = themeManager.getCurrentTheme().id;
      themeManager.setTheme(currentThemeId);
      
      expect(mockListener).not.toHaveBeenCalled();
    });
  });

  describe('主题数据获取', () => {
    beforeEach(() => {
      themeManager.setTheme('fruit');
    });

    it('应该返回正确的图标', () => {
      const icon = themeManager.getThemeIcon(1);
      expect(icon).toBe('🍎');
    });

    it('应该返回正确的颜色', () => {
      const color = themeManager.getThemeColor(1);
      expect(color).toBe('#ffebee');
    });

    it('无效的tileId应该返回空字符串或默认颜色', () => {
      expect(themeManager.getThemeIcon(0)).toBe('');
      expect(themeManager.getThemeIcon(999)).toBe('');
      expect(themeManager.getThemeColor(0)).toBe('#f6f7f9');
      expect(themeManager.getThemeColor(999)).toBe('#f6f7f9');
    });
  });

  describe('主题查询', () => {
    it('应该返回所有可用主题', () => {
      const themes = themeManager.getAvailableThemes();
      expect(themes).toHaveLength(4);
      expect(themes.map(t => t.id)).toContain('fruit');
      expect(themes.map(t => t.id)).toContain('car');
      expect(themes.map(t => t.id)).toContain('people');
      expect(themes.map(t => t.id)).toContain('cosmetic');
    });

    it('应该根据ID返回主题', () => {
      const theme = themeManager.getThemeById('car');
      expect(theme).not.toBeNull();
      expect(theme!.id).toBe('car');
      expect(theme!.name).toBe('汽车');
    });

    it('无效ID应该返回null', () => {
      const theme = themeManager.getThemeById('invalid');
      expect(theme).toBeNull();
    });
  });

  describe('重置功能', () => {
    it('应该重置为默认主题', () => {
      themeManager.setTheme('car');
      themeManager.resetToDefault();
      expect(themeManager.getCurrentTheme().id).toBe(themeConfig.defaultTheme);
    });
  });

  describe('事件管理', () => {
    it('应该能够移除事件监听器', () => {
      const mockListener = vi.fn();
      themeManager.on('themeChanged', mockListener);
      themeManager.off('themeChanged', mockListener);
      
      themeManager.setTheme('car');
      expect(mockListener).not.toHaveBeenCalled();
    });

    it('应该处理监听器中的错误', () => {
      const errorListener = vi.fn(() => {
        throw new Error('Test error');
      });
      const normalListener = vi.fn();
      
      themeManager.on('themeChanged', errorListener);
      themeManager.on('themeChanged', normalListener);
      
      // 应该不会抛出错误，并且正常监听器仍然被调用
      expect(() => themeManager.setTheme('car')).not.toThrow();
      expect(normalListener).toHaveBeenCalled();
    });
  });

  describe('资源清理', () => {
    it('应该清理所有事件监听器', () => {
      const mockListener = vi.fn();
      themeManager.on('themeChanged', mockListener);
      
      themeManager.destroy();
      themeManager.setTheme('car');
      
      expect(mockListener).not.toHaveBeenCalled();
    });
  });
});
