**Project Overview**

CookCut is a video editing app tailored for cooking creators, enabling them to efficiently produce and share engaging culinary content. The platform offers intuitive tools for video editing, collaboration, and analytics to enhance content creation and audience engagement.

**User Roles & Core Workflows**

1. As a cooking creator, I want to import and trim raw video clips to create concise cooking tutorials.
2. As a cooking creator, I want to overlay text instructions and timers onto videos to guide viewers through recipes.
3. As a cooking creator, I want to add background music and voiceovers to enhance the viewing experience.
4. As a collaborator, I want to edit shared projects to contribute to content refinement.
5. As a collaborator, I want to comment on specific sections of a video to provide feedback.
6. As a cooking creator, I want to view analytics on my videos to understand audience engagement.

**Technical Foundation**

*Data Models*

- **User**
  - Fields: user_id, username, email, profile_picture_url, created_at
  - Relationships: One-to-many with Project

- **Project**
  - Fields: project_id, user_id, title, description, created_at, updated_at
  - Relationships: Many-to-one with User; One-to-many with MediaAsset and EditSession

- **MediaAsset**
  - Fields: asset_id, project_id, type, file_url, uploaded_at
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