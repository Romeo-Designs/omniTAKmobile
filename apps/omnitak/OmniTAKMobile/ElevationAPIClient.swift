//
//  ElevationAPIClient.swift
//  OmniTAKMobile
//
//  Real elevation data API client using Open-Elevation service
//

import Foundation
import CoreLocation

// MARK: - Elevation API Client

class ElevationAPIClient {
    
    static let shared = ElevationAPIClient()
    
    private let baseURL = "https://api.open-elevation.com/api/v1/lookup"
    private let session: URLSession
    private let cache = ElevationCache()
    private var requestQueue: [ElevationRequest] = []
    private var isProcessingQueue = false
    
    // Rate limiting
    private let maxRequestsPerMinute = 30
    private var requestTimestamps: [Date] = []
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Public API
    
    /// Get elevation for a single coordinate
    func getElevation(for coordinate: CLLocationCoordinate2D, useCache: Bool = true) async throws -> Double {
        // Check cache first
        if useCache, let cachedElevation = cache.elevation(for: coordinate) {
            return cachedElevation
        }
        
        // Rate limiting check
        try await enforceRateLimit()
        
        // Make API request
        let elevation = try await fetchElevation(for: [coordinate]).first ?? 0
        
        // Cache result
        cache.setElevation(elevation, for: coordinate)
        
        return elevation
    }
    
    /// Get elevations for multiple coordinates (batch request)
    func getElevations(for coordinates: [CLLocationCoordinate2D], useCache: Bool = true) async throws -> [Double] {
        guard !coordinates.isEmpty else { return [] }
        
        // Check which coordinates are cached
        var results: [Double?] = Array(repeating: nil, count: coordinates.count)
        var uncachedIndices: [Int] = []
        var uncachedCoordinates: [CLLocationCoordinate2D] = []
        
        if useCache {
            for (index, coordinate) in coordinates.enumerated() {
                if let cached = cache.elevation(for: coordinate) {
                    results[index] = cached
                } else {
                    uncachedIndices.append(index)
                    uncachedCoordinates.append(coordinate)
                }
            }
        } else {
            uncachedIndices = Array(0..<coordinates.count)
            uncachedCoordinates = coordinates
        }
        
        // Fetch uncached elevations
        if !uncachedCoordinates.isEmpty {
            // Rate limiting
            try await enforceRateLimit()
            
            // Batch requests in chunks of 100 (API limit)
            let chunkSize = 100
            var fetchedElevations: [Double] = []
            
            for chunk in uncachedCoordinates.chunked(into: chunkSize) {
                let elevations = try await fetchElevation(for: chunk)
                fetchedElevations.append(contentsOf: elevations)
                
                // Small delay between chunks
                if uncachedCoordinates.count > chunkSize {
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                }
            }
            
            // Fill in results and cache
            for (arrayIndex, originalIndex) in uncachedIndices.enumerated() {
                let elevation = fetchedElevations[arrayIndex]
                results[originalIndex] = elevation
                cache.setElevation(elevation, for: coordinates[originalIndex])
            }
        }
        
        return results.compactMap { $0 }
    }
    
    /// Clear the elevation cache
    func clearCache() {
        cache.clear()
    }
    
    // MARK: - Private Methods
    
    private func fetchElevation(for coordinates: [CLLocationCoordinate2D]) async throws -> [Double] {
        // Build request body
        let locations = coordinates.map { coord in
            ["latitude": coord.latitude, "longitude": coord.longitude]
        }
        
        let requestBody: [String: Any] = ["locations": locations]
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Create request
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        // Execute request
        let (data, response) = try await session.data(for: request)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevationError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ElevationError.httpError(httpResponse.statusCode)
        }
        
        // Parse response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let results = json?["results"] as? [[String: Any]] else {
            throw ElevationError.invalidData
        }
        
        // Extract elevations
        var elevations: [Double] = []
        for result in results {
            if let elevation = result["elevation"] as? Double {
                elevations.append(elevation)
            } else {
                elevations.append(0) // Fallback for missing data
            }
        }
        
        return elevations
    }
    
    private func enforceRateLimit() async throws {
        // Clean old timestamps (older than 1 minute)
        let now = Date()
        requestTimestamps = requestTimestamps.filter { now.timeIntervalSince($0) < 60 }
        
        // Check if we've exceeded rate limit
        if requestTimestamps.count >= maxRequestsPerMinute {
            // Calculate wait time
            if let oldest = requestTimestamps.first {
                let waitTime = 60 - now.timeIntervalSince(oldest)
                if waitTime > 0 {
                    print("⚠️ Rate limit reached, waiting \(Int(waitTime))s...")
                    try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                }
            }
            // Clear timestamps after waiting
            requestTimestamps.removeAll()
        }
        
        // Record this request
        requestTimestamps.append(now)
    }
}

// MARK: - Elevation Cache

private class ElevationCache {
    private var cache: [String: CachedElevation] = [:]
    private let cacheExpirationInterval: TimeInterval = 3600 * 24 // 24 hours
    private let gridSize: Double = 0.001 // ~100m resolution for caching
    
    func elevation(for coordinate: CLLocationCoordinate2D) -> Double? {
        let key = cacheKey(for: coordinate)
        
        guard let cached = cache[key] else { return nil }
        
        // Check expiration
        if Date().timeIntervalSince(cached.timestamp) > cacheExpirationInterval {
            cache.removeValue(forKey: key)
            return nil
        }
        
        return cached.elevation
    }
    
    func setElevation(_ elevation: Double, for coordinate: CLLocationCoordinate2D) {
        let key = cacheKey(for: coordinate)
        cache[key] = CachedElevation(elevation: elevation, timestamp: Date())
    }
    
    func clear() {
        cache.removeAll()
    }
    
    private func cacheKey(for coordinate: CLLocationCoordinate2D) -> String {
        // Round to grid for caching nearby coordinates
        let lat = (coordinate.latitude / gridSize).rounded() * gridSize
        let lon = (coordinate.longitude / gridSize).rounded() * gridSize
        return "\(lat),\(lon)"
    }
    
    private struct CachedElevation {
        let elevation: Double
        let timestamp: Date
    }
}

// MARK: - Elevation Request Queue

private struct ElevationRequest {
    let coordinates: [CLLocationCoordinate2D]
    let continuation: CheckedContinuation<[Double], Error>
}

// MARK: - Errors

enum ElevationError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case invalidData
    case rateLimitExceeded
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from elevation service"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .invalidData:
            return "Invalid elevation data received"
        case .rateLimitExceeded:
            return "Rate limit exceeded, please try again later"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Array Extension

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
