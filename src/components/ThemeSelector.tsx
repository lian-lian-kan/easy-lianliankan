import { useState, useEffect } from 'react';
import './ThemeSelector.css';
import type { Theme } from '../themes/types';
import { themeManager } from '../themes/ThemeManager';

type Props = {
  onThemeChange?: (theme: Theme) => void;
};

export default function ThemeSelector({ onThemeChange }: Props) {
  const [currentTheme, setCurrentTheme] = useState<Theme>(themeManager.getCurrentTheme());
  const [isOpen, setIsOpen] = useState(false);
  const availableThemes = themeManager.getAvailableThemes();

  useEffect(() => {
    const handleThemeChange = (theme: Theme) => {
      setCurrentTheme(theme);
      onThemeChange?.(theme);
    };

    themeManager.on('themeChanged', handleThemeChange);
    
    return () => {
      themeManager.off('themeChanged', handleThemeChange);
    };
  }, [onThemeChange]);

  const handleThemeSelect = (themeId: string) => {
    themeManager.setTheme(themeId);
    setIsOpen(false);
  };

  const toggleDropdown = () => {
    setIsOpen(!isOpen);
  };

  return (
    <div className="theme-selector">
      <button 
        className="theme-selector__trigger"
        onClick={toggleDropdown}
        aria-label="选择主题"
      >
        <span className="theme-selector__current-icon">
          {currentTheme.icons[0]}
        </span>
        <span className="theme-selector__current-name">
          {currentTheme.name}
        </span>
        <span className={`theme-selector__arrow ${isOpen ? 'theme-selector__arrow--open' : ''}`}>
          ▼
        </span>
      </button>

      {isOpen && (
        <div className="theme-selector__dropdown">
          <div className="theme-selector__dropdown-header">
            选择主题
          </div>
          <div className="theme-selector__options">
            {availableThemes.map((theme) => (
              <button
                key={theme.id}
                className={`theme-selector__option ${
                  theme.id === currentTheme.id ? 'theme-selector__option--active' : ''
                }`}
                onClick={() => handleThemeSelect(theme.id)}
              >
                <div className="theme-selector__option-icons">
                  {theme.icons.slice(0, 4).map((icon, index) => (
                    <span key={index} className="theme-selector__option-icon">
                      {icon}
                    </span>
                  ))}
                </div>
                <div className="theme-selector__option-info">
                  <div className="theme-selector__option-name">
                    {theme.name}
                  </div>
                  <div className="theme-selector__option-description">
                    {theme.description}
                  </div>
                </div>
                {theme.id === currentTheme.id && (
                  <div className="theme-selector__option-check">
                    ✓
                  </div>
                )}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* 点击外部关闭下拉菜单 */}
      {isOpen && (
        <div 
          className="theme-selector__overlay"
          onClick={() => setIsOpen(false)}
        />
      )}
    </div>
  );
}
