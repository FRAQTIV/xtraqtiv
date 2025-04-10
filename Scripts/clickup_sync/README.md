# ClickUp Task Sync

A utility script for synchronizing the XTRAQTIV project structure with ClickUp tasks.

## Setup

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Update the `.env` file with your ClickUp credentials:
   - `CLICKUP_API_TOKEN`: Your ClickUp API token
   - `CLICKUP_WORKSPACE_ID`: Your ClickUp workspace ID
   - `CLICKUP_SPACE_ID`: Your ClickUp space ID
   - `CLICKUP_LIST_ID`: The ID of the ClickUp list where tasks will be created

## Usage

The script provides several options for managing task synchronization:

### Preview Tasks

To preview the task structure without creating tasks in ClickUp:
```bash
python src/main.py --preview
```

### Save Task Structure

To save the current task structure to a JSON file:
```bash
python src/main.py --save
```

### Load Task Structure

To load and use a previously saved task structure:
```bash
python src/main.py --load task_structure.json
```

### Create Tasks

To create the tasks in ClickUp:
```bash
python src/main.py
```

## Task Structure

The script creates a hierarchical task structure in ClickUp that includes:

1. Core Development (xtraqtivCore)
   - Core Architecture Setup
   - Core Business Logic Implementation
   - Data Models and Schemas
   - Core Unit Tests

2. Application Development (xtraqtivApp)
   - UI/UX Implementation
   - Resource Management
   - Application State Management
   - App Integration Tests

3. Documentation
   - API Documentation
   - User Documentation
   - Development Setup Guide

4. Project Infrastructure
   - Build System Setup
   - CI/CD Pipeline
   - Development Tools

## Error Handling

The script includes comprehensive error handling and logging. Check the console output for any issues during task creation.

