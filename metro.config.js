// metro.config.js
const { getDefaultConfig } = require('@expo/metro-config');

module.exports = (async () => {
    const config = await getDefaultConfig(__dirname);

    // Đảm bảo resolver tồn tại
    config.resolver = config.resolver || {};
    config.resolver.extraNodeModules = {
        ...(config.resolver.extraNodeModules || {}),
        stream: require.resolve('stream-browserify'),
        util: require.resolve('util'),
        events: require.resolve('events'),
        process: require.resolve('process/browser'),
        buffer: require.resolve('buffer'),
        querystring: require.resolve('querystring-es3'), // fix @hydralerne/youtube-api
        // Ensure shaka-player UI bundle resolves correctly in Metro on web
        'shaka-player/dist/shaka-player.ui': require.resolve('shaka-player/dist/shaka-player.ui.js'),
    };

    return config;
})();
