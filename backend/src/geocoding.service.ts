import {
  BadGatewayException,
  BadRequestException,
  Injectable,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";

import { DatabaseService } from "./database.service";

export interface ResolvedLocation {
  name: string;
  latitude: number;
  longitude: number;
}

interface NominatimResult {
  display_name?: string;
  lat?: string;
  lon?: string;
}

@Injectable()
export class GeocodingService {
  private requestQueue: Promise<void> = Promise.resolve();
  private lastRequestAt = 0;

  constructor(
    private readonly db: DatabaseService,
    private readonly config: ConfigService,
  ) {}

  async search(locationName: string): Promise<ResolvedLocation> {
    const query = locationName.trim().replace(/\s+/g, " ");
    if (query.length < 3)
      throw new BadRequestException("Enter a more specific delivery location");
    const cacheKey = `search:${query.toLowerCase()}`;
    const cached = await this.cached(cacheKey);
    if (cached) return cached;

    const parameters = new URLSearchParams({
      q: query,
      format: "jsonv2",
      limit: "1",
      addressdetails: "1",
      countrycodes: "rw",
      "accept-language": "en",
    });
    const results = await this.request<NominatimResult[]>(
      `/search?${parameters.toString()}`,
    );
    if (!results[0])
      throw new BadRequestException(
        "Location not found in Rwanda. Add a district, sector or nearby landmark.",
      );
    return this.persist(cacheKey, query, results[0]);
  }

  async reverse(
    latitude: number,
    longitude: number,
  ): Promise<ResolvedLocation> {
    const cacheKey = `reverse:${latitude.toFixed(5)},${longitude.toFixed(5)}`;
    const cached = await this.cached(cacheKey);
    if (cached) return cached;

    const parameters = new URLSearchParams({
      lat: latitude.toString(),
      lon: longitude.toString(),
      format: "jsonv2",
      addressdetails: "1",
      zoom: "18",
      "accept-language": "en",
    });
    const result = await this.request<NominatimResult>(
      `/reverse?${parameters.toString()}`,
    );
    if (!result.display_name)
      throw new BadRequestException(
        "We could not identify that location. Enter a nearby landmark instead.",
      );
    return this.persist(cacheKey, cacheKey, result);
  }

  private async cached(cacheKey: string) {
    const result = await this.db.query<{
      name: string;
      latitude: string | number;
      longitude: string | number;
    }>(
      'SELECT display_name AS name,latitude,longitude FROM geocoding_cache WHERE cache_key=$1',
      [cacheKey],
    );
    const row = result.rows[0];
    return row
      ? {
          name: row.name,
          latitude: Number(row.latitude),
          longitude: Number(row.longitude),
        }
      : null;
  }

  private async persist(
    cacheKey: string,
    query: string,
    result: NominatimResult,
  ): Promise<ResolvedLocation> {
    const latitude = Number(result.lat);
    const longitude = Number(result.lon);
    const name = result.display_name?.trim();
    if (
      !name ||
      !Number.isFinite(latitude) ||
      latitude < -90 ||
      latitude > 90 ||
      !Number.isFinite(longitude) ||
      longitude < -180 ||
      longitude > 180
    )
      throw new BadGatewayException("The location provider returned invalid data");
    await this.db.query(
      "INSERT INTO geocoding_cache(cache_key,query,display_name,latitude,longitude,provider,updated_at) VALUES($1,$2,$3,$4,$5,'nominatim',now()) ON CONFLICT(cache_key) DO UPDATE SET display_name=$3,latitude=$4,longitude=$5,updated_at=now()",
      [cacheKey, query, name, latitude, longitude],
    );
    if (cacheKey.startsWith("search:")) {
      const canonicalKey = `search:${name.toLowerCase().replace(/\s+/g, " ")}`;
      if (canonicalKey !== cacheKey)
        await this.db.query(
          "INSERT INTO geocoding_cache(cache_key,query,display_name,latitude,longitude,provider,updated_at) VALUES($1,$2,$3,$4,$5,'nominatim',now()) ON CONFLICT(cache_key) DO UPDATE SET display_name=$3,latitude=$4,longitude=$5,updated_at=now()",
          [canonicalKey, name, name, latitude, longitude],
        );
    }
    return { name, latitude, longitude };
  }

  private async request<T>(path: string): Promise<T> {
    const previous = this.requestQueue;
    let release = () => {};
    this.requestQueue = new Promise<void>((resolve) => {
      release = resolve;
    });
    await previous;
    try {
      const remaining = Math.max(0, 1000 - (Date.now() - this.lastRequestAt));
      if (remaining)
        await new Promise((resolve) => setTimeout(resolve, remaining));
      const baseUrl = this.config
        .get("GEOCODING_BASE_URL", "https://nominatim.openstreetmap.org")
        .replace(/\/$/, "");
      const userAgent = this.config.get(
        "GEOCODING_USER_AGENT",
        "MimiStore/1.0 (https://mimi-store-delta.vercel.app)",
      );
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 10_000);
      try {
        const response = await fetch(`${baseUrl}${path}`, {
          headers: {
            Accept: "application/json",
            "Accept-Language": "en",
            "User-Agent": userAgent,
          },
          signal: controller.signal,
        });
        if (!response.ok)
          throw new BadGatewayException(
            `Location provider unavailable (${response.status})`,
          );
        return (await response.json()) as T;
      } finally {
        clearTimeout(timeout);
      }
    } catch (error) {
      if (
        error instanceof BadRequestException ||
        error instanceof BadGatewayException
      )
        throw error;
      throw new BadGatewayException(
        "Location lookup is temporarily unavailable. Please try again.",
      );
    } finally {
      this.lastRequestAt = Date.now();
      release();
    }
  }
}
