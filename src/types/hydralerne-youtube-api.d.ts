declare module '@hydralerne/youtube-api' {
    export interface Format {
        url: string;
        mimeType?: string;
        bitrate?: number;
        audioBitrate?: number;
        width?: number;
        height?: number;
        hasVideo?: boolean;
        hasAudio?: boolean;
        isHLS?: boolean;
        isDashMPD?: boolean;
        contentLength?: number;
        codecs?: string;
    }

    export interface GetDataOptions {
        requestOptions?: {
            headers?: Record<string, string>;
        };
        lang?: string;
        visitorId?: string;
        debug?: boolean;
    }

    export interface GetDataResult {
        formats: Format[];
        fallback: boolean;
    }

    export interface FilterOptions {
        fallback?: boolean;
        customSort?: (a: Format, b: Format) => number;
        minBitrate?: number;
        minResolution?: number;
        codec?: string;
    }

    export function getData(videoId: string, options?: GetDataOptions): Promise<GetDataResult>;
    export function filter(formats: Format[], filterType: string, options?: FilterOptions): Format;
    export function initialize(options?: GetDataOptions, videoId?: string): Promise<string>;
}
