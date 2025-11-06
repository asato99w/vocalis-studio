# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Language Preference

**IMPORTANT: Always respond in Japanese (日本語) for all communications with the user.**

## Problem-Solving Philosophy

**CRITICAL: Never give up on solving the requested problem unless it is truly impossible.**

When encountering difficulties during task execution:

1. **Persist with Systematic Investigation**: Continue investigating and trying different approaches
2. **Document and Reference**: Update relevant documentation (`claudedocs/`) with findings and reference existing docs
3. **Avoid Easy Alternatives**: Do NOT offer alternative approaches that avoid the core problem unless the problem is demonstrably unsolvable
4. **Example - UITest Failures**:
   - ❌ WRONG: "UIテストが失敗しています。代わりにViewModelテストで確認しましょうか?" (Offering to skip UI tests)
   - ✅ RIGHT: "UIテストが失敗しています。調査報告書を確認し、前回成功した方法を試します" (Continuing investigation)

**Remember**: The user requested a specific solution. Deliver that solution through persistent, systematic problem-solving.

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
- **Run Tests**: See "Test Management" section below for efficient test execution
- **Clean**: `⌘+Shift+K` in Xcode or `xcodebuild clean -project VocalisStudio/VocalisStudio.xcodeproj -scheme VocalisStudio`
- **Run on Device**: Connect iPhone via cable, pair in Xcode (Window > Devices and Simulators), then `⌘+R`. First run requires trusting developer certificate in iPhone Settings > General > VPN & Device Management

### Test Management

The project uses multiple test schemes for efficient test execution. **See `VocalisStudio/claudedocs/test-scheme-management.md` for detailed documentation.**

**Quick Test Commands**:
```bash
# UI Tests only (recommended during UI development)
./VocalisStudio/scripts/test-runner.sh ui

# Unit Tests only (recommended during TDD)
./VocalisStudio/scripts/test-runner.sh unit

# All tests (recommended for CI/CD)
./VocalisStudio/scripts/test-runner.sh all

# Specific test class
./VocalisStudio/scripts/test-runner.sh ui PaywallUITests
```

**Available Schemes**:
- `VocalisStudio-UIOnly` - UI Tests only (skips Unit Tests)
- `VocalisStudio-UnitOnly` - Unit Tests only (skips UI Tests)
- `VocalisStudio-All` - All tests (Unit + UI)

**Why Multiple Schemes?**
- **Efficiency**: Run only necessary tests to save time
- **Error Isolation**: One test type's compilation errors won't block the other
- **Development Flow**: Focus on relevant tests during development

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

## Test-Driven Development (TDD) - CRITICAL RULES

**⚠️ MANDATORY: Read `docs/TDD_PRINCIPLES.md` for full details**

### Absolute Rules (NO EXCEPTIONS)

1. **ALWAYS write tests FIRST**
   - Write 1 test before ANY implementation code
   - No exceptions, no shortcuts
   - Test defines the API design

2. **ALWAYS run tests and verify Red**
   - Run immediately after writing test
   - Confirm test fails for the right reason
   - Never skip this step

3. **Write minimal implementation for Green**
   - Only write code to make test pass
   - Avoid over-engineering
   - YAGNI (You Aren't Gonna Need It)

4. **ALWAYS run tests and verify Green**
   - Run immediately after implementation
   - All tests must pass
   - Never proceed with failing tests

5. **ALWAYS run tests after refactoring**
   - Refactor only when all tests are Green
   - Run tests after each refactoring change
   - Ensure no regression

### Red-Green-Refactor Cycle (Target: 3-5 minutes per cycle)

```
🔴 Red (30 sec - 1 min):
   1. Write 1 failing test
   2. Run test → verify it fails
   3. Read failure message

🟢 Green (1-2 min):
   1. Write minimal code to pass test
   2. Run test → verify it passes
   3. Celebrate small victory

🔵 Refactor (1-2 min):
   1. Improve code quality
   2. Run all tests → verify still pass
   3. Commit if stable

→ Repeat for next test
```

### Common Anti-Patterns to AVOID

❌ **Implementation-First**: Writing code before tests
❌ **Test-After**: Adding tests to existing code
❌ **No Execution**: Writing tests but not running them
❌ **Batch Testing**: Writing many tests at once
❌ **Skip Red**: Not verifying test failure
❌ **Skip Green**: Not verifying test success
❌ **Skip Refactor**: Most common anti-pattern - skipping refactoring after Green
   - **⚠️ CRITICAL**: Minimal implementation ALWAYS needs refactoring
   - Code duplication, long methods, unclear naming are normal after Green
   - Refactoring is NOT optional - it's a mandatory TDD step
   - Test safety net makes refactoring safe and fast

### Quick Check Before Moving On

- [ ] Did I write the test first?
- [ ] Did I run and see Red?
- [ ] Did I write minimal code?
- [ ] Did I run and see Green?
- [ ] Did I refactor safely?
- [ ] Are ALL tests still passing?

**If any answer is NO, stop and fix immediately.**

### Test Execution Commands

```bash
# Run all tests (use frequently)
⌘+U in Xcode

# Run specific test class (during focused work)
xcodebuild test -only-testing:VocalisStudioTests/MIDINoteTests

# Run single test method (for debugging)
xcodebuild test -only-testing:VocalisStudioTests/MIDINoteTests/testInit
```

### Why This Matters

- **Tests as Design Tool**: Tests define how code should be used
- **Immediate Feedback**: Catch errors in seconds, not hours
- **Safe Refactoring**: Change code fearlessly with test safety net
- **No Over-Engineering**: Build only what tests require
- **Living Documentation**: Tests show how code works

### TDD for Bug Fixes - CRITICAL PATTERN

**バグ修正でもTDDサイクルを厳守してください。** テストファーストでバグを再現し、修正後も回帰を防ぎます。

#### Bug Fix Workflow

```
1. 🔴 Red: バグ再現テストを作成
   - バグを再現する失敗するテストを書く
   - テストコードのみ変更（製品コードに触れない）
   - テスト実行して失敗を確認

2. 🟢 Green: 実装を修正
   - 製品コードのみ変更（テストコードに触れない）
   - テスト実行してパスを確認
   - 既存テストもすべてパスすることを確認

3. 🔵 Refactor: コード品質改善
   - 必要に応じてリファクタリング
   - すべてのテストがパスすることを確認
```

#### 実例: スケール停止バグの修正 (Commit: 1735866)

**問題**: 録音停止時にスケール再生が停止しない

**🔴 Red Phase**:
```swift
// RecordingStateViewModelTests.swift
func testStartRecording_withScale_shouldSetStopRecordingContext() async throws {
    // Given: スケール付き録音の準備
    let settings = ScaleSettings(...)
    mockStartRecordingWithScaleUseCase.sessionToReturn = session

    // When: 録音開始
    await sut.startRecording(settings: settings)

    // Then: StopRecordingUseCaseにコンテキストが設定されているはず
    XCTAssertTrue(mockStopRecordingUseCase.setRecordingContextCalled)
    XCTAssertEqual(mockStopRecordingUseCase.contextURL, expectedURL)
}
```

**結果**: テスト失敗 ✓ (製品コードには一切触れていない)

**🟢 Green Phase**:
```swift
// RecordingStateViewModel.swift - executeRecording()
// セッション取得後に追加
stopRecordingUseCase.setRecordingContext(
    url: session.recordingURL,
    settings: session.settings
)
```

**結果**: テストパス ✓ (テストコードには一切触れていない)

**検証**: 既存テスト12個すべてパス ✓

#### Key Points

- ✅ テストファーストでバグを正確に再現
- ✅ 製品コード変更時にテストコード変更なし（厳守）
- ✅ テストコード変更時に製品コード変更なし（厳守）
- ✅ 既存機能を破壊していないことを確認
- ✅ 将来の回帰を防ぐテストが追加された
- ✅ バグ修正のドキュメントとしても機能

### Reference Documents

- **Full TDD Guidelines**: `docs/TDD_PRINCIPLES.md` (comprehensive explanation)
- **MVP Specification**: `docs/MVP_SPECIFICATION.md` (what to build)
- **Architecture Design**: `docs/MVP_ARCHITECTURE.md` (how to structure)

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

## Debugging and Log Retrieval - CRITICAL RULES

### ⚠️ MANDATORY: Always Report Log Retrieval Failures

When debugging issues (especially UI tests or runtime bugs), **ALWAYS attempt to retrieve logs first**. If log retrieval fails:

1. ❌ **DO NOT proceed with other work without reporting the failure**
2. ✅ **MUST report to user immediately**: "ログ取得に失敗しました。原因: [具体的な理由]"
3. ✅ **MUST wait for user guidance** before attempting alternative approaches

**Common mistakes to avoid**:
- ❌ Silently giving up on log retrieval and moving to code analysis
- ❌ Trying multiple log retrieval methods without reporting failures
- ❌ Assuming logs don't exist without verifying timing and process

### Log Retrieval Best Practices

**⚠️ IMPORTANT**: Refer to detailed logging guide for specific methods:
- **`VocalisStudio/claudedocs/log_capture_guide_v2.md`** - Comprehensive logging methods and troubleshooting

**Quick Reference**:
- **FileLogger** (推奨) - UIテスト後の解析で確実
- **OSLog** - リアルタイムデバッグ向け（2分以内に取得必須）

**If logs cannot be retrieved**:
1. Check test execution timestamp
2. Report to user: "テスト実行から[X]分経過しているため、ログが取得できません。"
3. Consult `log_capture_guide_v2.md` for alternative methods
4. Do NOT proceed with speculation or code changes without logs

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