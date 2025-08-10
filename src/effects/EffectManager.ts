// 特效管理器
import type { 
  EffectInstance, 
  EffectConfig, 
  EffectPosition, 
  EffectManagerEvents 
} from './types';

// 特效管理器类
export class EffectManager {
  private activeEffects: Map<string, EffectInstance> = new Map();
  private eventListeners: Map<keyof EffectManagerEvents, Set<Function>> = new Map();
  private effectIdCounter = 0;

  /**
   * 播放特效
   */
  playEffect(config: EffectConfig, position: EffectPosition): string {
    const effectId = `effect-${++this.effectIdCounter}`;
    
    const instance: EffectInstance = {
      id: effectId,
      config,
      position,
      startTime: Date.now(),
      isPlaying: true,
    };

    this.activeEffects.set(effectId, instance);
    this.emit('effectStart', instance);

    // 设置定时器，在特效结束时清理
    setTimeout(() => {
      this.endEffect(effectId);
    }, config.duration);

    return effectId;
  }

  /**
   * 结束特效
   */
  endEffect(effectId: string): void {
    const instance = this.activeEffects.get(effectId);
    if (instance) {
      instance.isPlaying = false;
      this.emit('effectEnd', instance);
      this.activeEffects.delete(effectId);
    }
  }

  /**
   * 获取所有活跃的特效
   */
  getActiveEffects(): EffectInstance[] {
    return Array.from(this.activeEffects.values());
  }

  /**
   * 停止所有特效
   */
  stopAllEffects(): void {
    const effectIds = Array.from(this.activeEffects.keys());
    effectIds.forEach(id => this.endEffect(id));
  }

  /**
   * 添加事件监听器
   */
  on<K extends keyof EffectManagerEvents>(
    event: K,
    listener: EffectManagerEvents[K]
  ): void {
    if (!this.eventListeners.has(event)) {
      this.eventListeners.set(event, new Set());
    }
    this.eventListeners.get(event)!.add(listener);
  }

  /**
   * 移除事件监听器
   */
  off<K extends keyof EffectManagerEvents>(
    event: K,
    listener: EffectManagerEvents[K]
  ): void {
    const listeners = this.eventListeners.get(event);
    if (listeners) {
      listeners.delete(listener);
    }
  }

  /**
   * 触发事件
   */
  private emit<K extends keyof EffectManagerEvents>(
    event: K,
    ...args: Parameters<EffectManagerEvents[K]>
  ): void {
    const listeners = this.eventListeners.get(event);
    if (listeners) {
      listeners.forEach(listener => {
        try {
          (listener as any)(...args);
        } catch (error) {
          console.error(`Error in effect event listener:`, error);
        }
      });
    }
  }

  /**
   * 清理资源
   */
  destroy(): void {
    this.stopAllEffects();
    this.eventListeners.clear();
  }
}

// 创建全局特效管理器实例
export const effectManager = new EffectManager();
