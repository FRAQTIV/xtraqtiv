# xtraqtiv
Evernote integration and data extraction tool

## About
xtraqtiv is a powerful tool that integrates with Evernote to provide advanced data extraction capabilities. Built with SwiftUI for macOS, it offers a seamless experience for managing and processing your Evernote content.

## Project Structure
- `xtraqtivApp`: SwiftUI-based macOS application (UI/UX)
- `xtraqtivCore`: Core business logic and Evernote integration
- `Documentation`: User guides and project documents
- `Scripts`: Development, build, and CI/CD scripts

## Contributing
We welcome contributions from the community! Our project follows a structured development workflow to ensure code quality and maintainability.

### Development Workflow
We maintain a comprehensive [Git Workflow Guide](.github/GIT_WORKFLOW.md) that covers:
- Branch management strategy
- Commit message conventions
- Pull request processes
- Code review guidelines
- Release procedures

Please review our [Contributing Guidelines](CONTRIBUTING.md) before submitting any changes.

## Getting Started
1. Clone the repository
2. Follow setup instructions in the xtraqtivApp/README.md
3. Review the Git Workflow Guide for development practices
4. Check CONTRIBUTING.md for detailed contribution guidelines

- macOS 13.0 or later (with SwiftUI support)
- Internet connection (for initial Evernote authentication only)
- Evernote account (Free, Premium, or Business)
- Approximately 200MB of disk space for the application

## Installation

1. Download the latest release from the [Releases page](https://github.com/FRAQTIV/xtraqtiv/releases)
2. Open the downloaded DMG file
3. Drag xtraqtiv to your Applications folder
4. Launch xtraqtiv from your Applications folder or Launchpad
5. Authenticate with your Evernote account when prompted

## Development Setup

xtraqtiv is built using a modular architecture:

### Project Structure

- **xtraqtivApp**: The main macOS application built with SwiftUI
- **xtraqtivCore**: Core library providing Evernote API integration and data processing functionality

### Building the Project

1. Clone the repository:
   ```bash
   git clone https://github.com/FRAQTIV/xtraqtiv.git
   cd xtraqtiv
   ```

2. Open the Xcode project:
   ```bash
   open xtraqtiv.xcodeproj
   ```

3. Select the appropriate scheme (xtraqtivApp) and run target (My Mac)

4. Build and run the project using Cmd+R or the play button

### Development Guidelines

- Use SwiftUI for all new UI components
- Follow MVVM architecture pattern
- Write unit tests for all core functionality
- Ensure backward compatibility with macOS 13.0+
## Basic Usage

### Initial Setup

1. Launch xtraqtiv
2. Click "Connect to Evernote" and complete the authentication process
3. Wait for your notebooks to sync (initial sync time depends on your library size)

### Exporting Notes

1. Select notebooks or notes to export from the left sidebar
2. Choose your preferred export format (ENEX, HTML, PDF, etc.)
3. Specify destination folder and export options
4. Click "Export" to begin the process
5. View export progress and any warnings/errors

### Managing Local Data

1. Use the "Local Library" tab to view exported content
2. Apply tags, filters, or custom organization to your local archive
3. Perform batch operations (rename, reorganize, tag) as needed
4. Use the search functionality to locate specific content quickly

## Privacy & Security

xtraqtiv is designed with your data privacy and security as a top priority:

- **Local Processing**: All data processing happens locally on your device
- **No External Servers**: Your notes and credentials are never transmitted to any external servers
- **Evernote API Compliance**: We strictly adhere to Evernote's developer guidelines
- **Authentication Security**: Secure OAuth authentication with no password storage
- **Control Your Data**: You maintain complete control over what is exported and where it's stored

## Support the Project

If xtraqtiv is helpful, consider supporting its development through Buy Me a Coffee. Your support helps maintain and improve the project!

[![Buy Me A Coffee](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/fraqtiv)

## Support

For issues, feature requests, or general feedback:

- Submit an issue on our [GitHub repository](https://github.com/FRAQTIV/xtraqtiv/issues)
- Contact our support team at support@fraqtiv.com
- Consider supporting the project through [Buy Me a Coffee](https://www.buymeacoffee.com/fraqtiv)
## License
[License information to be added]

## Contact
[Contact information to be added]
