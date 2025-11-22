import { INativeBitmap } from './INativeBitmap';

export interface SnapDrawingValdiContextNative {
  brand?: 'SnapDrawingValdiContextNative';
}

export interface SnapDrawingFrameNative {
  brand?: 'SnapDrawingFrameNative';
}

export interface SnapDrawingValdiContext {
  contextId: string;
  native: SnapDrawingValdiContextNative;
}

export const enum AssetTrackerEventType {
  beganRequestingLoadedAsset = 1,
  endRequestingLoadedAsset = 2,
  loadedAssetChange = 3,
}

export type AssetTrackerCallback = (
  eventType: AssetTrackerEventType,
  nodeId: number,
  error: string | undefined,
) => void;

export function createValdiContextWithSnapDrawing(
  useNewExternalSurfaceRasterMethod: boolean,
  enableDeltaRasterization: boolean,
  assetTrackerCallback: AssetTrackerCallback,
): SnapDrawingValdiContext;

export function destroyValdiContextWithSnapDrawing(native: SnapDrawingValdiContextNative): void;

export function drawFrame(native: SnapDrawingValdiContextNative): SnapDrawingFrameNative;

export function disposeFrame(native: SnapDrawingFrameNative): void;

export function rasterFrame(
  native: SnapDrawingFrameNative,
  bitmapNative: INativeBitmap,
  shouldClearBitmapBeforeDrawing: boolean,
  deltaRasterization: boolean,
): void;
