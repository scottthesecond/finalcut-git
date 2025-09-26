import SwiftUI

struct MenuBarView: View {
    @State private var checkedOutProjects: [Project] = [
        Project(name: "Wedding_2024_Johnson", lastCheckpoint: "2 hours ago", checkedOutBy: "scott"),
        Project(name: "Corporate_Video_Q4", lastCheckpoint: "1 day ago", checkedOutBy: "alex")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "film")
                    .foregroundColor(.blue)
                Text("PostSync")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("v2.2.1")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Project List
            if checkedOutProjects.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No projects checked out")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(checkedOutProjects) { project in
                            ProjectRowView(project: project)
                        }
                    }
                    .padding()
                }
            }
            
            Divider()
            
            // Action Buttons
            VStack(spacing: 8) {
                // Check Out Another Project
                Button(action: {
                    // Dummy action - will be implemented later
                    print("Check Out Another Project tapped")
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text("Check Out Another Project")
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Quick Save
                Button(action: {
                    // Dummy action - will be implemented later
                    print("Quick Save tapped")
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle")
                        Text("Quick Save")
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Setup
                Button(action: {
                    // Dummy action - will be implemented later
                    print("Setup tapped")
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Setup")
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .foregroundColor(.gray)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
        }
        .frame(width: 400, height: 500)
    }
}

struct ProjectRowView: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(project.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("by \(project.checkedOutBy)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Last Autosave: \(project.lastCheckpoint)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            HStack(spacing: 8) {
                // Go To Project
                Button(action: {
                    // Dummy action - will be implemented later
                    print("Go To \(project.name) tapped")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                        Text("Go To")
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Check In
                Button(action: {
                    // Dummy action - will be implemented later
                    print("Check In \(project.name) tapped")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle")
                        Text("Check In")
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
}

struct Project: Identifiable {
    let id = UUID()
    let name: String
    let lastCheckpoint: String
    let checkedOutBy: String
}

#Preview {
    MenuBarView()
}
