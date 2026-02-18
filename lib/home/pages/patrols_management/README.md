# Patrols Management Feature

## Overview
Patrols Management provides role-aware patrol CRUD and member assignment scoped by troop.

- System roles (rank >= 90): must select troop first
- Troop roles (rank 60/70): automatically scoped to managed troop

## Data Model
This feature uses:
- `patrols` table for patrol records
- `profiles.patrol_id` for current member assignment to exactly one patrol
- `profile_roles.troop_context` and user role rank for authorization scope

## Business Rules
- A member can belong to one patrol at a time (`profiles.patrol_id`)
- Unassigned members are those with `patrol_id IS NULL`
- Deleting a patrol unassigns members by setting `patrol_id = NULL`
- Duplicate patrol names in a troop are blocked client-side before write
- Reassigning from one patrol to another requires explicit confirmation in UI

## Folder Structure
- `data/`: models + Supabase service
- `logic/`: provider state and role-scoped orchestration
- `ui/`: page + dialog/card components

## Navigation
Route: `/patrols-management` (`AppRouter.patrolsManagement`)

Accessible from Home role dashboards:
- System Admin/Moderator dashboard actions
- Troop Head/Leader dashboard actions
