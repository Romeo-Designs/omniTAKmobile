/**
 * This file uses the Valdi compiler to generate code, but due to depenency cycle must be copied to another module
 * (eg valdi_example), and remove the "@__" annotation prefixes, then copy the generated code back over.
 */

/**
 * @__ExportProxy({ios: 'SCValdiDrawingFontSpecs', android: 'com.snap.valdi.modules.drawing.FontSpecs'})
 */
export interface FontSpecs {
  font: string;
  lineHeight?: number;
}

/**
 * @__ExportProxy
 */
export interface Size {
  width: number;
  height: number;
}

/**
 * @__ExportEnum({ios: 'SCValdiDrawingFontWeight', android: 'com.snap.valdi.modules.drawing.FontWeight'})
 */
export const enum FontWeight {
  LIGHT = 'light',
  NORMAL = 'normal',
  MEDIUM = 'medium',
  DEMI_BOLD = 'demi-bold',
  BOLD = 'bold',
  BLACK = 'black',
}

/**
 * @__ExportEnum({ios: 'SCValdiDrawingFontStyle', android: 'com.snap.valdi.modules.drawing.FontStyle'})
 */
export const enum FontStyle {
  NORMAL = 'normal',
  ITALIC = 'italic',
}

/**
 * @__ExportProxy({ios: 'SCValdiDrawingFont', android: 'com.snap.valdi.modules.drawing.Font'})
 */
export interface Font {
  measureText(text: string, maxWidth?: number, maxHeight?: number, maxLines?: number): Size;
}

/**
 * @__ExportProxy({android: 'com.snap.valdi.modules.drawing.DrawingModule', ios: 'SCValdiDrawingModule'})
 */
export interface DrawingModule {
  getFont(specs: FontSpecs): Font;
  isFontRegistered(fontName: string): boolean;
  registerFont(fontName: string, weight: FontWeight, style: FontStyle, filename: string): void;
}

export interface DrawingModuleProvider {
  // eslint-disable-next-line @typescript-eslint/naming-convention
  Drawing: DrawingModule;
}
