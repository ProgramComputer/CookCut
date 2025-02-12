**Project Overview**

CookCut is a video editing Android app tailored for cooking creators, enabling them to efficiently produce and share engaging culinary content. The platform offers intuitive tools for video editing, collaboration, and analytics to enhance content creation and audience engagement.

**User Roles & Core Workflows**

1. As a cooking creator, I want to import and trim raw video clips to create concise cooking tutorials.
2. As a cooking creator, I want to overlay text instructions and timers onto videos to guide viewers through recipes.
3. As a cooking creator, I want to add background music and voiceovers to enhance the viewing experience.
4. As a collaborator, I want to edit shared projects to contribute to content refinement.
5. As a collaborator, I want to comment on specific sections of a video to provide feedback.
6. As a cooking creator, I want to view analytics on my videos to understand audience engagement.

**Technical Foundation**

*Data Models & Storage Architecture*

- **User** (Firestore)
  - Fields: user_id, username, email, profile_picture_url, created_at
  - Relationships: One-to-many with Project

- **Project** (Firestore)
  - Fields: project_id, user_id, title, description, created_at, updated_at
  - Relationships: Many-to-one with User; One-to-many with MediaAsset, EditSession, and Clip

- **Clip** (Firestore)
  - Fields: clip_id, project_id, original_file_url, start_time, end_time, position, layer, effects[], status, created_at, updated_at, created_by
  - Relationships: Many-to-one with Project; Many-to-one with User

- **MediaAsset** (Supabase Storage)
  - Fields: asset_id, project_id, type, file_url, uploaded_at
  - Storage: Raw videos and processed videos stored in Supabase buckets
  - Metadata: Stored in Firestore
  - Relationships: Many-to-one with Project

- **EditSession**
  - Fields: session_id, project_id, changes, started_at, ended_at
  - Relationships: Many-to-one with Project

- **Collaborator**
  - Fields: collaborator_id, project_id, user_id, role
  - Relationships: Many-to-one with Project; Many-to-one with User

- **Analytics**
  - Fields: analytics_id, project_id, views, engagement_rate, platform, recorded_at
  - Relationships: Many-to-one with Project

*Storage Architecture*

1. **Supabase Storage**
   - Bucket: `cookcut-media`
   - Structure:
     ```
     cookcut-media/
     ├── <project-id>/
     │   └── media/
     │       ├── thumbnails/    # Video thumbnails and previews
     │       ├── raws/          # Original uploaded videos
     │       └── processed/     # Processed/compressed videos
     ```
   - Access Control:
     - Public read access for processed videos
     - Private access for raw uploads
     - Thumbnails cached at CDN level

2. **Firestore**
   - User data
   - Project metadata
   - Clip metadata
   - Collaboration data
   - Real-time session data

3. **FFMPEG EC2 Instance**
   - Temporary video processing
   - No permanent storage
   - Used only during active editing/processing

*API Endpoints*

1. **User Management**
   - POST /api/users/register
   - POST /api/users/login
   - GET /api/users/profile
   - PUT /api/users/profile

2. **Project Management**
   - GET /api/projects
   - POST /api/projects
   - GET /api/projects/{project_id}
   - PUT /api/projects/{project_id}
   - DELETE /api/projects/{project_id}

3. **Media Asset Management**
   - POST /api/projects/{project_id}/media
   - GET /api/projects/{project_id}/media/{asset_id}
   - DELETE /api/projects/{project_id}/media/{asset_id}
   - POST /api/projects/{project_id}/clips
   - GET /api/projects/{project_id}/clips
   - PUT /api/projects/{project_id}/clips/{clip_id}
   - DELETE /api/projects/{project_id}/clips/{clip_id}

4. **Collaboration Management**
   - POST /api/projects/{project_id}/collaborators
   - DELETE /api/projects/{project_id}/collaborators/{collaborator_id}

5. **Analytics**
   - GET /api/projects/{project_id}/analytics

*Key Components*

1. **Authentication Pages**
   - LoginPage
   - RegisterPage

2. **Dashboard**
   - DashboardPage
   - ProjectListComponent
   - CreateProjectButton

3. **Project Management**
   - ProjectDetailPage
   - MediaAssetListComponent
   - AddMediaAssetButton
   - EditSessionComponent

4. **Media Editing**
   - VideoEditorComponent
   - CaptionEditorComponent
   - OverlayEditorComponent

5. **Collaboration**
   - CollaboratorManagementComponent
   - AddCollaboratorForm

6. **Analytics**
   - AnalyticsPage
   - EngagementChartComponent

**MVP Launch Requirements**

1. User registration and authentication system.
2. Dashboard displaying user projects.
3. Ability to create, edit, and delete projects.
4. Functionality to upload, view, and delete media assets within projects.
5. Basic video editing tools: trimming, text overlays, and audio addition.
6. Collaboration feature allowing users to invite others to projects with defined roles.
7. Analytics page showing views and engagement rates for projects.
8. Responsive design ensuring usability across devices.
9. Secure data storage and access controls.
10. Comprehensive error handling and user notifications.

# CookCut Video Editor Implementation Plan

## Phase 1: Core Features Implementation

### 1. Core Video Import & Processing 🎥
- [ ] **Video Import Flow**
  - [x] Gallery/Camera selection with preview
  - [x] Initial video quality check & format validation
  - [x] Progress indicator during import
  - [x] Thumbnail generation
  - [x] Basic metadata extraction (duration, resolution)
  - [x] Upload to Supabase storage

- [ ] **Clip Management**
  - [x] Create clips from imported videos
  - [x] Store clip metadata in Firestore
  - [x] Clip preview generation
  - [ ] Clip ordering and organization
  - [ ] Real-time clip updates
  - [ ] Clip status tracking

- [ ] **Basic Video Operations**
  - [x] Trim functionality with precise frame selection
  - [ ] Split video into segments
  - [ ] Delete segments
  - [ ] Reorder segments
  - [ ] Basic transitions between segments
  - [x] FFMPEG EC2 Instance integration for processing

### 2. Audio Integration 🎵
- [ ] **Background Music (Jamendo Integration)**
  - [ ] Music search and preview functionality
  - [ ] Volume control for background music
  - [ ] Multiple audio track support
  - [ ] Audio waveform visualization
  - [ ] Fade in/out effects

- [ ] **Original Audio Management**
  - [ ] Original video audio control
  - [ ] Audio ducking when music plays
  - [ ] Voice-over recording
  - [ ] Audio track mixing

### 3. Visual Enhancements 🎨
- [ ] **Text Overlays**
  - [ ] Add/edit/delete text
  - [ ] Font selection and styling
  - [ ] Text animation presets
  - [ ] Duration control for text
  - [ ] Position and scaling

- [ ] **Filters and Effects**
  - [ ] Basic color correction
  - [ ] Preset filters
  - [ ] Brightness/contrast/saturation controls
  - [ ] Speed adjustment (slow-mo/fast forward)
  - [ ] Crop and rotate

### 4. Export & Share 📤
- [ ] **Export Pipeline**
  - [ ] Quality selection (resolution/bitrate)
  - [ ] Format selection
  - [ ] Progress tracking
  - [ ] Background processing
  - [ ] Cancel/pause/resume support

- [ ] **Local Storage**
  - [ ] Project auto-save
  - [ ] Draft management
  - [ ] Export history
  - [ ] Cache management

## Phase 2: Advanced Features (Future Implementation)

### 1. Advanced Motion & Animation System 🎭
- [ ] Keyframe animation system
- [ ] Custom motion paths
- [ ] Preset animations library
- [ ] Motion curve editor
- [ ] Multi-object animation synchronization

### 2. Smart Template System 📱
- [ ] Recipe video templates
- [ ] Cooking tutorial templates
- [ ] Food review templates
- [ ] Custom template creation
- [ ] Template sharing system

### 3. AI-Enhanced Features 🤖
- [ ] Auto video enhancement
- [ ] Smart moment detection
- [ ] Background removal
- [ ] Food shot detection
- [ ] Auto-color correction

### 4. Advanced Sticker & Effect System ✨
- [ ] Dynamic stickers
- [ ] Interactive effects
- [ ] Custom effect creation
- [ ] Effect layering
- [ ] Real-time preview

### 5. Social Integration & Sharing 🌐
- [ ] Direct platform sharing
- [ ] Cross-platform optimization
- [ ] Social media import
- [ ] Analytics integration
- [ ] Engagement tracking

### 6. Advanced Audio Features 🎵
- [ ] Background noise removal
- [ ] Voice enhancement
- [ ] Auto-tune effects
- [ ] Beat synchronization
- [ ] Multi-track mixing

### 7. Collaborative Features 👥
- [ ] Project sharing
- [ ] Real-time collaboration
- [ ] Version control
- [ ] Comment system
- [ ] Change tracking

### 8. Performance Optimization ⚡
- [ ] Device-specific optimization
- [ ] Asset preloading
- [ ] Memory management
- [ ] Background processing
- [ ] Cache optimization

### 9. Tutorial & Onboarding System 📚
- [ ] Interactive tutorials
- [ ] Feature discovery
- [ ] Contextual help
- [ ] Video tutorials
- [ ] Template guides

### 10. Project Auto-Recovery 🔄
- [ ] Automatic checkpoints
- [ ] Version history
- [ ] Conflict resolution
- [ ] Cloud backup
- [ ] Cross-device sync

## Required Services & Dependencies

### Core Processing Services
```yaml
dependencies:
  # Video Preview & Playback
  video_player: ^2.7.2
  video_thumbnail: ^0.5.3
  chewie: ^1.7.1        # Better video player UI
  
  # API & Network
  dio: ^5.3.2          # For FFMPEG API calls
  retrofit: ^4.0.1     # Type-safe API calls
  json_annotation: ^4.8.1
  supabase_flutter: ^1.10.25  # Supabase SDK
  cloud_firestore: ^4.9.1    # Firestore SDK
  firebase_core: ^2.15.1     # Firebase Core
  
  # State Management & Architecture
  flutter_bloc: ^8.1.3
  get_it: ^7.6.4       # Dependency injection
  injectable: ^2.3.0
  
  # UI Components
  flutter_spinkit: ^5.2.0    # Loading indicators
  shimmer: ^3.0.0           # Loading placeholders
  cached_network_image: ^3.3.0
  
  # Audio Processing (Local Preview)
  just_audio: ^0.9.35
  audio_session: ^0.1.16
  
  # Storage & Caching
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  path_provider: ^2.1.1
  
  # Utils
  permission_handler: ^11.0.1
  logger: ^2.0.2
  connectivity_plus: ^5.0.1  # Network status
  mime: ^1.0.4              # File type detection
  timeago: ^3.5.0           # Timestamp formatting

dev_dependencies:
  build_runner: ^2.4.6
  json_serializable: ^6.7.1
  retrofit_generator: ^7.0.8
  injectable_generator: ^2.4.0
  hive_generator: ^2.0.1
```

```
AWS_EC2_FFMPEG=your_ec2_user@your_ec2_instance_public_ip
```

### Storage Services
```dart
// lib/core/services/storage_service.dart
class StorageService {
  final SupabaseClient _supabase;
  final FirebaseFirestore _firestore;
  
  Future<String> uploadVideo(File videoFile, String projectId) async {
    // 1. Upload to Supabase
    final fileName = '${projectId}/${uuid.v4()}.mp4';
    await _supabase
        .storage
        .from('raw-videos')
        .upload(fileName, videoFile);
        
    // 2. Get public URL
    final fileUrl = _supabase
        .storage
        .from('raw-videos')
        .getPublicUrl(fileName);
        
    return fileUrl;
  }
}

// lib/core/services/clip_service.dart
class ClipService {
  final FirebaseFirestore _firestore;
  
  Future<void> createClip({
    required String projectId,
    required String originalFileUrl,
    required double startTime,
    required double endTime,
    required int position,
    required int layer,
  }) async {
    await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('clips')
        .add({
          'originalFileUrl': originalFileUrl,
          'startTime': startTime,
          'endTime': endTime,
          'position': position,
          'layer': layer,
          'status': 'draft',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'createdBy': _auth.currentUser?.uid,
        });
  }
  
  Stream<List<Clip>> watchProjectClips(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('clips')
        .orderBy('position')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Clip.fromFirestore(doc))
            .toList());
  }
}
```

### Database Schema (Supabase)

```sql
-- Projects table
create table public.projects (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references auth.users not null,
  raw_video_id text not null,
  processed_video_id text,
  edit_operations jsonb not null default '[]'::jsonb,
  status text not null default 'draft',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- RLS Policies
alter table public.projects enable row level security;

create policy "Users can view their own projects"
  on public.projects for select
  using (auth.uid() = user_id);

create policy "Users can create their own projects"
  on public.projects for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own projects"
  on public.projects for update
  using (auth.uid() = user_id);
```

### Storage Buckets (Supabase)
bucket is cookcut-media

## Implementation Timeline

### Phase 1 (Core Features)
- Day 1-2: Core Video Foundation
- Day 2-3: Audio Integration
- Day 3-4: Visual Enhancements
- Day 4: Export & Storage

### Phase 2 (Advanced Features)
- Week 2: Motion & Templates
- Week 3: AI Features & Effects
- Week 4: Social & Audio
- Week 5: Collaboration & Performance
- Week 6: Tutorial & Recovery Systems

## Notes
- Focus on completing Phase 1 before moving to Phase 2
- Ensure robust testing of core features
- Gather user feedback before implementing advanced features
- Maintain performance as priority during implementation
- Consider device capabilities for feature availability 