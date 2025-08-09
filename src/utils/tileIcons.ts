// 连连看图标映射
export function getTileIcon(tileId: number): string {
  const icons = [
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
  ];
  
  if (tileId <= 0 || tileId > icons.length) {
    return '';
  }
  
  return icons[tileId - 1];
}

export function getTileColor(tileId: number): string {
  const colors = [
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
  ];
  
  if (tileId <= 0 || tileId > colors.length) {
    return '#f6f7f9';
  }
  
  return colors[tileId - 1];
}
