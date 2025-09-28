# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Vocalis Studio is an iOS voice training app written in Swift that helps users improve their singing skills. The app provides scale playback with simultaneous recording capabilities. The project follows Clean Architecture + Domain-Driven Design (DDD) + Test-Driven Development (TDD) principles.

## Technology Stack

- **Platform**: iOS (minimum iOS 15.0)
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Core Frameworks**: AVFoundation (audio recording/playback), Combine (reactive programming)
- **Development Environment**: Xcode 15.0+, macOS Sonoma 14.0+

## Development Commands

This is a native iOS project using Xcode's build system:

- **Open Project**: `open VocalisStudio/VocalisStudio.xcodeproj`
- **Build**: `⌘+B` in Xcode or `xcodebuild -project VocalisStudio/VocalisStudio.xcodeproj -scheme VocalisStudio -destination 'platform=iOS Simulator,name=iPhone 16' build -allowProvisioningUpdates`
- **Run Tests**: `⌘+U` in Xcode or `xcodebuild test -project VocalisStudio/VocalisStudio.xcodeproj -scheme VocalisStudio -destination 'platform=iOS Simulator,name=iPhone 16' -allowProvisioningUpdates`
- **Clean**: `⌘+Shift+K` in Xcode or `xcodebuild clean -project VocalisStudio/VocalisStudio.xcodeproj -scheme VocalisStudio`
- **Run on Device**: Connect iPhone via cable, pair in Xcode (Window > Devices and Simulators), then `⌘+R`. First run requires trusting developer certificate in iPhone Settings > General > VPN & Device Management

## Architecture Overview

The project implements Clean Architecture with strict layer separation:

### Layer Structure
```
VocalisStudio/
├── App/                    # Application entry point and DI container
├── Domain/                 # Business entities, value objects, repository interfaces
├── Application/           # Use cases that orchestrate business logic
├── Infrastructure/        # Repository implementations, AVFoundation wrappers
└── Presentation/          # SwiftUI views and ViewModels (MVVM pattern)
```

### Key Architectural Principles
- **Clean Architecture**: Strict dependency inversion - inner layers never depend on outer layers
- **Domain-Driven Design**: Rich domain entities (`Recording`) and value objects (`RecordingId`, `Duration`)
- **Repository Pattern**: Abstract data access through interfaces in Domain layer
- **Dependency Injection**: Centralized DI container manages object lifecycle

## Core Components

### Entry Points
- **`VocalisStudioApp.swift`**: Main app entry point using SwiftUI App protocol
- **`DependencyContainer.swift`**: Dependency injection container in App layer

### Domain Layer (`Domain/`)
- **Entities**: `Recording.swift` - core business entity
- **Value Objects**: `RecordingId.swift`, `Duration.swift` - ensure data integrity
- **Repository Interfaces**: `RecordingRepositoryProtocol.swift` - abstract data access

### Application Layer (`Application/`)
- **Use Cases**: `StartRecordingUseCase.swift`, `StopRecordingUseCase.swift` - business logic orchestration

### Infrastructure Layer (`Infrastructure/`)
- **Repositories**: Concrete implementations of domain repository interfaces
- **AVFoundation**: Wrappers around iOS audio frameworks

### Presentation Layer (`Presentation/`)
- **Views**: SwiftUI components
- **ViewModels**: MVVM pattern with Combine for reactive programming

## Testing Strategy

### Test Distribution
- **Unit Tests (70%)**: Domain entities, use cases, ViewModels
- **Integration Tests (20%)**: Repository and external service integration  
- **UI Tests (10%)**: Critical user flows

### Test Infrastructure
- **Mock Objects**: `MockRecordingRepository`, `MockAudioRecorder` for testing external dependencies
- **TDD Approach**: Write tests before implementation (Red-Green-Refactor cycle)
- **Coverage Target**: 80%+

### Running Tests
- All tests: `⌘+U` in Xcode
- Specific test class: Right-click test class → "Run Tests"
- Test results viewable in Xcode's Test Navigator

## Code Organization Rules

### Language Usage
- **UI Text**: Japanese (target audience: Japanese users)
- **Code & Comments**: English
- **Documentation**: Japanese in docs/, English in code comments

### Dependency Rules
- **Domain Layer**: No dependencies on outer layers
- **Application Layer**: Only depends on Domain
- **Infrastructure Layer**: Implements Domain interfaces, can depend on external frameworks
- **Presentation Layer**: Depends on Application and Domain layers only

### File Naming Conventions
- **Entities**: `EntityName.swift` (e.g., `Recording.swift`)
- **Value Objects**: `ValueObjectName.swift` (e.g., `RecordingId.swift`)
- **Use Cases**: `VerbNounUseCase.swift` (e.g., `StartRecordingUseCase.swift`)
- **Repository Interfaces**: `EntityNameRepositoryProtocol.swift`
- **Repository Implementations**: `ConcreteEntityNameRepository.swift`

## Development Workflow

1. **Follow TDD**: Write failing test → Implement minimal code → Refactor
2. **Respect Layer Boundaries**: Never violate dependency inversion principle
3. **Use DI Container**: Register new dependencies in `DependencyContainer.swift`
4. **Update Tests**: Ensure mock objects reflect interface changes
5. **Documentation**: Update relevant docs/ files for architectural changes

## Important Files to Reference

- **`docs/TECHNICAL_SPEC.md`**: Detailed TDD/DDD guidelines and coding standards
- **`docs/ARCHITECTURE.md`**: Clean Architecture implementation details
- **`docs/PROJECT_OVERVIEW.md`**: Business requirements and project vision
- **`docs/ROADMAP.md`**: Development milestones and feature priorities

## Current Implementation Status

The project has basic recording functionality implemented with:
- Recording start/stop capabilities
- Clean Architecture foundation with proper layer separation
- Domain entities and value objects
- Repository pattern with mock implementations
- SwiftUI-based user interface
- Comprehensive test coverage

Next major features planned: 5-tone scale audio generation, file management, and data persistence.