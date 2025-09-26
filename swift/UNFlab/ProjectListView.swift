import SwiftUI

struct ProjectListView: View {
    @State private var projects: [Project] = [
        Project(name: "Wedding_2024_Johnson", lastCheckpoint: "2 hours ago", checkedOutBy: "scott"),
        Project(name: "Corporate_Video_Q4", lastCheckpoint: "1 day ago", checkedOutBy: "alex"),
        Project(name: "Music_Video_Artist", lastCheckpoint: "3 days ago", checkedOutBy: "mike")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Checked Out Projects")
                .font(.title2)
                .fontWeight(.semibold)
            
            if projects.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No projects currently checked out")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(projects) { project in
                    ProjectDetailRowView(project: project)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
                .listStyle(PlainListStyle())
            }
        }
        .padding()
    }
}

struct ProjectDetailRowView: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.headline)
                        .fontWeight(.medium)
                    Text("Checked out by \(project.checkedOutBy)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Last Autosave")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(project.lastCheckpoint)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    // Dummy action - will be implemented later
                    print("Open \(project.name) in Finder")
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                        Text("Open in Finder")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    // Dummy action - will be implemented later
                    print("Check In \(project.name)")
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle")
                        Text("Check In")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .foregroundColor(.orange)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(8)
    }
}

#Preview {
    ProjectListView()
        .frame(width: 500, height: 400)
}
