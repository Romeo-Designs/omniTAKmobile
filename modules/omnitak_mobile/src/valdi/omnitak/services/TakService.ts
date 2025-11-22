/**
 * TakService - FFI Bridge to omni-TAK Rust Library
 *
 * Provides TypeScript interface to native omni-TAK functionality including:
 * - TAK server connections (TCP, UDP, TLS, WebSocket)
 * - CoT message sending/receiving
 * - Certificate management
 * - Connection health monitoring
 */

/**
 * @ExportModel({
 *   ios: 'OmniTAKNative',
 *   android: 'com.engindearing.omnitak.native.OmniTAKNative'
 * })
 *
 * Native module interface that will be implemented in:
 * - iOS: Swift/Objective-C wrapper around omnitak-mobile.a
 * - Android: JNI wrapper around libomnitak_mobile.so
 */
export interface OmniTAKNativeModule {
  /**
   * Connect to a TAK server
   * @param config Server connection configuration
   * @returns Connection handle or null on failure
   */
  connect(config: ServerConfig): Promise<number | null>;

  /**
   * Disconnect from a server
   * @param connectionId Connection handle from connect()
   */
  disconnect(connectionId: number): Promise<void>;

  /**
   * Send CoT message to server
   * @param connectionId Connection handle
   * @param cotXml CoT message as XML string
   * @returns true if sent successfully
   */
  sendCot(connectionId: number, cotXml: string): Promise<boolean>;

  /**
   * Register callback for incoming CoT messages
   * @param connectionId Connection handle
   * @param callback Function to call when CoT received
   */
  registerCotCallback(
    connectionId: number,
    callback: (cotXml: string) => void
  ): void;

  /**
   * Get connection status
   * @param connectionId Connection handle
   * @returns Connection status info
   */
  getConnectionStatus(connectionId: number): Promise<ConnectionInfo | null>;

  /**
   * Import certificate bundle
   * @param certPem PEM-encoded certificate
   * @param keyPem PEM-encoded private key
   * @param caPem PEM-encoded CA certificate chain (optional)
   * @returns Certificate ID for use in ServerConfig
   */
  importCertificate(
    certPem: string,
    keyPem: string,
    caPem?: string
  ): Promise<string | null>;

  /**
   * Enroll for a certificate from a TAK server
   * @param serverUrl Full server URL (e.g., https://tak.example.com:8443)
   * @param username Username for authentication
   * @param password Password for authentication
   * @param validityDays Certificate validity period
   * @returns Enrollment result with certificate ID and server info
   */
  enrollCertificate?(
    serverUrl: string,
    username: string,
    password: string,
    validityDays: number
  ): Promise<{
    certificateId: string | null;
    serverInfo?: { hostname: string; port?: number };
    expiresAt?: string;
    error?: string;
  }>;

  /**
   * List all stored certificates
   * @returns Array of certificate info
   */
  listCertificates?(): Promise<Array<{
    id: string;
    name: string;
    commonName: string;
    issuer: string;
    validFrom: string;
    validUntil: string;
    status: 'valid' | 'expiring_soon' | 'expired';
    daysUntilExpiry?: number;
  }>>;

  /**
   * Delete a stored certificate
   * @param certificateId Certificate ID to delete
   * @returns true if successful
   */
  deleteCertificate?(certificateId: string): Promise<boolean>;

  /**
   * Open file picker to select certificate files
   * @param fileType Type of file to select ('pem', 'p12', etc.)
   * @returns File content and metadata
   */
  pickCertificateFile?(fileType: string): Promise<{
    filename: string;
    content: string;
    type: string;
  } | null>;
}

/**
 * @ExportModel({
 *   ios: 'ServerConfig',
 *   android: 'com.engindearing.omnitak.ServerConfig'
 * })
 */
export interface ServerConfig {
  host: string;
  port: number;
  protocol: string;
  useTls: boolean;
  certificateId?: string; // Reference to imported certificate
  reconnect: boolean;
  reconnectDelayMs: number;
}

/**
 * @ExportModel({
 *   ios: 'ConnectionInfo',
 *   android: 'com.engindearing.omnitak.ConnectionInfo'
 * })
 */
export interface ConnectionInfo {
  id: number;
  status: string;
  host: string;
  port: number;
  protocol: string;
  latencyMs: number;
  messagesReceived: number;
  messagesSent: number;
  lastError?: string;
}

/**
 * High-level TakService wrapper around native module
 *
 * Provides TypeScript-friendly API with connection management,
 * automatic reconnection, and CoT event handling.
 */
export class TakService {
  private native: OmniTAKNativeModule | null = null;
  private connections: Map<number, ServerConfig> = new Map();
  private cotCallbacks: Map<number, Set<(xml: string) => void>> = new Map();

  constructor() {
    // Native module will be injected by Valdi's polyglot system
    // For now, we'll use a placeholder
    console.log('TakService initialized');
  }

  /**
   * Initialize the service with native module
   * Called by Valdi after polyglot module is loaded
   */
  initialize(nativeModule: OmniTAKNativeModule): void {
    this.native = nativeModule;
    console.log('TakService native module initialized');
  }

  /**
   * Connect to a TAK server
   */
  async connect(config: ServerConfig): Promise<number | null> {
    if (!this.native) {
      console.error('Native module not initialized');
      return null;
    }

    try {
      const connectionId = await this.native.connect(config);
      if (connectionId !== null) {
        this.connections.set(connectionId, config);
        this.cotCallbacks.set(connectionId, new Set());

        // Register internal callback to distribute to subscribers
        this.native.registerCotCallback(connectionId, (xml: string) => {
          this.handleIncomingCot(connectionId, xml);
        });
      }
      return connectionId;
    } catch (error) {
      console.error('Failed to connect to TAK server:', error);
      return null;
    }
  }

  /**
   * Disconnect from server
   */
  async disconnect(connectionId: number): Promise<void> {
    if (!this.native) return;

    await this.native.disconnect(connectionId);
    this.connections.delete(connectionId);
    this.cotCallbacks.delete(connectionId);
  }

  /**
   * Send CoT message
   */
  async sendCot(connectionId: number, cotXml: string): Promise<boolean> {
    if (!this.native) {
      console.error('Native module not initialized');
      return false;
    }

    return await this.native.sendCot(connectionId, cotXml);
  }

  /**
   * Subscribe to CoT messages from a connection
   */
  onCotReceived(
    connectionId: number,
    callback: (xml: string) => void
  ): () => void {
    const callbacks = this.cotCallbacks.get(connectionId);
    if (callbacks) {
      callbacks.add(callback);
      return () => callbacks.delete(callback);
    }
    return () => {};
  }

  /**
   * Get all active connections
   */
  getConnections(): number[] {
    return Array.from(this.connections.keys());
  }

  /**
   * Get connection status
   */
  async getStatus(connectionId: number): Promise<ConnectionInfo | null> {
    if (!this.native) return null;
    return await this.native.getConnectionStatus(connectionId);
  }

  /**
   * Import certificate for TLS connections
   */
  async importCertificate(
    certPem: string,
    keyPem: string,
    caPem?: string
  ): Promise<string | null> {
    if (!this.native) {
      console.error('Native module not initialized');
      return null;
    }

    return await this.native.importCertificate(certPem, keyPem, caPem);
  }

  /**
   * Enroll for a certificate from a TAK server
   * @param serverUrl Full server URL (e.g., https://tak.example.com:8443)
   * @param username Username for authentication
   * @param password Password for authentication
   * @param validityDays Certificate validity period (default: 365)
   * @returns Certificate ID for use in ServerConfig, or null on failure
   */
  async enrollCertificate(
    serverUrl: string,
    username: string,
    password: string,
    validityDays?: number
  ): Promise<{
    certificateId: string | null;
    serverInfo?: { hostname: string; port?: number };
    expiresAt?: string;
    error?: string;
  }> {
    if (!this.native) {
      console.error('Native module not initialized');
      return { certificateId: null, error: 'Native module not initialized' };
    }

    if (!this.native.enrollCertificate) {
      console.error('Certificate enrollment not supported by native module');
      return { certificateId: null, error: 'Enrollment not supported' };
    }

    try {
      const result = await this.native.enrollCertificate(
        serverUrl,
        username,
        password,
        validityDays || 365
      );

      return result;
    } catch (error) {
      console.error('Certificate enrollment failed:', error);
      return {
        certificateId: null,
        error: error instanceof Error ? error.message : 'Unknown error',
      };
    }
  }

  /**
   * List all stored certificates
   * @returns Array of certificate info objects
   */
  async listCertificates(): Promise<any[]> {
    if (!this.native || !this.native.listCertificates) {
      console.warn('Certificate listing not supported');
      return [];
    }

    try {
      return await this.native.listCertificates();
    } catch (error) {
      console.error('Failed to list certificates:', error);
      return [];
    }
  }

  /**
   * Delete a stored certificate
   * @param certificateId ID of certificate to delete
   * @returns true if successful
   */
  async deleteCertificate(certificateId: string): Promise<boolean> {
    if (!this.native || !this.native.deleteCertificate) {
      console.warn('Certificate deletion not supported');
      return false;
    }

    try {
      return await this.native.deleteCertificate(certificateId);
    } catch (error) {
      console.error('Failed to delete certificate:', error);
      return false;
    }
  }

  /**
   * Internal handler for incoming CoT messages
   */
  private handleIncomingCot(connectionId: number, xml: string): void {
    const callbacks = this.cotCallbacks.get(connectionId);
    if (callbacks) {
      callbacks.forEach((callback) => {
        try {
          callback(xml);
        } catch (error) {
          console.error('Error in CoT callback:', error);
        }
      });
    }
  }
}

// Singleton instance
export const takService = new TakService();
