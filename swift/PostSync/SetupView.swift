import SwiftUI

struct SetupView: View {
    @StateObject private var configManager = ConfigManager()
    @State private var showingSetup = false
    @State private var serverAddress = ""
    @State private var serverPort = "22"
    @State private var serverPath = "~/repositories"
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "gear.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                Text("PostSync Setup")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            // Current Config Status
            if configManager.isValid {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Configuration Complete")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Server: \(configManager.config.serverAddress)")
                        Text("Port: \(configManager.config.serverPort)")
                        Text("Path: \(configManager.config.serverPath)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                }
            } else {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Configuration Required")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                    
                    Text("PostSync needs to be configured before you can use it.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Setup Form
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Server Address")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("e.g., git.example.com", text: $serverAddress)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Server Port")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("22", text: $serverPort)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Server Path")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("~/repositories", text: $serverPath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            
            // Action Buttons
            VStack(spacing: 12) {
                Button(action: saveConfiguration) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("Save Configuration")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                if configManager.isValid {
                    Button(action: {
                        // Dummy action - will be implemented later
                        print("Test Connection tapped")
                    }) {
                        HStack {
                            Image(systemName: "network")
                            Text("Test Connection")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 400, height: 500)
        .onAppear {
            loadCurrentConfig()
        }
        .alert("Setup", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func loadCurrentConfig() {
        serverAddress = configManager.config.serverAddress
        serverPort = configManager.config.serverPort
        serverPath = configManager.config.serverPath
    }
    
    private func saveConfiguration() {
        // Validate input
        guard !serverAddress.isEmpty else {
            alertMessage = "Server address is required"
            showingAlert = true
            return
        }
        
        guard !serverPort.isEmpty else {
            alertMessage = "Server port is required"
            showingAlert = true
            return
        }
        
        guard !serverPath.isEmpty else {
            alertMessage = "Server path is required"
            showingAlert = true
            return
        }
        
        // Update config
        configManager.config.serverAddress = serverAddress
        configManager.config.serverPort = serverPort
        configManager.config.serverPath = serverPath
        
        // Save to file
        configManager.saveToFile()
        
        alertMessage = "Configuration saved successfully!"
        showingAlert = true
    }
}

#Preview {
    SetupView()
}
