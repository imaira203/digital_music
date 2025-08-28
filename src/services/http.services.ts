// src/api/httpCache.ts
import axios, { AxiosInstance, AxiosRequestConfig, AxiosResponse } from 'axios';

type CacheEntry = {
    data: any;
    headers: Record<string, any>;
    status: number;
    statusText: string;
    expiresAt: number;             // epoch ms
    etag?: string;
    lastModified?: string;
};

const cache = new Map<string, CacheEntry>();

function keyOf(cfg: AxiosRequestConfig) {
    const m = (cfg.method || 'get').toUpperCase();
    const u = cfg.baseURL ? new URL(cfg.url!, cfg.baseURL).toString() : cfg.url!;
    // params ảnh hưởng dữ liệu → phải đưa vào key
    const p = cfg.params ? JSON.stringify(cfg.params) : '';
    // body GET thường không có; nếu cần bạn có thể thêm cfg.data
    return `${m}:${u}?${p}`;
}

function parseTTL(headers: Record<string, any>, now = Date.now()): {
    ttlSec: number | null;
    noStore: boolean;
    noCache: boolean;
    mustRevalidate: boolean;
} {
    const h = Object.fromEntries(Object.entries(headers || {}).map(([k, v]) => [k.toLowerCase(), v]));
    const cc = (h['cache-control'] as string) || '';
    const noStore = /no-store/i.test(cc);
    const noCache = /no-cache/i.test(cc);
    const mustRevalidate = /must-revalidate/i.test(cc);

    let ttlSec: number | null = null;

    const m = cc.match(/max-age=(\d+)/i);
    if (m) {
        let maxAge = parseInt(m[1], 10);
        const ageHdr = parseInt(h['age'] ?? '0', 10);
        if (!Number.isNaN(ageHdr) && ageHdr > 0) maxAge = Math.max(0, maxAge - ageHdr);
        ttlSec = maxAge;
    } else if (h['expires']) {
        const ts = new Date(h['expires']).getTime();
        if (!Number.isNaN(ts)) ttlSec = Math.max(0, Math.floor((ts - now) / 1000));
    }

    return { ttlSec, noStore, noCache, mustRevalidate };
}

// public helpers
export function clearHttpCache(urlPrefix?: string) {
    if (!urlPrefix) {
        cache.clear();
        return;
    }
    for (const k of [...cache.keys()]) {
        if (k.includes(urlPrefix)) cache.delete(k);
    }
}

export const http: AxiosInstance = axios.create();

// Attach interceptors
http.interceptors.request.use(async (cfg) => {
    if ((cfg.method || 'get').toLowerCase() !== 'get') return cfg;

    const k = keyOf(cfg);
    const entry = cache.get(k);
    const now = Date.now();

    if (entry && entry.expiresAt > now) {
        // serve from cache
        const resp: AxiosResponse = {
            data: entry.data,
            status: entry.status,
            statusText: entry.statusText,
            headers: entry.headers,
            config: cfg,
            request: undefined,
        };
        // trick: axios cho phép trả Promise.reject/resolve ở request? Trong request interceptor
        // ta trả một object đặc biệt để skip network: dùng adapter custom.
        // Đơn giản hơn: gắn cờ để response interceptor trả cache ngay.
        (cfg as any)._serveFromCache = resp;
        return cfg;
    }

    // hết hạn → nếu có ETag/Last-Modified thì revalidate
    if (entry) {
        cfg.headers = cfg.headers ?? {};
        if (entry.etag) (cfg.headers as any)['If-None-Match'] = entry.etag;
        if (entry.lastModified) (cfg.headers as any)['If-Modified-Since'] = entry.lastModified;
        (cfg as any)._cacheKey = k;
    } else {
        (cfg as any)._cacheKey = k;
    }

    return cfg;
});

http.interceptors.response.use(
    (resp) => {
        // nếu request interceptor đã chuẩn bị sẵn cached response còn hạn → trả luôn
        const pre = (resp.config as any)._serveFromCache as AxiosResponse | undefined;
        if (pre) return pre;

        const cfg = resp.config as any;
        const k = cfg._cacheKey as string | undefined;
        if (!k || (resp.config.method || 'get').toLowerCase() !== 'get') return resp;

        const { ttlSec, noStore } = parseTTL(resp.headers);

        if (!noStore) {
            const etag = (resp.headers as any)['etag'] as string | undefined;
            const lastModified = (resp.headers as any)['last-modified'] as string | undefined;
            const expiresAt = Date.now() + Math.max(0, (ttlSec ?? 0)) * 1000;

            cache.set(k, {
                data: resp.data,
                headers: resp.headers,
                status: resp.status,
                statusText: resp.statusText,
                expiresAt,
                etag,
                lastModified,
            });
        } else {
            cache.delete(k);
        }

        return resp;
    },
    async (error) => {
        const cfg = (error?.config || {}) as any;
        const k = cfg._cacheKey as string | undefined;
        const status = error?.response?.status;

        // 304 Not Modified → trả lại cache
        if (status === 304 && k && cache.has(k)) {
            const entry = cache.get(k)!;
            // gia hạn theo header mới (nếu có)
            const { ttlSec } = parseTTL(error.response.headers || {});
            if (ttlSec != null) entry.expiresAt = Date.now() + ttlSec * 1000;

            return {
                data: entry.data,
                status: entry.status,
                statusText: entry.statusText,
                headers: entry.headers,
                config: error.config,
                request: error.request,
            } as AxiosResponse;
        }

        // nếu network fail mà còn cache (dù hết hạn) → fallback best-effort
        if (k && cache.has(k)) {
            const entry = cache.get(k)!;
            return {
                data: entry.data,
                status: entry.status,
                statusText: entry.statusText,
                headers: entry.headers,
                config: error.config,
                request: error.request,
            } as AxiosResponse;
        }

        return Promise.reject(error);
    }
);
