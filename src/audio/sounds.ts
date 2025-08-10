// 音效配置文件
import type { ThemeAudio, AudioConfig } from './types';

// 创建音效配置的辅助函数
function createAudioConfig(
  id: string,
  name: string,
  filename: string,
  options: Partial<AudioConfig> = {}
): AudioConfig {
  return {
    id,
    name,
    src: `/sounds/${filename}`,
    volume: 0.7,
    loop: false,
    playbackRate: 1.0,
    preload: 'auto',
    ...options,
  };
}

// 水果主题音效
const fruitAudio: ThemeAudio = {
  themeId: 'fruit',
  eliminateSound: createAudioConfig(
    'fruit-eliminate',
    '水果消除音效',
    'fruit-pop.mp3',
    { volume: 0.8 }
  ),
  selectSound: createAudioConfig(
    'fruit-select',
    '水果选中音效',
    'fruit-click.mp3',
    { volume: 0.6 }
  ),
  hintSound: createAudioConfig(
    'fruit-hint',
    '水果提示音效',
    'fruit-hint.mp3',
    { volume: 0.7 }
  ),
  winSound: createAudioConfig(
    'fruit-win',
    '水果胜利音效',
    'fruit-win.mp3',
    { volume: 0.9 }
  ),
};

// 汽车主题音效
const carAudio: ThemeAudio = {
  themeId: 'car',
  eliminateSound: createAudioConfig(
    'car-eliminate',
    '汽车消除音效',
    'car-engine.mp3',
    { volume: 0.7 }
  ),
  selectSound: createAudioConfig(
    'car-select',
    '汽车选中音效',
    'car-beep.mp3',
    { volume: 0.5 }
  ),
  hintSound: createAudioConfig(
    'car-hint',
    '汽车提示音效',
    'car-horn.mp3',
    { volume: 0.6 }
  ),
  winSound: createAudioConfig(
    'car-win',
    '汽车胜利音效',
    'car-victory.mp3',
    { volume: 0.8 }
  ),
};

// 人物主题音效
const peopleAudio: ThemeAudio = {
  themeId: 'people',
  eliminateSound: createAudioConfig(
    'people-eliminate',
    '人物消除音效',
    'people-cheer.mp3',
    { volume: 0.8 }
  ),
  selectSound: createAudioConfig(
    'people-select',
    '人物选中音效',
    'people-tap.mp3',
    { volume: 0.6 }
  ),
  hintSound: createAudioConfig(
    'people-hint',
    '人物提示音效',
    'people-whistle.mp3',
    { volume: 0.7 }
  ),
  winSound: createAudioConfig(
    'people-win',
    '人物胜利音效',
    'people-applause.mp3',
    { volume: 0.9 }
  ),
};

// 化妆品主题音效
const cosmeticAudio: ThemeAudio = {
  themeId: 'cosmetic',
  eliminateSound: createAudioConfig(
    'cosmetic-eliminate',
    '化妆品消除音效',
    'cosmetic-sparkle.mp3',
    { volume: 0.8 }
  ),
  selectSound: createAudioConfig(
    'cosmetic-select',
    '化妆品选中音效',
    'cosmetic-click.mp3',
    { volume: 0.6 }
  ),
  hintSound: createAudioConfig(
    'cosmetic-hint',
    '化妆品提示音效',
    'cosmetic-chime.mp3',
    { volume: 0.7 }
  ),
  winSound: createAudioConfig(
    'cosmetic-win',
    '化妆品胜利音效',
    'cosmetic-fanfare.mp3',
    { volume: 0.9 }
  ),
};

// 通用音效（不依赖主题）
export const commonAudio = {
  backgroundMusic: createAudioConfig(
    'background-music',
    '背景音乐',
    'background.mp3',
    { 
      volume: 0.3, 
      loop: true, 
      preload: 'metadata' 
    }
  ),
  errorSound: createAudioConfig(
    'error',
    '错误音效',
    'error.mp3',
    { volume: 0.6 }
  ),
  buttonClick: createAudioConfig(
    'button-click',
    '按钮点击音效',
    'button-click.mp3',
    { volume: 0.5 }
  ),
};

// 所有主题音效配置
export const themeAudioConfig: ThemeAudio[] = [
  fruitAudio,
  carAudio,
  peopleAudio,
  cosmeticAudio,
];

// 音效配置映射
export const audioMap = new Map<string, ThemeAudio>(
  themeAudioConfig.map(audio => [audio.themeId, audio])
);

// 获取当前主题的音效配置
export function getThemeAudio(themeId: string): ThemeAudio | null {
  return audioMap.get(themeId) || null;
}

// 获取所有音效配置（用于预加载）
export function getAllAudioConfigs(): AudioConfig[] {
  const configs: AudioConfig[] = [];
  
  // 添加主题音效
  themeAudioConfig.forEach(themeAudio => {
    configs.push(themeAudio.eliminateSound);
    if (themeAudio.selectSound) configs.push(themeAudio.selectSound);
    if (themeAudio.hintSound) configs.push(themeAudio.hintSound);
    if (themeAudio.winSound) configs.push(themeAudio.winSound);
    if (themeAudio.backgroundMusic) configs.push(themeAudio.backgroundMusic);
  });
  
  // 添加通用音效
  configs.push(
    commonAudio.backgroundMusic,
    commonAudio.errorSound,
    commonAudio.buttonClick
  );
  
  return configs;
}
