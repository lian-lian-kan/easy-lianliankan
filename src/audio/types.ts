// 音效系统类型定义

export interface AudioConfig {
  /** 音效唯一标识符 */
  id: string;
  
  /** 音效名称 */
  name: string;
  
  /** 音效文件路径 */
  src: string;
  
  /** 音量 (0-1) */
  volume: number;
  
  /** 是否循环播放 */
  loop: boolean;
  
  /** 播放速率 */
  playbackRate: number;
  
  /** 预加载策略 */
  preload: 'auto' | 'metadata' | 'none';
}

export interface ThemeAudio {
  /** 主题ID */
  themeId: string;
  
  /** 消除音效 */
  eliminateSound: AudioConfig;
  
  /** 选中音效 */
  selectSound?: AudioConfig;
  
  /** 提示音效 */
  hintSound?: AudioConfig;
  
  /** 胜利音效 */
  winSound?: AudioConfig;
  
  /** 背景音乐 */
  backgroundMusic?: AudioConfig;
}

export interface AudioInstance {
  /** 实例ID */
  id: string;
  
  /** 音效配置 */
  config: AudioConfig;
  
  /** HTML Audio元素 */
  audio: HTMLAudioElement;
  
  /** 是否正在播放 */
  isPlaying: boolean;
  
  /** 是否已加载 */
  isLoaded: boolean;
  
  /** 加载错误 */
  loadError?: Error;
}

export interface AudioManagerEvents {
  /** 音效开始播放事件 */
  audioStart: (audio: AudioInstance) => void;
  
  /** 音效播放结束事件 */
  audioEnd: (audio: AudioInstance) => void;
  
  /** 音效加载完成事件 */
  audioLoaded: (audio: AudioInstance) => void;
  
  /** 音效加载错误事件 */
  audioError: (audio: AudioInstance, error: Error) => void;
}

export interface AudioSettings {
  /** 主音量 */
  masterVolume: number;
  
  /** 音效音量 */
  effectVolume: number;
  
  /** 音乐音量 */
  musicVolume: number;
  
  /** 是否静音 */
  muted: boolean;
  
  /** 是否启用音效 */
  effectsEnabled: boolean;
  
  /** 是否启用音乐 */
  musicEnabled: boolean;
}

export type AudioType = 'eliminate' | 'select' | 'hint' | 'win' | 'background';
