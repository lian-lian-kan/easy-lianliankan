import { useState, useEffect, useRef } from 'react';
import './EffectLayer.css';
import type { EffectInstance } from '../effects/types';

type Props = {
  effects: EffectInstance[];
  onEffectEnd?: (effectId: string) => void;
};

export default function EffectLayer({ effects, onEffectEnd }: Props) {
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    // 为每个特效设置定时器，在特效结束时清理
    const timers: number[] = [];

    effects.forEach(effect => {
      if (effect.isPlaying) {
        const timer = setTimeout(() => {
          onEffectEnd?.(effect.id);
        }, effect.config.duration);
        timers.push(timer);
      }
    });

    return () => {
      timers.forEach(timer => clearTimeout(timer));
    };
  }, [effects, onEffectEnd]);

  return (
    <div ref={containerRef} className="effect-layer">
      {effects.map(effect => (
        <EffectElement
          key={effect.id}
          effect={effect}
        />
      ))}
    </div>
  );
}

type EffectElementProps = {
  effect: EffectInstance;
};

function EffectElement({ effect }: EffectElementProps) {
  const { config, position, isPlaying } = effect;
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    // 延迟挂载以触发动画
    const timer = setTimeout(() => setMounted(true), 10);
    return () => clearTimeout(timer);
  }, []);

  // 根据特效类型生成不同的元素
  const renderEffect = () => {
    switch (config.type) {
      case 'particle':
        return renderParticleEffect();
      case 'animation':
        return renderAnimationEffect();
      case 'glow':
        return renderGlowEffect();
      case 'bounce':
        return renderBounceEffect();
      default:
        return renderAnimationEffect();
    }
  };

  const renderParticleEffect = () => {
    const particleCount = config.styles.particleCount || 8;
    const particles = Array.from({ length: particleCount }, (_, i) => (
      <div
        key={i}
        className="effect-particle"
        style={{
          '--particle-delay': `${i * 50}ms`,
          '--particle-angle': `${(360 / particleCount) * i}deg`,
          '--primary-color': config.styles.primaryColor,
          '--secondary-color': config.styles.secondaryColor,
          animationDuration: `${config.duration}ms`,
        } as React.CSSProperties}
      />
    ));

    return (
      <div className="effect-particle-container">
        {particles}
      </div>
    );
  };

  const renderAnimationEffect = () => (
    <div
      className="effect-animation"
      style={{
        '--primary-color': config.styles.primaryColor,
        '--secondary-color': config.styles.secondaryColor,
        '--scale': config.styles.scale || 1,
        '--opacity': config.styles.opacity || 1,
        animationDuration: `${config.duration}ms`,
      } as React.CSSProperties}
    />
  );

  const renderGlowEffect = () => (
    <div
      className="effect-glow"
      style={{
        '--primary-color': config.styles.primaryColor,
        '--secondary-color': config.styles.secondaryColor,
        '--scale': config.styles.scale || 1,
        animationDuration: `${config.duration}ms`,
      } as React.CSSProperties}
    />
  );

  const renderBounceEffect = () => (
    <div
      className="effect-bounce"
      style={{
        '--primary-color': config.styles.primaryColor,
        '--secondary-color': config.styles.secondaryColor,
        '--scale': config.styles.scale || 1,
        animationDuration: `${config.duration}ms`,
      } as React.CSSProperties}
    />
  );

  if (!isPlaying || !mounted) {
    return null;
  }

  return (
    <div
      className={`effect-element effect-element--${config.type}`}
      style={{
        left: position.x,
        top: position.y,
        width: position.width,
        height: position.height,
        pointerEvents: 'none',
        zIndex: 1000,
      }}
    >
      {renderEffect()}
      
      {/* 动态注入CSS关键帧 */}
      {config.keyframes && (
        <style>
          {config.keyframes}
        </style>
      )}
    </div>
  );
}
