// 连连看图标映射 - 支持主题系统
import { themeManager } from '../themes/ThemeManager';

/**
 * 获取当前主题的图标
 * @param tileId 图标ID (1-based)
 * @returns emoji图标字符串
 */
export function getTileIcon(tileId: number): string {
  return themeManager.getThemeIcon(tileId);
}

/**
 * 获取当前主题的颜色
 * @param tileId 图标ID (1-based)
 * @returns 颜色字符串
 */
export function getTileColor(tileId: number): string {
  return themeManager.getThemeColor(tileId);
}

/**
 * 获取当前主题信息
 */
export function getCurrentTheme() {
  return themeManager.getCurrentTheme();
}

/**
 * 设置主题
 * @param themeId 主题ID
 * @returns 是否设置成功
 */
export function setTheme(themeId: string): boolean {
  return themeManager.setTheme(themeId);
}

/**
 * 获取所有可用主题
 */
export function getAvailableThemes() {
  return themeManager.getAvailableThemes();
}
