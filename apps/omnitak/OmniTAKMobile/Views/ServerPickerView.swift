//
//  ServerPickerView.swift
//  OmniTAKMobile
//
//  Server selection view for changing active TAK server connection
//

import SwiftUI

struct ServerPickerView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var takService: TAKService
    @ObservedObject var serverManager = ServerManager.shared
    @State private var selectedServer: TAKServer?
    @State private var isConnecting = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if serverManager.servers.isEmpty {
                        emptyState
                    } else {
                        serverList
                    }
                }
            }
            .navigationTitle("Select Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isConnecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#00BCD4")))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Server List
    
    private var serverList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(serverManager.servers) { server in
                    ServerRowView(
                        server: server,
                        isActive: serverManager.activeServer?.id == server.id,
                        isSelected: selectedServer?.id == server.id,
                        onSelect: {
                            selectServer(server)
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "server.rack")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "#666666"))
            
            VStack(spacing: 8) {
                Text("No Servers Configured")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Add a TAK server in Settings to get started")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#AAAAAA"))
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func selectServer(_ server: TAKServer) {
        selectedServer = server
        isConnecting = true
        
        Task {
            // Disconnect from current server
            await takService.disconnect()
            
            // Wait a moment
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            // Connect to new server
            await takService.reconnect(to: server)
            
            // Update active server
            await MainActor.run {
                serverManager.activeServer = server
                isConnecting = false
                dismiss()
            }
        }
    }
}

// MARK: - Server Row View

struct ServerRowView: View {
    let server: TAKServer
    let isActive: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Status indicator
                Circle()
                    .fill(isActive ? Color(hex: "#00FF00") : Color(hex: "#666666"))
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(server.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("\(server.protocol.rawValue)://\(server.hostname):\(server.port)")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#AAAAAA"))
                }
                
                Spacer()
                
                if isActive {
                    Text("Active")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#00FF00"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "#00FF00").opacity(0.2))
                        .cornerRadius(12)
                }
                
                if isSelected && !isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#00BCD4"))
                }
            }
            .padding()
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color(hex: "#00BCD4") : Color(hex: "#3A3A3A"),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
