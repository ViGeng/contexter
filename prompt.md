# Project Context: Context Manager (Contexter)

## Overview
**Context Manager** is a native macOS application built with SwiftUI (targeting macOS 12+). It serves as a visual workspace to organize "contexts"—collections of files, notes, and links—allowing users to manage project-specific resources more intuitively than a standard file browser.

The core philosophy is to map a "Page" in the app to a **Folder** on the disk. The app monitors these folders and creates a visual layer on top, persisting layout order and text notes in a hidden sidecar file (`._context_layout.json`).

## Implemented Features

### 1. Core Architecture & Data Model
- **File-System Backed**: 
  - Each "Page" represents a physical directory on the user's disk.
  - Files dropped into the app are strictly copied/moved to that directory.
- **Sidecar Persistence**:
  - Metadata (like text notes, block order, etc.) is stored in `._context_layout.json` within the folder.
  - This ensures data portability and resilience.
- **Reactive Monitoring**:
  - A custom `FolderMonitor` watches the file system. Changes made outside the app (e.g., in Finder) are instantly reflected in the app.

### 2. User Interface (Premium Design)
- **Sidebar**:
  - Lists top-level Pages.
  - Supports adding new pages and deleting existing pages via context menu.
  - Styled with translucent materials for a native macOS feel.
- **Page View**:
  - Displays the content of the selected context (Page).
  - Uses a `LazyVStack` for performance.
  - **Visual Blocks**:
    - **Text Blocks**: Rounded, visually distinct blocks for notes.
    - **File Blocks**: 
      - Images allow for "Aspect Fill" previews (max height 200px) to function as ease-to-scan thumbnails.
      - Non-image files appear as cards with icons and filenames.

### 3. Key Functionalities
- **Creation & Import**:
  - **Drag & Drop**: Files can be dragged directly onto the Page View.
  - **Import Button**: Toolbar button to generic file picker.
  - **Add Text**: Toolbar button to append new editable text blocks.
- **Editing**:
  - **In-Place Text Editing**: Text blocks are fully editable (`TextEditor`) and auto-save changes in real-time.
- **Deletion**:
  - **Block Deletion**: Right-click context menu on any block (Text or File) to delete it.
  - **Page Deletion**: Right-click context menu on sidebar items to delete the entire page/folder.

## To Be Implemented

### 1. Nested Hierarchy (Priority)
- **Sub-pages**: Ability to create pages *inside* other pages.
- **Sidebar Update**: The sidebar needs to support a tree-like structure (collapsible folders) to navigate nested contexts.
- **Breadcrumbs**: UI navigation to show current depth (e.g., `Root > Project A > Research`).

### 2. Advanced Layout & Organization
- **Reordering**: Drag-and-drop to reorder blocks within a page (currently fixed order or append-only).
- **Grid View**: Option to view files in a grid instead of a stack.
- **Resizing**: Ability for users to manually resize image blocks (e.g., Small, Medium, Large).

### 3. Enhanced Content Support
- **Rich Text / Markdown**: Upgrade simple text blocks to support formatting (bold, lists, headers).
- **Quick Look**: Spacebar to preview files natively.
- **Link Blocks**: First-class support for URL bookmarks with metadata fetching.

### 4. Search & Discovery
- **Global Search**: Ability to fuzzy search for text or filenames across all pages.
- **Tags**: Adding tag metadata to pages or blocks for cross-context filtering.
