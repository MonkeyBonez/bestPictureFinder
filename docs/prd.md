# Product Requirements Document: AI Photo Curation App

## 1. Overview
This application aims to provide users with an objective opinion on their photos, helping them to **shortlist images for sharing**. The primary business goal for this standalone product is to **drive traffic and user acquisition**, focusing on providing a **great user experience** to address a common need. It is not currently part of a larger project.
\- **Platform**: iOS-only, targeting **iOS 18+**.

## 2. Goals & Success Criteria
The primary goal is to **help users make progress in choosing which photos to share**. While specific measurable goals or Key Performance Indicators (KPIs) are not yet defined, success will be measured by **user adoption and satisfaction**.

## 3. Problem Statement
Many users find themselves with numerous photos, particularly from events like vacations, and struggle to objectively shortlist the best ones for sharing on social media or with friends. This leads to confusion and a fear of being "humiliated" by choosing "bad photos". The core problem this app solves is providing an **objective, AI-driven opinion to streamline photo selection**, easing the emotional and social burden of choosing what to share.

## 4. Target Users / JTBD Summary
*   **When I have a collection of photos** (e.g., from a vacation or event), **I want to objectively shortlist them** for sharing, **so I can confidently post the best ones to impress people around me without embarrassment**.

## 5. Functional Requirements
The system must:
*   Allow users to **add photos from their iOS photo library**.
*   **Rank the photos** based on their **aesthetic score**.
*   Display a **list of photos** provided by the user, **sorted by aesthetic score** (most aesthetic on top).
*   Provide functionality to **select individual photos** from the list (similar to a checkbox).
*   **Include actions to select the top photo, top five photos, top 10 photos, and top 20 photos**, scaling up to the maximum number of photos provided by the user if fewer are available. These actions **replace the current selection**.
*   Allow users to **remove selected photos** from the list.
*   Enable users to **share selected photos** using the iOS share sheet, sharing the **original assets** (no re-encoding/export).
*   Display an **error toast** if a user attempts to share or delete photos without any selected, stating "must select photos". The error toast should be **professionally formatted**.
*   **Allow users to create an album on their phone with all photos currently in the app's list, sorted by aesthetic order**. This action should **not require selecting each photo** and should **utilize the original image** stored on the device to avoid creating duplicates. The album should be named **"TO NAME yyyy-MM-dd HH.mm.ss"**; if an album with the same name exists, **append an incrementing numeric suffix** (e.g., "(2)", "(3)") until a unique name is found.

## 6. Non-Functional Requirements
*   **Performance**: There are no specific performance targets defined at this stage.
*   **Security**: All photo processing and data handling will occur **locally on the device**, therefore there are no current security concerns regarding server-side data.
*   **Scalability**: This is a front-end iOS application with no backend components, so scalability is not a concern for this iteration.
*   **Accessibility**: The application should consider **accessibility standards** and **follow Apple guidelines**.
*   **Persistence**: The application **does not persist** imported photos or rankings **between app launches**.

## 7. Screens & Functionalities

### App Screen: Photo Curation View
*   **Name**: Photo Curation View
*   **Purpose**: To allow users to import, view, curate, and act upon their photos based on AI aesthetic scoring.
*   **Core Components**:
    *   A **list view of the photos** imported by the user.
    *   A button to **choose photos from the photo library**.
    *   **Actions for "Select Top Photo," "Select Top Five Photos," "Select Top 10 Photos," "Select Top 20 Photos"**.
    *   A **"Share" button**.
    *   A **"Delete" button** (to remove photos from the app's list).
    *   A **"Create Album" button/action**.
*   **Primary User Interactions**:
    *   Tapping a "Choose Photos" button to import images.
    *   **Tapping on individual photos in the list to select/deselect them** (checkbox-like interaction).
    *   Tapping the "Share" button to initiate sharing of selected photos.
    *   Tapping the "Delete" button to remove selected photos.
    *   Tapping "Select Top X Photos" actions to automatically select a subset; these actions **replace any existing selection**.
    *   **Tapping the "Create Album" action to generate an album of all displayed photos**.
*   **Link or reference to Figma/design files**: [PLACEHOLDER: Add link to design mockups here]

### Functionality: Photo Ranking
*   **Name**: Photo Ranking
*   **Description**: The application will automatically rank all imported photos based on their aesthetic score, with the most aesthetic photo appearing at the top of the list. Scoring is performed on-device via Apple Vision's **CalculateImageAestheticsScoresRequest** (iOS 18+).
*   **Trigger**: System (upon photo import).
*   **Expected Outcome**: An ordered list of photos from most to least aesthetically pleasing.

### Functionality: Error Toast Display
*   **Name**: Error Toast Display
*   **Description**: If a user attempts to share or delete photos without any photos being selected, a temporary, professionally formatted toast message will appear informing the user that photos must be selected.
*   **Trigger**: User (clicking Share or Delete without selection).
*   **Expected Outcome**: A clear, non-intrusive error message displayed to the user.

### Functionality: Create Photo Album
*   **Name**: Create Photo Album
*   **Description**: The application will create a new photo album on the user's device containing all photos currently displayed in the app's list, sorted by their aesthetic score. This action will not require individual photo selection and will utilize the original image files on the device to avoid duplication. The album will be named **"TO NAME yyyy-MM-dd HH.mm.ss"**; if a duplicate name exists, a numeric suffix will be appended until the name is unique. Assets will be inserted in the app's **sorted order**.
*   **Trigger**: User (clicking "Create Album" button/action).
*   **Expected Outcome**: A new album is created in the user's photo library with the sorted photos. A confirmation message is displayed to the user.

### Functionality: Share Originals
*   **Name**: Share Originals
*   **Description**: When sharing selected photos, the application will share the **original assets** from the Photos library (no re-encoding/export), via the iOS share sheet.
*   **Trigger**: User (clicking "Share" with one or more selected photos).
*   **Expected Outcome**: The native share sheet appears with the original photo files attached.

## 8. Out of Scope
*   Any features or functionalities not explicitly mentioned in this PRD are out of scope for the initial version. This specifically includes:
    *   Consideration for photo variety in ranking (focus is solely on "best" aesthetic score).
    *   Handling of ties in aesthetic ranking (assumed not to happen, no specific logic needed for now).
    *   Server-side processing or backend development.
    *   **Persistence** of imported photos and rankings across app relaunches.

## 9. Dependencies
*   **Vision Framework (Apple)**: iOS 18+ **CalculateImageAestheticsScoresRequest** for on-device aesthetic scoring. See: [Apple Vision Aesthetics Scoring](https://developer.apple.com/documentation/vision/calculateimageaestheticsscoresrequest).
*   **Photos / PhotosUI**: Importing from library, creating albums, sharing originals.

---
**Quick-reference links:**
*   /docs/design_spec.md
*   /.cursor/rules/frontend.mdc
*   /.cursor/rules/backend.mdc