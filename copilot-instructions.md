# MAS App - Copilot Instructions

## General Overview
MAS App is a community management tool for scouts and similar organizations, built with Flutter and Supabase. It features role-based access control, troop-scoped admin features, and a modern Material 3 design.

## Features & Modules

### Notifications Tab (Refined & Modernized)
The notifications system allows for sending and receiving targeted messages.
- **UI/UX**: Premium aesthetic with rounded corners (20px-24px), subtle gradients, and refined typography.
- **Stability**: Bulletproof layout designs using `Flexible`, `Expanded`, and `SingleChildScrollView` to prevent `RenderFlex` overflows on various screen sizes.

### Role Management (Enhanced UI/UX)
Centralized interface for managing user roles and permissions with senior-level UI polish.
- **Visuals**: Modern card-based layout with gradient avatars, integrated status badges, and icon-based information hierarchy.
- **Rank Indicators**: Professional neutral-themed badges (e.g., "Rank 60") replacing outdated "error-like" red circles.
- **Dialogs**: Clean, structured modals with distinct sections for "Assigned Roles" and "Editable Roles", featuring persistent state feedback and improved typography.
- **Filters**: Integrated, borderless search and filter bar using `surfaceContainerLow` for a lightweight feel.

### Admin Features
- Scoped data access for Troop Leaders (rank 60-70).
- System-wide access for Admins/Moderators (rank 90-100).
- Automatic troop-scoping via `ScopedServiceMixin` and context inference.

## Coding Standards
- **UI**: Use Vanilla CSS/Flutter Material 3. Avoid hardcoded colors where possible, but use `withValues(alpha: ...)` on theme colors for subtle variations.
- **Layout Stability**: Always wrap flexible Row/Column children in `Flexible` or `Expanded` to avoid overflows.
- **State Management**: Provider.
- **Architecture**: Feature-based folder structure (Layered: UI, Logic, Data).
