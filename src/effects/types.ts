// 消除特效系统类型定义

export interface EffectConfig {
  /** 特效唯一标识符 */
  id: string;
  
  /** 特效名称 */
  name: string;
  
  /** 特效类型 */
  type: 'particle' | 'animation' | 'glow' | 'bounce';
  
  /** 特效持续时间（毫秒） */
  duration: number;
  
  /** 特效样式配置 */
  styles: {
    /** 主要颜色 */
    primaryColor: string;
    /** 次要颜色 */
    secondaryColor: string;
    /** 粒子数量（仅粒子特效） */
    particleCount?: number;
    /** 动画缩放比例 */
    scale?: number;
    /** 透明度变化 */
    opacity?: number;
  };
  
  /** CSS动画关键帧 */
  keyframes?: string;
  
  /** 特效音效文件路径 */
  soundPath?: string;
}

export interface ThemeEffects {
  /** 主题ID */
  themeId: string;
  
  /** 消除特效配置 */
  eliminateEffect: EffectConfig;
  
  /** 选中特效配置 */
  selectEffect?: EffectConfig;
  
  /** 提示特效配置 */
  hintEffect?: EffectConfig;
}

export interface EffectPosition {
  /** X坐标 */
  x: number;
  
  /** Y坐标 */
  y: number;
  
  /** 宽度 */
  width: number;
  
  /** 高度 */
  height: number;
}

export interface EffectInstance {
  /** 实例ID */
  id: string;
  
  /** 特效配置 */
  config: EffectConfig;
  
  /** 特效位置 */
  position: EffectPosition;
  
  /** 开始时间 */
  startTime: number;
  
  /** 是否正在播放 */
  isPlaying: boolean;
}

export interface EffectManagerEvents {
  /** 特效开始事件 */
  effectStart: (effect: EffectInstance) => void;
  
  /** 特效结束事件 */
  effectEnd: (effect: EffectInstance) => void;
}

export type EffectType = 'eliminate' | 'select' | 'hint';
