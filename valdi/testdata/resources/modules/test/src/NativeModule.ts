import { RequireFunc } from "valdi_core/src/IModuleLoader";
import { getModuleLoader } from "valdi_core/src/ModuleLoaderGlobal";

declare const require: RequireFunc;

interface NativeModule {
    doSomeMath(l: number, r: number): number;
}

const nativeModule: NativeModule = require('NativeModuleTest');

export function compute(): number {
    return nativeModule.doSomeMath(42, 8);
}

