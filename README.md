# Extraqtiv

<p align="center">
  <br>
  <em>A powerful Evernote export solution by FRAQTIV</em>
</p>

## Overview

Extraqtiv is a professional-grade desktop application designed for Evernote power users who need comprehensive control over their note archives. This macOS-native tool facilitates complete notebook exports while preserving the integrity of notes, attachments, and metadata.

Key features include:

- **Full-Fidelity Exports**: Generate ENEX or other export formats with complete metadata and attachments intact
- **Local Data Management**: Categorize, batch-edit, and organize notes for offline storage
- **Enhanced Viewing and Analytics**: Advanced searching, filtering, and optional analytics on note content (all performed locally)
- **Security and Privacy**: No external data transmission or storage - all processing happens on your machine

## System Requirements

- macOS 13.0 or later (with SwiftUI support)
- Internet connection (for initial Evernote authentication only)
- Evernote account (Free, Premium, or Business)
- Approximately 200MB of disk space for the application

## Installation

1. Download the latest release from the [Releases page](https://github.com/fraqtiv/extraqtiv/releases)
2. Open the downloaded DMG file
3. Drag Extraqtiv to your Applications folder
4. Launch Extraqtiv from your Applications folder or Launchpad
5. Authenticate with your Evernote account when prompted

## Development Setup

Extraqtiv is built using a modular architecture:

### Project Structure

- **ExtraqtivApp**: The main macOS application built with SwiftUI
- **ExtraqtivCore**: Core library providing Evernote API integration and data processing functionality

### Building the Project

1. Clone the repository:
   ```bash
   git clone https://github.com/fraqtiv/extraqtiv.git
   cd extraqtiv
   ```

2. Open the Xcode project:
   ```bash
   open Extraqtiv.xcodeproj
   ```

3. Select the appropriate scheme (ExtraqtivApp) and run target (My Mac)

4. Build and run the project using Cmd+R or the play button

### Development Guidelines

- Use SwiftUI for all new UI components
- Follow MVVM architecture pattern
- Write unit tests for all core functionality
- Ensure backward compatibility with macOS 13.0+
## Basic Usage

### Initial Setup

1. Launch Extraqtiv
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
4. Use search functionality to quickly locate specific content

## Privacy & Security

Extraqtiv is designed with your data privacy and security as a top priority:

- **Local Processing**: All data processing happens locally on your device
- **No External Servers**: Your notes and credentials are never transmitted to any external servers
- **Evernote API Compliance**: We strictly adhere to Evernote's developer guidelines
- **Authentication Security**: Secure OAuth authentication with no password storage
- **Control Your Data**: You maintain complete control over what is exported and where it's stored

## Support the Project

If you find Extraqtiv helpful, consider supporting its development through Buy Me a Coffee. Your support helps maintain and improve the project!

[![Buy Me A Coffee](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/fraqtiv)

## Support

For issues, feature requests, or general feedback:

- Submit an issue on our [GitHub repository](https://github.com/fraqtiv/extraqtiv/issues)
- Contact our support team at support@fraqtiv.com
- Consider supporting the project through [Buy Me a Coffee](https://www.buymeacoffee.com/fraqtiv)
## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

