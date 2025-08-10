// 音效管理器
import type {
  AudioConfig,
  AudioInstance,
  AudioSettings,
  AudioManagerEvents
} from './types';

// 本地存储实现
class AudioStorage {
  private readonly STORAGE_KEY = 'lianliankan-audio-settings';

  getSettings(): AudioSettings {
    try {
      const stored = localStorage.getItem(this.STORAGE_KEY);
      if (stored) {
        return { ...this.getDefaultSettings(), ...JSON.parse(stored) };
      }
    } catch {
      // 忽略存储错误
    }
    return this.getDefaultSettings();
  }

  setSettings(settings: AudioSettings): void {
    try {
      localStorage.setItem(this.STORAGE_KEY, JSON.stringify(settings));
    } catch {
      // 忽略存储错误
    }
  }

  private getDefaultSettings(): AudioSettings {
    return {
      masterVolume: 0.7,
      effectVolume: 0.8,
      musicVolume: 0.5,
      muted: false,
      effectsEnabled: true,
      musicEnabled: true,
    };
  }
}

// 音效管理器类
export class AudioManager {
  private audioInstances: Map<string, AudioInstance> = new Map();
  private settings: AudioSettings;
  private storage: AudioStorage;
  private eventListeners: Map<keyof AudioManagerEvents, Set<Function>> = new Map();

  constructor() {
    this.storage = new AudioStorage();
    this.settings = this.storage.getSettings();
  }

  /**
   * 预加载音效
   */
  async preloadAudio(config: AudioConfig): Promise<AudioInstance> {
    const existingInstance = this.audioInstances.get(config.id);
    if (existingInstance) {
      return existingInstance;
    }

    const audio = new Audio();
    audio.src = config.src;
    audio.volume = config.volume * this.getEffectiveVolume('effect');
    audio.loop = config.loop;
    audio.playbackRate = config.playbackRate;
    audio.preload = config.preload;

    const instance: AudioInstance = {
      id: config.id,
      config,
      audio,
      isPlaying: false,
      isLoaded: false,
    };

    // 设置事件监听器
    audio.addEventListener('canplaythrough', () => {
      instance.isLoaded = true;
      this.emit('audioLoaded', instance);
    });

    audio.addEventListener('error', () => {
      const error = new Error(`Failed to load audio: ${config.src}`);
      instance.loadError = error;
      this.emit('audioError', instance, error);
    });

    audio.addEventListener('play', () => {
      instance.isPlaying = true;
      this.emit('audioStart', instance);
    });

    audio.addEventListener('ended', () => {
      instance.isPlaying = false;
      this.emit('audioEnd', instance);
    });

    audio.addEventListener('pause', () => {
      instance.isPlaying = false;
    });

    this.audioInstances.set(config.id, instance);

    // 开始加载
    try {
      await audio.load();
    } catch (error) {
      instance.loadError = error as Error;
      this.emit('audioError', instance, error as Error);
    }

    return instance;
  }

  /**
   * 播放音效
   */
  async playAudio(audioId: string): Promise<void> {
    if (this.settings.muted || !this.settings.effectsEnabled) {
      return;
    }

    const instance = this.audioInstances.get(audioId);
    if (!instance) {
      console.warn(`Audio instance not found: ${audioId}`);
      return;
    }

    if (instance.loadError) {
      console.warn(`Audio has load error: ${audioId}`, instance.loadError);
      return;
    }

    try {
      // 重置播放位置
      instance.audio.currentTime = 0;
      
      // 更新音量
      instance.audio.volume = instance.config.volume * this.getEffectiveVolume('effect');
      
      await instance.audio.play();
    } catch (error) {
      console.warn(`Failed to play audio: ${audioId}`, error);
    }
  }

  /**
   * 停止音效
   */
  stopAudio(audioId: string): void {
    const instance = this.audioInstances.get(audioId);
    if (instance && instance.isPlaying) {
      instance.audio.pause();
      instance.audio.currentTime = 0;
    }
  }

  /**
   * 停止所有音效
   */
  stopAllAudio(): void {
    this.audioInstances.forEach(instance => {
      if (instance.isPlaying) {
        instance.audio.pause();
        instance.audio.currentTime = 0;
      }
    });
  }

  /**
   * 获取音效设置
   */
  getSettings(): AudioSettings {
    return { ...this.settings };
  }

  /**
   * 更新音效设置
   */
  updateSettings(newSettings: Partial<AudioSettings>): void {
    this.settings = { ...this.settings, ...newSettings };
    this.storage.setSettings(this.settings);
    
    // 更新所有音效实例的音量
    this.audioInstances.forEach(instance => {
      const audioType = this.getAudioType(instance.config.id);
      instance.audio.volume = instance.config.volume * this.getEffectiveVolume(audioType);
    });
  }

  /**
   * 设置静音
   */
  setMuted(muted: boolean): void {
    this.updateSettings({ muted });
  }

  /**
   * 获取有效音量
   */
  private getEffectiveVolume(type: 'effect' | 'music'): number {
    if (this.settings.muted) return 0;
    
    const typeVolume = type === 'effect' ? this.settings.effectVolume : this.settings.musicVolume;
    return this.settings.masterVolume * typeVolume;
  }

  /**
   * 根据音效ID判断音效类型
   */
  private getAudioType(audioId: string): 'effect' | 'music' {
    return audioId.includes('background') ? 'music' : 'effect';
  }

  /**
   * 添加事件监听器
   */
  on<K extends keyof AudioManagerEvents>(
    event: K,
    listener: AudioManagerEvents[K]
  ): void {
    if (!this.eventListeners.has(event)) {
      this.eventListeners.set(event, new Set());
    }
    this.eventListeners.get(event)!.add(listener);
  }

  /**
   * 移除事件监听器
   */
  off<K extends keyof AudioManagerEvents>(
    event: K,
    listener: AudioManagerEvents[K]
  ): void {
    const listeners = this.eventListeners.get(event);
    if (listeners) {
      listeners.delete(listener);
    }
  }

  /**
   * 触发事件
   */
  private emit<K extends keyof AudioManagerEvents>(
    event: K,
    ...args: Parameters<AudioManagerEvents[K]>
  ): void {
    const listeners = this.eventListeners.get(event);
    if (listeners) {
      listeners.forEach(listener => {
        try {
          (listener as any)(...args);
        } catch (error) {
          console.error(`Error in audio event listener:`, error);
        }
      });
    }
  }

  /**
   * 清理资源
   */
  destroy(): void {
    this.stopAllAudio();
    this.audioInstances.clear();
    this.eventListeners.clear();
  }
}

// 创建全局音效管理器实例
export const audioManager = new AudioManager();
