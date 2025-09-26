import Foundation

// MARK: - App Configuration Model
struct AppConfig: Codable {
    var serverAddress: String
    var serverPort: String
    var serverPath: String
    
    // Default values
    static let `default` = AppConfig(
        serverAddress: "",
        serverPort: "22",
        serverPath: "~/repositories"
    )
}

// MARK: - Configuration Manager
class ConfigManager: ObservableObject {
    @Published var config: AppConfig
    
    private let configKey = "PostSyncConfig"
    private let configFileName = "config.json"
    
    // File-based storage (similar to current .config file)
    private var configFileURL: URL {
        let dataFolder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("PostSync")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: dataFolder, withIntermediateDirectories: true)
        
        return dataFolder.appendingPathComponent(configFileName)
    }
    
    init() {
        // Try to load from file first, then fall back to UserDefaults, then default
        if let fileConfig = loadFromFile() {
            self.config = fileConfig
        } else if let userDefaultsConfig = loadFromUserDefaults() {
            self.config = userDefaultsConfig
        } else {
            self.config = AppConfig.default
        }
    }
    
    // MARK: - File-based Storage (Recommended)
    func saveToFile() {
        do {
            let data = try JSONEncoder().encode(config)
            try data.write(to: configFileURL)
            print("Config saved to: \(configFileURL.path)")
        } catch {
            print("Failed to save config to file: \(error)")
        }
    }
    
    private func loadFromFile() -> AppConfig? {
        guard FileManager.default.fileExists(atPath: configFileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: configFileURL)
            return try JSONDecoder().decode(AppConfig.self, from: data)
        } catch {
            print("Failed to load config from file: \(error)")
            return nil
        }
    }
    
    // MARK: - UserDefaults Storage (Alternative)
    func saveToUserDefaults() {
        do {
            let data = try JSONEncoder().encode(config)
            UserDefaults.standard.set(data, forKey: configKey)
        } catch {
            print("Failed to save config to UserDefaults: \(error)")
        }
    }
    
    private func loadFromUserDefaults() -> AppConfig? {
        guard let data = UserDefaults.standard.data(forKey: configKey) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(AppConfig.self, from: data)
        } catch {
            print("Failed to load config from UserDefaults: \(error)")
            return nil
        }
    }
    
    // MARK: - Legacy .config file support
    func loadFromLegacyConfig() -> AppConfig? {
        let legacyConfigPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("fcp-git")
            .appendingPathComponent(".config")
        
        guard FileManager.default.fileExists(atPath: legacyConfigPath.path) else {
            return nil
        }
        
        do {
            let content = try String(contentsOf: legacyConfigPath)
            var newConfig = AppConfig.default
            
            for line in content.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
                
                let parts = trimmed.components(separatedBy: "=")
                if parts.count == 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    
                    switch key {
                    case "SERVER_ADDRESS":
                        newConfig.serverAddress = value
                    case "SERVER_PORT":
                        newConfig.serverPort = value
                    case "SERVER_PATH":
                        newConfig.serverPath = value
                    default:
                        break
                    }
                }
            }
            
            return newConfig
        } catch {
            print("Failed to load legacy config: \(error)")
            return nil
        }
    }
    
    // MARK: - Validation
    var isValid: Bool {
        return !config.serverAddress.isEmpty && 
               !config.serverPort.isEmpty && 
               !config.serverPath.isEmpty
    }
    
    // MARK: - Git URL Generation
    func gitURL(for repository: String) -> String {
        return "ssh://git@\(config.serverAddress):\(config.serverPort)/\(config.serverPath)/\(repository).git"
    }
}
