import { Platform } from 'react-native';

export const Constants = {
    // baseUrl: Platform.OS === 'web' ?
    //     'http://localhost:8789' :
    //     'http://10.0.2.2:8789',
    baseUrl: 'http://69.176.84.185:8789',
    appName: 'Digital Music',
    version: '1.0.0',
};

export const Colors = {
    primary: '#ff0000',
    secondary: '#333333',
    background: '#1a1a1a',
    surface: '#2a2a2a',
    text: '#ffffff',
    textSecondary: '#cccccc',
    accent: '#ff4444',
    error: '#ff0000',
    success: '#00ff00',
    warning: '#ffaa00',
};

export const Spacing = {
    xs: 4,
    sm: 8,
    md: 16,
    lg: 24,
    xl: 32,
    xxl: 48,
};

export const FontSizes = {
    xs: 12,
    sm: 14,
    md: 16,
    lg: 18,
    xl: 20,
    xxl: 24,
    xxxl: 32,
};
