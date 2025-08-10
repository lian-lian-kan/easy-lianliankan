// 主题系统类型定义

export interface Theme {
  /** 主题唯一标识符 */
  id: string;
  
  /** 主题显示名称 */
  name: string;
  
  /** 主题描述 */
  description: string;
  
  /** emoji图标数组，用于游戏格子 */
  icons: string[];
  
  /** 对应图标的背景颜色数组 */
  colors: string[];
  
  /** 可选的UI主题颜色配置 */
  uiColors?: {
    /** 主要颜色 */
    primary: string;
    /** 次要颜色 */
    secondary: string;
    /** 背景颜色 */
    background: string;
    /** 选中状态边框颜色 */
    selectedBorder: string;
    /** 按钮颜色 */
    buttonColor: string;
    /** 按钮悬停颜色 */
    buttonHoverColor: string;
  };
}

export interface ThemeConfig {
  /** 默认主题ID */
  defaultTheme: string;
  
  /** 所有可用主题 */
  themes: Theme[];
}

export interface ThemeManagerEvents {
  /** 主题变更事件 */
  themeChanged: (theme: Theme) => void;
}

export type ThemeId = string;

export interface ThemeStorage {
  /** 获取存储的主题ID */
  getStoredThemeId(): ThemeId | null;
  
  /** 存储主题ID */
  setStoredThemeId(themeId: ThemeId): void;
  
  /** 清除存储的主题ID */
  clearStoredThemeId(): void;
}
