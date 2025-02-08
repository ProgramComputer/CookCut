# CookCut: Cooking Video Editing App

CookCut is a specialized video editing application designed for cooking creators to efficiently produce and share engaging culinary content. The platform offers intuitive tools for video editing, collaboration, and analytics to enhance content creation and audience engagement.

## Features

- **Import and Trim Videos**: Easily import raw video clips and trim them to create concise cooking tutorials.
- **Text Overlays and Timers**: Overlay text instructions and timers onto videos to guide viewers through recipes.
- **Audio Enhancements**: Add background music and voiceovers to enhance the viewing experience.
- **Collaboration Tools**: Invite collaborators to edit shared projects and provide feedback.
- **Analytics Dashboard**: View analytics on your videos to understand audience engagement.

## Documentation

The project documentation is organized in the `docs/` directory:

- [`FIREBASE_CHECKLIST.md`](docs/FIREBASE_CHECKLIST.md): Tracks the Firebase setup and configuration progress
- [`CONTEXT.md`](docs/CONTEXT.md): Maintains project context, decisions, and development status
- [`PRD.md`](PRD.md): Product Requirements Document
- [`.cursorrules`](.cursorrules): Flutter development guidelines and best practices

## Getting Started

### Prerequisites

- Flutter SDK
- Dart
- Firebase account

### Installation

1. **Clone the Repository**:

   ```bash
   git clone https://github.com/yourusername/cookcut.git
   cd cookcut
   ```

2. **Install Dependencies**:

   ```bash
   flutter pub get
   ```

3. **Set Up Firebase**:

   - Create a new Firebase project.
   - Add Android and iOS apps to your Firebase project.
   - Download the `google-services.json` file for Android and place it in `android/app/`.
   - Download the `GoogleService-Info.plist` file for iOS and place it in `ios/Runner/`.

4. **Run the App**:

   ```bash
   flutter run
   ```

## Usage

1. **Create a New Project**: Start by creating a new project for your cooking video.
2. **Import Media**: Upload your raw video clips to the project.
3. **Edit Video**: Trim clips, add text overlays, timers, and audio enhancements.
4. **Collaborate**: Invite team members to edit and provide feedback on the project.
5. **Publish and Analyze**: Export your final video and use the analytics dashboard to monitor audience engagement.

## Contributing

We welcome contributions from the community. To contribute:

1. Fork the repository.
2. Create a new branch (`git checkout -b feature/YourFeature`).
3. Commit your changes (`git commit -m 'Add YourFeature'`).
4. Push to the branch (`git push origin feature/YourFeature`).
5. Open a Pull Request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgements

Special thanks to all contributors and the open-source community for their invaluable support. 