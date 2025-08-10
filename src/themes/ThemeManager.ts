// 主题管理器
import type { Theme, ThemeId, ThemeStorage, ThemeManagerEvents } from './types';
import { themeConfig, themesMap } from './themes';

// 本地存储实现
class LocalThemeStorage implements ThemeStorage {
  private readonly STORAGE_KEY = 'lianliankan-theme';

  getStoredThemeId(): ThemeId | null {
    try {
      return localStorage.getItem(this.STORAGE_KEY);
    } catch {
      return null;
    }
  }

  setStoredThemeId(themeId: ThemeId): void {
    try {
      localStorage.setItem(this.STORAGE_KEY, themeId);
    } catch {
      // 忽略存储错误
    }
  }

  clearStoredThemeId(): void {
    try {
      localStorage.removeItem(this.STORAGE_KEY);
    } catch {
      // 忽略存储错误
    }
  }
}

// 主题管理器类
export class ThemeManager {
  private currentTheme: Theme;
  private storage: ThemeStorage;
  private eventListeners: Map<keyof ThemeManagerEvents, Set<Function>> = new Map();

  constructor(storage?: ThemeStorage) {
    this.storage = storage || new LocalThemeStorage();
    
    // 初始化当前主题
    const storedThemeId = this.storage.getStoredThemeId();
    const initialTheme = storedThemeId && themesMap.has(storedThemeId) 
      ? themesMap.get(storedThemeId)! 
      : themesMap.get(themeConfig.defaultTheme)!;
    
    this.currentTheme = initialTheme;
  }

  /**
   * 获取当前主题
   */
  getCurrentTheme(): Theme {
    return this.currentTheme;
  }

  /**
   * 设置当前主题
   */
  setTheme(themeId: ThemeId): boolean {
    const theme = themesMap.get(themeId);
    if (!theme) {
      console.warn(`Theme with id "${themeId}" not found`);
      return false;
    }

    const previousTheme = this.currentTheme;
    this.currentTheme = theme;
    
    // 保存到存储
    this.storage.setStoredThemeId(themeId);
    
    // 触发事件
    if (previousTheme.id !== theme.id) {
      this.emit('themeChanged', theme);
    }
    
    return true;
  }

  /**
   * 获取所有可用主题
   */
  getAvailableThemes(): Theme[] {
    return themeConfig.themes;
  }

  /**
   * 根据ID获取主题
   */
  getThemeById(themeId: ThemeId): Theme | null {
    return themesMap.get(themeId) || null;
  }

  /**
   * 重置为默认主题
   */
  resetToDefault(): void {
    this.setTheme(themeConfig.defaultTheme);
  }

  /**
   * 获取主题图标
   */
  getThemeIcon(tileId: number): string {
    if (tileId <= 0 || tileId > this.currentTheme.icons.length) {
      return '';
    }
    return this.currentTheme.icons[tileId - 1];
  }

  /**
   * 获取主题颜色
   */
  getThemeColor(tileId: number): string {
    if (tileId <= 0 || tileId > this.currentTheme.colors.length) {
      return '#f6f7f9';
    }
    return this.currentTheme.colors[tileId - 1];
  }

  /**
   * 添加事件监听器
   */
  on<K extends keyof ThemeManagerEvents>(
    event: K,
    listener: ThemeManagerEvents[K]
  ): void {
    if (!this.eventListeners.has(event)) {
      this.eventListeners.set(event, new Set());
    }
    this.eventListeners.get(event)!.add(listener);
  }

  /**
   * 移除事件监听器
   */
  off<K extends keyof ThemeManagerEvents>(
    event: K,
    listener: ThemeManagerEvents[K]
  ): void {
    const listeners = this.eventListeners.get(event);
    if (listeners) {
      listeners.delete(listener);
    }
  }

  /**
   * 触发事件
   */
  private emit<K extends keyof ThemeManagerEvents>(
    event: K,
    ...args: Parameters<ThemeManagerEvents[K]>
  ): void {
    const listeners = this.eventListeners.get(event);
    if (listeners) {
      listeners.forEach(listener => {
        try {
          (listener as any)(...args);
        } catch (error) {
          console.error(`Error in theme event listener:`, error);
        }
      });
    }
  }

  /**
   * 清理资源
   */
  destroy(): void {
    this.eventListeners.clear();
  }
}

// 创建全局主题管理器实例
export const themeManager = new ThemeManager();
