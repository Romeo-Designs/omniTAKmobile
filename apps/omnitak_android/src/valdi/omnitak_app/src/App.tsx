import React from 'react';
import { App as OmniTAKApp } from '@valdi/omnitak_mobile/App';

/**
 * OmniTAK Android Application Entry Point
 *
 * This is the root component for the Android version of OmniTAK.
 * It imports and renders the main OmniTAK app from the omnitak_mobile module.
 *
 * The OmniTAK app provides:
 * - TAK server connectivity with multi-server support
 * - MapLibre-based tactical mapping
 * - Real-time CoT (Cursor on Target) messaging
 * - Military symbology (MIL-STD-2525)
 * - Server management and settings
 */
export const App: React.FC = () => {
  return <OmniTAKApp />;
};

export default App;
