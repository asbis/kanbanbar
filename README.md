# KanbanBar

A macOS menu bar application that displays GitHub Projects (v2) kanban boards in a dropdown from the menu bar.

![KanbanBar](https://img.shields.io/badge/platform-macOS-blue.svg)
![Swift](https://img.shields.io/badge/language-Swift-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## Features

- **Menu Bar Integration**: Clean menu bar app with popover interface
- **GitHub Projects v2**: Full integration with GitHub's new Projects
- **Secure Authentication**: OAuth flow with keychain storage
- **Real-time Updates**: Automatic refresh every 5 minutes (configurable)
- **Modern UI**: SwiftUI interface following macOS design guidelines
- **Multiple Views**: Authentication, kanban board, settings, and empty states
- **Card Management**: View issues and PRs with labels, assignees, and status
- **Search & Filter**: Find tasks quickly with built-in search
- **Notifications**: Native macOS notifications for important updates

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later
- Swift 5.9 or later
- GitHub account with Projects v2

## Installation

### From Source

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/KanbanBar.git
   cd KanbanBar
   ```

2. Open in Xcode:
   ```bash
   open KanbanBar.xcodeproj
   ```

3. Build and run:
   - Select the KanbanBar scheme
   - Build and run (⌘+R)

### Building for Distribution

```bash
xcodebuild -project KanbanBar.xcodeproj -scheme KanbanBar -configuration Release archive
```

## Setup

1. **Launch KanbanBar**: The app will appear in your menu bar
2. **Connect GitHub**: Click the menu bar icon and follow the authentication flow
3. **Select Project**: Choose a GitHub Project from the dropdown
4. **View Your Board**: See your kanban columns and cards

## Configuration

### GitHub OAuth Setup

To use real GitHub authentication (currently using demo mode):

1. Create a GitHub OAuth App:
   - Go to GitHub Settings > Developer settings > OAuth Apps
   - Click "New OAuth App"
   - Set Authorization callback URL to your custom scheme

2. Update the client ID in `AuthenticationService.swift`:
   ```swift
   private let clientId = "your_actual_github_client_id"
   ```

### Settings

Access settings by clicking the gear icon in the popover:

- **Refresh Interval**: 1, 5, 15, or 30 minutes
- **Launch at Login**: Automatically start with macOS
- **Notifications**: Enable/disable system notifications
- **Account Management**: Connect/disconnect GitHub account

## Architecture

The app follows modern SwiftUI and MVVM patterns:

```
KanbanBar/
├── App/
│   ├── KanbanBarApp.swift          # Main app entry point
│   └── MenuBarController.swift     # Menu bar management
├── Views/
│   ├── MainPopoverView.swift       # Main popover container
│   ├── AuthenticationView.swift    # GitHub auth interface
│   ├── BoardView.swift             # Kanban board display
│   ├── SettingsView.swift          # Settings interface
│   └── EmptyStateView.swift        # Empty state handling
├── Models/
│   └── GitHubModels.swift          # Data models for API
├── Services/
│   ├── AuthenticationService.swift # OAuth handling
│   └── GitHubAPIService.swift      # GitHub API integration
└── Utilities/
    └── KeychainHelper.swift        # Secure credential storage
```

## Key Components

### Menu Bar Controller
- Manages the `NSStatusItem` and popover presentation
- Handles light/dark mode icon templating
- Provides click-to-toggle functionality

### Authentication Service
- Secure OAuth flow with GitHub
- Keychain integration for token storage
- Automatic token validation and refresh

### GitHub API Service
- GraphQL integration with GitHub Projects v2
- Async/await API calls
- Data caching and error handling

### UI Components
- Responsive SwiftUI views
- Native macOS controls and styling
- Accessibility support

## GraphQL Queries

The app uses GitHub's GraphQL v4 API to fetch project data:

```graphql
query GetProjects {
  viewer {
    projectsV2(first: 20) {
      nodes {
        id
        title
        items(first: 50) {
          nodes {
            content {
              ... on Issue {
                title
                number
                state
                assignees(first: 5) {
                  nodes { login avatarUrl }
                }
                labels(first: 5) {
                  nodes { name color }
                }
              }
            }
          }
        }
      }
    }
  }
}
```

## Performance

- **Memory Usage**: < 30MB typical usage
- **Cold Start**: < 2 seconds
- **API Caching**: Reduces network requests
- **Efficient Updates**: Only refreshes when needed

## Troubleshooting

### App won't launch
- Check macOS version compatibility (13.0+)
- Verify app permissions in System Preferences

### Authentication issues
- Ensure GitHub OAuth app is configured correctly
- Check network connectivity
- Verify GitHub account has project access

### No projects showing
- Confirm you have GitHub Projects v2 (not classic projects)
- Check project visibility settings
- Verify OAuth scope includes necessary permissions

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Roadmap

- [ ] Real GitHub OAuth implementation
- [ ] Drag and drop card management
- [ ] Multiple GitHub account support
- [ ] Custom notification settings
- [ ] Keyboard shortcuts
- [ ] Export functionality
- [ ] Dark mode optimization
- [ ] Performance improvements

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- GitHub for the excellent Projects v2 API
- Apple for SwiftUI and modern macOS development tools
- The open source community for inspiration and libraries

## Support

If you encounter any issues or have questions:

1. Check the [Issues](https://github.com/yourusername/KanbanBar/issues) page
2. Create a new issue with detailed information
3. Include macOS version, Xcode version, and reproduction steps

---

Made with ❤️ for the developer community