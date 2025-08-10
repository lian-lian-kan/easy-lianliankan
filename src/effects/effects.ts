// 特效配置文件
import type { ThemeEffects } from './types';

// 水果主题特效
const fruitEffects: ThemeEffects = {
  themeId: 'fruit',
  eliminateEffect: {
    id: 'fruit-eliminate',
    name: '水果消除',
    type: 'particle',
    duration: 800,
    styles: {
      primaryColor: '#4caf50',
      secondaryColor: '#81c784',
      particleCount: 12,
      scale: 1.2,
      opacity: 0.8,
    },
    keyframes: `
      @keyframes fruit-eliminate {
        0% { transform: scale(1) rotate(0deg); opacity: 1; }
        50% { transform: scale(1.2) rotate(180deg); opacity: 0.8; }
        100% { transform: scale(0) rotate(360deg); opacity: 0; }
      }
    `,
    soundPath: '/sounds/fruit-eliminate.mp3',
  },
  selectEffect: {
    id: 'fruit-select',
    name: '水果选中',
    type: 'glow',
    duration: 300,
    styles: {
      primaryColor: '#ff7a00',
      secondaryColor: '#ffab40',
      scale: 1.05,
      opacity: 0.9,
    },
    keyframes: `
      @keyframes fruit-select {
        0% { box-shadow: 0 0 0 rgba(255, 122, 0, 0); }
        50% { box-shadow: 0 0 20px rgba(255, 122, 0, 0.8); }
        100% { box-shadow: 0 0 10px rgba(255, 122, 0, 0.6); }
      }
    `,
  },
};

// 汽车主题特效
const carEffects: ThemeEffects = {
  themeId: 'car',
  eliminateEffect: {
    id: 'car-eliminate',
    name: '汽车消除',
    type: 'animation',
    duration: 600,
    styles: {
      primaryColor: '#2196f3',
      secondaryColor: '#64b5f6',
      particleCount: 8,
      scale: 1.1,
      opacity: 0.9,
    },
    keyframes: `
      @keyframes car-eliminate {
        0% { transform: scale(1) translateX(0); opacity: 1; }
        25% { transform: scale(1.1) translateX(-10px); opacity: 0.8; }
        75% { transform: scale(1.1) translateX(10px); opacity: 0.4; }
        100% { transform: scale(0) translateX(0); opacity: 0; }
      }
    `,
    soundPath: '/sounds/car-eliminate.mp3',
  },
  selectEffect: {
    id: 'car-select',
    name: '汽车选中',
    type: 'bounce',
    duration: 400,
    styles: {
      primaryColor: '#ff5722',
      secondaryColor: '#ff8a65',
      scale: 1.08,
      opacity: 1,
    },
    keyframes: `
      @keyframes car-select {
        0% { transform: scale(1); }
        50% { transform: scale(1.08); }
        100% { transform: scale(1.05); }
      }
    `,
  },
};

// 人物主题特效
const peopleEffects: ThemeEffects = {
  themeId: 'people',
  eliminateEffect: {
    id: 'people-eliminate',
    name: '人物消除',
    type: 'particle',
    duration: 700,
    styles: {
      primaryColor: '#e91e63',
      secondaryColor: '#f06292',
      particleCount: 15,
      scale: 1.3,
      opacity: 0.7,
    },
    keyframes: `
      @keyframes people-eliminate {
        0% { transform: scale(1) rotate(0deg); opacity: 1; filter: hue-rotate(0deg); }
        33% { transform: scale(1.3) rotate(120deg); opacity: 0.7; filter: hue-rotate(120deg); }
        66% { transform: scale(1.1) rotate(240deg); opacity: 0.4; filter: hue-rotate(240deg); }
        100% { transform: scale(0) rotate(360deg); opacity: 0; filter: hue-rotate(360deg); }
      }
    `,
    soundPath: '/sounds/people-eliminate.mp3',
  },
  selectEffect: {
    id: 'people-select',
    name: '人物选中',
    type: 'glow',
    duration: 350,
    styles: {
      primaryColor: '#ff4081',
      secondaryColor: '#ff80ab',
      scale: 1.06,
      opacity: 0.95,
    },
    keyframes: `
      @keyframes people-select {
        0% { box-shadow: 0 0 0 rgba(255, 64, 129, 0); transform: scale(1); }
        50% { box-shadow: 0 0 15px rgba(255, 64, 129, 0.9); transform: scale(1.06); }
        100% { box-shadow: 0 0 8px rgba(255, 64, 129, 0.7); transform: scale(1.03); }
      }
    `,
  },
};

// 化妆品主题特效
const cosmeticEffects: ThemeEffects = {
  themeId: 'cosmetic',
  eliminateEffect: {
    id: 'cosmetic-eliminate',
    name: '化妆品消除',
    type: 'particle',
    duration: 900,
    styles: {
      primaryColor: '#9c27b0',
      secondaryColor: '#ba68c8',
      particleCount: 20,
      scale: 1.4,
      opacity: 0.85,
    },
    keyframes: `
      @keyframes cosmetic-eliminate {
        0% { 
          transform: scale(1) rotate(0deg); 
          opacity: 1; 
          filter: brightness(1) saturate(1);
        }
        25% { 
          transform: scale(1.2) rotate(90deg); 
          opacity: 0.9; 
          filter: brightness(1.2) saturate(1.3);
        }
        50% { 
          transform: scale(1.4) rotate(180deg); 
          opacity: 0.7; 
          filter: brightness(1.5) saturate(1.5);
        }
        75% { 
          transform: scale(1.1) rotate(270deg); 
          opacity: 0.4; 
          filter: brightness(1.8) saturate(2);
        }
        100% { 
          transform: scale(0) rotate(360deg); 
          opacity: 0; 
          filter: brightness(2) saturate(3);
        }
      }
    `,
    soundPath: '/sounds/cosmetic-eliminate.mp3',
  },
  selectEffect: {
    id: 'cosmetic-select',
    name: '化妆品选中',
    type: 'glow',
    duration: 450,
    styles: {
      primaryColor: '#e91e63',
      secondaryColor: '#f48fb1',
      scale: 1.07,
      opacity: 0.92,
    },
    keyframes: `
      @keyframes cosmetic-select {
        0% { 
          box-shadow: 0 0 0 rgba(233, 30, 99, 0); 
          transform: scale(1);
          filter: brightness(1);
        }
        50% { 
          box-shadow: 0 0 25px rgba(233, 30, 99, 0.8); 
          transform: scale(1.07);
          filter: brightness(1.3);
        }
        100% { 
          box-shadow: 0 0 12px rgba(233, 30, 99, 0.6); 
          transform: scale(1.04);
          filter: brightness(1.1);
        }
      }
    `,
  },
};

// 所有主题特效配置
export const themeEffectsConfig: ThemeEffects[] = [
  fruitEffects,
  carEffects,
  peopleEffects,
  cosmeticEffects,
];

// 特效配置映射
export const effectsMap = new Map<string, ThemeEffects>(
  themeEffectsConfig.map(effects => [effects.themeId, effects])
);
