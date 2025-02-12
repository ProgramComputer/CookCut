# CookCut Expo Migration PRD

## Overview

CookCut is migrating from Flutter to Expo React Native, with a primary focus on iOS platform while maintaining all existing functionality and improving where possible. This document outlines the migration strategy, architecture decisions, and implementation details.

## File Structure Requirements
All Expo iOS implementation files MUST be located under the `cookcut-expo/` directory to maintain proper project structure and build configuration. This includes:
- Source code
- Configuration files
- Assets
- Environment files
- iOS-specific files (e.g., `GoogleService-Info.plist`)

### Project Structure
```typescript
cookcut-expo/
  ├── app/              // Feature-based organization
  │   ├── features/     // Feature modules
  │   │   ├── auth/     // Authentication
  │   │   ├── projects/ // Video projects
  │   │   └── core/     // Shared functionality
  │   ├── components/   // Shared UI components
  │   ├── hooks/        // Custom hooks
  │   ├── utils/        // Utility functions
  │   ├── constants/    // App constants
  │   └── types/        // TypeScript types
  ├── assets/           // App assets (images, fonts)
  ├── GoogleService-Info.plist  // iOS Firebase config
  ├── app.config.ts     // Expo config
  ├── .env              // Environment variables
  └── package.json      // Dependencies
```

### Technology Stack
- **Framework:** Expo SDK (latest stable)
- **UI Library:** UI Kitten
- **State Management:** Redux Toolkit
- **Navigation:** expo-router
- **Media:** expo-av
- **Storage:** 
  - Supabase (media files)
  - Firebase (metadata, auth)
- **Video Processing:** FFMPEG Server (existing)

### Core Dependencies
```json
{
  "dependencies": {
    "@ui-kitten/components": "latest",
    "@reduxjs/toolkit": "latest",
    "expo": "latest",
    "expo-router": "latest",
    "expo-av": "latest",
    "expo-font": "latest",
    "firebase": "latest",
    "@supabase/supabase-js": "latest",
    "react-native-reanimated": "latest"
  }
}
```

## Feature Migration Plan

### 1. Core Infrastructure
- Environment configuration
- Theme system
- Navigation setup
- State management
- Error handling
- API services

### 2. Authentication
- Firebase Auth integration
- Login/Register flows
- Google Sign-in
- Session management

### 3. Project Management
- Project creation
- Project listing
- Template system
- Collaboration features

### 4. Video Editor
- Video preview
- Timeline scrubbing
- Trimming interface
- Overlay management
- Export system

### 5. Audio Integration
- Jamendo browser
- Audio preview
- Background music
- Volume controls

### 6. Analytics
- Firebase Analytics
- Engagement metrics
- Retention charts
- Performance tracking

## Component Migration

### UI Components
Following the style guide (`STYLE_GUIDE.md`):

#### Theme Implementation
```typescript
// theme/light.ts
const lightTheme = {
  'color-primary-100': '#D2E7F9',
  'color-primary-500': '#0277BD',
  'color-primary-600': '#0288D1',
  'background-basic-1': '#FFFFFF',
  'background-basic-2': '#F5F5F5',
  'background-basic-3': '#EEEEEE',
  'text-basic-color': '#000000',
  'text-hint-color': '#1F1F1F'
};
```

#### Core Components
- Custom Button
- Input Field
- Card
- Dialog
- Loading Overlay
- Error Banner

#### Video Editor Components
- Video Preview
- Timeline
- Tool Panel
- Export Dialog
- Comment System

## State Management

### Redux Structure
```typescript
store/
  ├── auth/
  ├── projects/
  ├── editor/
  ├── comments/
  └── analytics/
```

### Key Slices
- Authentication state
- Project metadata
- Editor state
- Collaboration state
- Media state

## Implementation Details

### Video Editor Features
1. **Core Video Functionality**
   ```typescript
   // Video Preview Component
   const VideoPreview = () => {
     const video = useRef(null);
     return (
       <Video
         ref={video}
         useNativeControls
         resizeMode="contain"
         shouldPlay={false}
         isLooping={false}
         source={{ uri: videoUri }}
       />
     );
   };
   ```

2. **Timeline Implementation**
   ```typescript
   // Timeline with scrubbing
   const Timeline = () => {
     const [position, setPosition] = useState(0);
     return (
       <Reanimated.View style={styles.timeline}>
         <Scrubber
           value={position}
           onScrubbing={(pos) => setPosition(pos)}
         />
       </Reanimated.View>
     );
   };
   ```

3. **FFMPEG Integration**
   ```typescript
   // Video processing service
   const processVideo = async (videoUri: string, command: string) => {
     const response = await fetch(`${FFMPEG_SERVER_URL}/process-url`, {
       method: 'POST',
       body: JSON.stringify({ videoUri, command })
     });
     return handleFFMPEGResponse(response);
   };
   ```

4. **Audio Features**
   ```typescript
   // Jamendo browser with preview
   const AudioBrowser = () => {
     const [playing, setPlaying] = useState(false);
     const audio = useRef(new Audio.Sound());
     
     const playPreview = async (url) => {
       await audio.current.loadAsync({ uri: url });
       await audio.current.playAsync();
     };
     
     return (
       <MusicList
         onPreview={playPreview}
         onSelect={handleMusicSelection}
       />
     );
   };
   ```

5. **Export System**
   ```typescript
   // Export workflow
   const exportProject = async (project: Project) => {
     const exportSession = await initializeExport(project);
     trackProgress(exportSession.id);
     return waitForCompletion(exportSession.id);
   };
   ```

### State Management Implementation

1. **Project State**
   ```typescript
   // projects/slice.ts
   const projectsSlice = createSlice({
     name: 'projects',
     initialState,
     reducers: {
       setCurrentProject: (state, action) => {
         state.current = action.payload;
       },
       updateEditingStatus: (state, action) => {
         state.editingStatus = action.payload;
       }
     }
   });
   ```

2. **Editor State**
   ```typescript
   // editor/slice.ts
   const editorSlice = createSlice({
     name: 'editor',
     initialState,
     reducers: {
       setVideoPosition: (state, action) => {
         state.position = action.payload;
       },
       setSelectedOverlay: (state, action) => {
         state.selectedOverlay = action.payload;
       },
       updateAudioMix: (state, action) => {
         state.audioLevels = action.payload;
       }
     }
   });
   ```

### UI Components Implementation

1. **Video Controls**
   ```typescript
   // Custom video controls with UI Kitten
   const VideoControls = () => {
     return (
       <Layout style={styles.controls}>
         <Button
           appearance="ghost"
           accessoryLeft={PlayIcon}
           onPress={togglePlayback}
         />
         <Slider
           style={styles.progress}
           value={position}
           onChange={handleSeek}
         />
       </Layout>
     );
   };
   ```

2. **Editor Toolbar**
   ```typescript
   const EditorToolbar = () => {
     return (
       <TopNavigation
         title="Video Editor"
         alignment="center"
         accessoryRight={() => (
           <Button onPress={handleExport}>
             Export
           </Button>
         )}
       />
     );
   };
   ```

### Development Process

1. **Initial Setup**
   ```bash
   npx create-expo-app cookcut-expo
   cd cookcut-expo
   npm install
   ```

2. **Environment Setup**
   ```typescript
   // app.config.ts
   export default {
     expo: {
       name: 'CookCut',
       slug: 'cookcut',
       version: '1.0.0',
       plugins: [
         'expo-router',
         'expo-av',
         'expo-font'
       ]
     }
   };
   ```

3. **Feature Implementation Order**
   1. Core setup & navigation
   2. Authentication
   3. Project management
   4. Video editor core
   5. Audio integration
   6. Export system
   7. Collaboration features
   8. Analytics

## Migration Strategy

### Phase 1: Foundation
1. Project setup
2. Core infrastructure
3. Basic navigation
4. Theme system

### Phase 2: Core Features
1. Authentication
2. Project management
3. Basic video playback
4. File management

### Phase 3: Editor
1. Video editor UI
2. Timeline implementation
3. Tool panels
4. Export system

### Phase 4: Advanced Features
1. Audio integration
2. Comments system
3. Analytics
4. Collaboration

### Phase 5: Polish
1. Performance optimization
2. Error handling
3. Loading states
4. Testing

## Questions & Decisions Needed

1. **Performance Monitoring:**
   - Implement Firebase Performance?
   - Add custom performance metrics?

2. **Development Priority:**
   - Which features should be prioritized?
   - Any features to be implemented in later phases?

3. **Testing Strategy:**
   - Unit testing requirements?
   - E2E testing needs?

4. **Deployment:**
   - EAS build configuration?
   - Release strategy?

## Next Steps

1. Initialize Expo project with TypeScript template
2. Set up UI Kitten and theme system
3. Implement core navigation
4. Begin feature migration in order

Note: All features will be implemented as per the current Flutter app, with optimizations where possible using Expo and React Native best practices.

## Timeline

TBD based on team capacity and priorities.

## Implementation Tracking

### Implemented Files
1. **App Entry & Configuration**
   - `App.tsx` - Main application entry with providers setup
   - `app/constants/theme.ts` - Theme configuration and constants

2. **Authentication Flow**
   - `app/screens/SplashScreen.tsx` - Initial loading screen with animations
   - `app/auth/_layout.tsx` - Authentication navigation layout
   - `app/auth/sign-in.tsx` - Sign in screen with email and Google auth
   - `app/auth/sign-up.tsx` - Sign up screen with form validation

3. **State Management**
   - `app/store/index.ts` - Redux store configuration
   - `app/store/slices/authSlice.ts` - Authentication state management
   - `app/store/slices/projectsSlice.ts` - Projects state management
   - `app/store/slices/editorSlice.ts` - Video editor state management

### Pending Implementation
1. **Core Features**
   - Video import and processing
   - Clip management system
   - Audio integration with Jamendo
   - Visual effects and overlays
   - Export functionality

2. **Project Management**
   - Project creation flow
   - Project listing and filtering
   - Project details and settings
   - Collaboration features

3. **Editor Components**
   - Video preview and controls
   - Timeline and scrubbing
   - Text overlay editor
   - Timer overlay editor
   - Audio mixer

4. **Analytics & Sharing**
   - Analytics dashboard
   - Export and sharing options
   - Social media integration

Note: This tracking section will be updated as new components are implemented.

## Platform Focus
- **Target Platform:** iOS
- **Development Environment:** Windows
- **Build Strategy:** Using EAS (Expo Application Services) for iOS builds
- **Testing:** 
  - Development testing on Windows using Android/Web
  - iOS testing through EAS builds
  - Final testing on iOS devices and simulators
- **Design Guidelines:** Following iOS Human Interface Guidelines alongside Material Design
- **Directory Structure:** All Expo iOS files must be under `cookcut-expo/` directory

## Windows Development Considerations

### Development Workflow
1. **Local Development**
   - Development and testing primarily done on Windows using Android/Web
   - Use Expo Go on Android for rapid development
   - Web browser testing for basic functionality

2. **iOS Build Process**
   - iOS builds handled through EAS build service
   - Regular EAS updates required for iOS testing
   - Command reference:
     ```bash
     eas build --platform ios  # For production builds
     eas update --platform ios # For OTA updates
     ```

3. **Testing Strategy**
   - Initial testing on Windows using Android/Web
   - iOS-specific features tested through EAS builds
   - Final validation on iOS devices
   - TestFlight distribution for beta testing

4. **Development Tips**
   - Use platform-specific code when necessary: `Platform.select({ ios: {...}, default: {...} })`
   - Test iOS-specific APIs through EAS builds
   - Maintain iOS-first design approach despite Windows development environment

## Implementation Status

### Completed Features
1. ✅ Project Setup
   - Basic Expo configuration under `cookcut-expo/`
   - Environment variables
   - Firebase iOS configuration
   - TypeScript setup

2. ✅ Core Infrastructure
   - Theme system implementation
   - Navigation setup with expo-router
   - Redux store configuration
   - Basic error handling

3. ✅ Authentication UI
   - Splash screen with animations
   - Sign-in screen with email and Google authentication
   - Sign-up screen with validation
   - Authentication service integration
   - Firebase Auth configuration

### In Progress
1. 🟡 Firebase Integration
   - Complete Google Sign-In for iOS
   - Testing authentication flow
   - User profile management

### Next Steps
1. Project Management
   - Project creation interface
   - Project listing
   - Project details view

2. Video Editor Core
   - Video import
   - Basic playback controls
   - Timeline implementation

3. Testing & Polish
   - iOS simulator testing
   - Device testing
   - Performance optimization 