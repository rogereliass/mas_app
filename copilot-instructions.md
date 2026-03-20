# MAS App - Copilot Instructions

## General Overview
MAS App is a community management tool for scouts and similar organizations, built with Flutter and Supabase. It features role-based access control, troop-scoped admin features, and a modern Material 3 design.

## Features & Modules

### Notifications Tab (Refined & Modernized)
The notifications system allows for sending and receiving targeted messages.
- **UI/UX**: Premium aesthetic with rounded corners (20px-24px), subtle gradients, and refined typography.
- **Stability**: Bulletproof layout designs using `Flexible`, `Expanded`, and `SingleChildScrollView` to prevent `RenderFlex` overflows on various screen sizes.
- **Role-Based Access**: 
    - Management buttons ("Send", "Audit") are only visible to roles with **Rank 60+**.
    - For **Troop Leaders (Rank 60/70)**, the system automatically infers their troop context, hides the troop selection dropdown, and filters recipients (Patrols/Members) accordingly.
    - System-wide admins (Rank 90+) maintain full visibility of all troops.
- **Simplified Compose**: Notification types default to `announcement`, and the metadata JSON field is removed for better UX.
- **Components**:
    - `NotificationsPanel`: Main container with dynamic button visibility.
    - `NotificationItem`: Individual notification card with unread status indicators.
    - `NotificationDetailModal`: Detailed view tested for stability with long content.
    - `NotificationComposeModal`: Simplified, role-scoped form.
    - `NotificationAudit`: Complete audit trail of sent notifications.

### Admin Features
- Scoped data access for Troop Leaders (rank 60-70).
- System-wide access for Admins/Moderators (rank 90-100).
- Automatic troop-scoping via `ScopedServiceMixin` and context inference.

## Coding Standards
- **UI**: Use Vanilla CSS/Flutter Material 3. Avoid hardcoded colors where possible, but use `withValues(alpha: ...)` on theme colors for subtle variations.
- **Layout Stability**: Always wrap flexible Row/Column children in `Flexible` or `Expanded` to avoid overflows.
- **State Management**: Provider.
- **Architecture**: Feature-based folder structure (Layered: UI, Logic, Data).
