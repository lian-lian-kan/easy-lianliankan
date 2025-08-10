// 主题配置文件
import type { Theme, ThemeConfig } from './types';
import { effectsMap } from '../effects/effects';
import { audioMap } from '../audio/sounds';

// 水果主题
export const fruitTheme: Theme = {
  id: 'fruit',
  name: '水果',
  description: '新鲜美味的水果主题',
  icons: [
    '🍎', // 1 - 苹果
    '🍊', // 2 - 橙子
    '🍌', // 3 - 香蕉
    '🍇', // 4 - 葡萄
    '🍓', // 5 - 草莓
    '🥝', // 6 - 猕猴桃
    '🍑', // 7 - 樱桃
    '🍒', // 8 - 樱桃(另一种)
    '🥭', // 9 - 芒果
    '🍍', // 10 - 菠萝
    '🥥', // 11 - 椰子
    '🍉', // 12 - 西瓜
    '🍈', // 13 - 哈密瓜
    '🍋', // 14 - 柠檬
    '🥑', // 15 - 牛油果
  ],
  colors: [
    '#ffebee', // 1 - 浅红
    '#fff3e0', // 2 - 浅橙
    '#fffde7', // 3 - 浅黄
    '#f3e5f5', // 4 - 浅紫
    '#ffebee', // 5 - 浅红2
    '#e8f5e8', // 6 - 浅绿
    '#ffebee', // 7 - 浅红3
    '#ffebee', // 8 - 浅红4
    '#fff3e0', // 9 - 浅橙2
    '#fffde7', // 10 - 浅黄2
    '#f5f5f5', // 11 - 浅灰
    '#e8f5e8', // 12 - 浅绿2
    '#e8f5e8', // 13 - 浅绿3
    '#fffde7', // 14 - 浅黄3
    '#e8f5e8', // 15 - 浅绿4
  ],
  uiColors: {
    primary: '#4caf50',
    secondary: '#81c784',
    background: '#ffffff',
    selectedBorder: '#ff7a00',
    buttonColor: '#ffffff',
    buttonHoverColor: '#f5f5f5',
  },
  effects: effectsMap.get('fruit'),
  audio: audioMap.get('fruit'),
};

// 汽车主题
export const carTheme: Theme = {
  id: 'car',
  name: '汽车',
  description: '各种酷炫的汽车主题',
  icons: [
    '🚗', // 1 - 汽车
    '🚕', // 2 - 出租车
    '🚙', // 3 - SUV
    '🚌', // 4 - 公交车
    '🚎', // 5 - 无轨电车
    '🏎️', // 6 - 赛车
    '🚓', // 7 - 警车
    '🚑', // 8 - 救护车
    '🚒', // 9 - 消防车
    '🚐', // 10 - 面包车
    '🛻', // 11 - 皮卡
    '🚚', // 12 - 卡车
    '🚛', // 13 - 货车
    '🚜', // 14 - 拖拉机
    '🏍️', // 15 - 摩托车
  ],
  colors: [
    '#e3f2fd', // 1 - 浅蓝
    '#fff3e0', // 2 - 浅橙
    '#f3e5f5', // 3 - 浅紫
    '#e8f5e8', // 4 - 浅绿
    '#fff9c4', // 5 - 浅黄绿
    '#ffebee', // 6 - 浅红
    '#e1f5fe', // 7 - 浅青
    '#f1f8e9', // 8 - 浅绿2
    '#ffebee', // 9 - 浅红2
    '#f5f5f5', // 10 - 浅灰
    '#e8eaf6', // 11 - 浅靛蓝
    '#fce4ec', // 12 - 浅粉
    '#e0f2f1', // 13 - 浅青绿
    '#fff8e1', // 14 - 浅琥珀
    '#f3e5f5', // 15 - 浅紫2
  ],
  uiColors: {
    primary: '#2196f3',
    secondary: '#64b5f6',
    background: '#ffffff',
    selectedBorder: '#ff5722',
    buttonColor: '#ffffff',
    buttonHoverColor: '#f5f5f5',
  },
  effects: effectsMap.get('car'),
  audio: audioMap.get('car'),
};

// 人物主题
export const peopleTheme: Theme = {
  id: 'people',
  name: '人物',
  description: '可爱的人物角色主题',
  icons: [
    '👶', // 1 - 婴儿
    '👧', // 2 - 女孩
    '🧒', // 3 - 儿童
    '👦', // 4 - 男孩
    '👩', // 5 - 女人
    '🧑', // 6 - 成人
    '👨', // 7 - 男人
    '👴', // 8 - 老爷爷
    '👵', // 9 - 老奶奶
    '🤱', // 10 - 哺乳
    '👮', // 11 - 警察
    '👷', // 12 - 建筑工人
    '💂', // 13 - 卫兵
    '🕵️', // 14 - 侦探
    '👩‍⚕️', // 15 - 医生
  ],
  colors: [
    '#fce4ec', // 1 - 浅粉
    '#f8bbd9', // 2 - 粉红
    '#e1bee7', // 3 - 浅紫
    '#c5cae9', // 4 - 浅靛蓝
    '#ffcdd2', // 5 - 浅红
    '#dcedc8', // 6 - 浅绿
    '#bbdefb', // 7 - 浅蓝
    '#d7ccc8', // 8 - 浅棕
    '#f8bbd9', // 9 - 粉红2
    '#ffccbc', // 10 - 浅橙
    '#c8e6c9', // 11 - 浅绿2
    '#fff9c4', // 12 - 浅黄
    '#ffcdd2', // 13 - 浅红2
    '#e0e0e0', // 14 - 浅灰
    '#b39ddb', // 15 - 浅紫2
  ],
  uiColors: {
    primary: '#e91e63',
    secondary: '#f06292',
    background: '#ffffff',
    selectedBorder: '#ff4081',
    buttonColor: '#ffffff',
    buttonHoverColor: '#f5f5f5',
  },
  effects: effectsMap.get('people'),
  audio: audioMap.get('people'),
};

// 化妆品主题
export const cosmeticTheme: Theme = {
  id: 'cosmetic',
  name: '化妆品',
  description: '时尚美丽的化妆品主题',
  icons: [
    '💄', // 1 - 口红
    '💋', // 2 - 嘴唇
    '👄', // 3 - 嘴巴
    '💅', // 4 - 指甲油
    '💍', // 5 - 戒指
    '👑', // 6 - 皇冠
    '🎀', // 7 - 蝴蝶结
    '🌸', // 8 - 樱花
    '💐', // 9 - 花束
    '🌺', // 10 - 木槿花
    '🌹', // 11 - 玫瑰
    '💎', // 12 - 钻石
    '👛', // 13 - 钱包
    '👜', // 14 - 手提包
    '🎭', // 15 - 面具
  ],
  colors: [
    '#fce4ec', // 1 - 浅粉
    '#f8bbd9', // 2 - 粉红
    '#ffcdd2', // 3 - 浅红
    '#e1bee7', // 4 - 浅紫
    '#fff3e0', // 5 - 浅橙
    '#fffde7', // 6 - 浅黄
    '#f3e5f5', // 7 - 浅紫2
    '#fce4ec', // 8 - 浅粉2
    '#e8f5e8', // 9 - 浅绿
    '#ffebee', // 10 - 浅红2
    '#fce4ec', // 11 - 浅粉3
    '#e3f2fd', // 12 - 浅蓝
    '#f8bbd9', // 13 - 粉红2
    '#e1bee7', // 14 - 浅紫3
    '#c8e6c9', // 15 - 浅绿2
  ],
  uiColors: {
    primary: '#9c27b0',
    secondary: '#ba68c8',
    background: '#ffffff',
    selectedBorder: '#e91e63',
    buttonColor: '#ffffff',
    buttonHoverColor: '#f5f5f5',
  },
  effects: effectsMap.get('cosmetic'),
  audio: audioMap.get('cosmetic'),
};

// 主题配置
export const themeConfig: ThemeConfig = {
  defaultTheme: 'fruit',
  themes: [fruitTheme, carTheme, peopleTheme, cosmeticTheme],
};

// 导出所有主题的映射
export const themesMap = new Map<string, Theme>(
  themeConfig.themes.map(theme => [theme.id, theme])
);
