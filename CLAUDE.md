# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ShoppingAppV2 is an iOS SwiftUI application that helps users calculate shopping costs by scanning price tags and managing shopping lists. The app uses multiple AI providers (OpenAI, Perplexity, Google Gemini) for price tag analysis and tax rate detection.

## Core Architecture

### Main Components

- **CalculatorView**: Primary UI coordinator that manages the shopping experience
- **AIService**: Centralized AI service coordinator that routes requests to appropriate providers  
- **ShoppingListStore**: Core data store for shopping items with automatic persistence
- **LocationManager**: Handles location detection for tax rate calculations
- **Models.swift**: Contains all data models including ShoppingItem and PriceTagInfo
- **Migration/**: Data and file migration utilities for backwards compatibility

### AI Integration

The app supports multiple AI providers through a unified interface:
- **OpenAI**: Used for legacy functionality and fallback scenarios
- **Perplexity**: Used for price guessing and web search capabilities  
- **Google Gemini**: Used for image analysis and text processing

AI provider selection is configurable per task type through SettingsService:
- `selectedModelForTaxRate`: Model used for tax rate detection
- `selectedModelForPhotoPrice`: Model used for price tag image analysis
- `selectedModelForTagIdentification`: Model used for price guessing

### Data Models

- **ShoppingItem**: Core shopping item with quantity tracking and tax calculations
- **PriceTagInfo**: Extracted information from price tag images
- **PromptHistoryItem**: Tracks AI interactions for billing and history

### Service Architecture

- **BillingService**: Tracks API costs and credit usage
- **HistoryService**: Manages prompt history and interaction tracking
- **SettingsService**: Manages user preferences and API keys
- **OpenAIService**: Legacy OpenAI service implementation (contains billing logic)

## Key Features

1. **Price Tag Scanning**: Camera integration for OCR price extraction
2. **Tax Rate Detection**: Location-based tax rate calculation
3. **Quantity Management**: Dynamic quantity controls with cost calculations
4. **Multi-Provider AI**: Configurable AI provider selection
5. **Billing Tracking**: Comprehensive cost tracking across all AI interactions
6. **Prompt Customization**: Advanced prompt editing system for tailoring AI interactions

## Common Development Commands

### Building and Testing
```bash
# Build the project
xcodebuild -project ShoppingAppV2.xcodeproj -scheme ShoppingAppV2 -destination 'platform=iOS Simulator,name=iPhone 15' build

# Run tests
xcodebuild -project ShoppingAppV2.xcodeproj -scheme ShoppingAppV2 -destination 'platform=iOS Simulator,name=iPhone 15' test

# Clean build folder
xcodebuild -project ShoppingAppV2.xcodeproj -scheme ShoppingAppV2 clean
```

### Running the App
The app requires API keys to be configured in the settings:
- OpenAI API key for legacy functionality
- Perplexity API key for price guessing
- Google Gemini API key for image analysis

## File Structure

### Core Files
- `ShoppingAppV2App.swift`: App entry point
- `ContentView.swift`: Main UI controller
- `Models.swift`: All data models and business logic
- `AIService.swift`: AI provider coordination
- `OpenAIService.swift`: Legacy OpenAI integration (contains billing logic)

### UI Components
- `AddItemView.swift`: Manual item addition
- `ItemEditView.swift`: Item editing interface
- `VerifyItemView.swift`: Price tag verification
- `SettingsView.swift`: App configuration
- `BillingView.swift`: Cost tracking interface
- `PromptsHistoryView.swift`: AI interaction history
- `AISettingsView.swift`: AI model selection and configuration
- `APIKeysView.swift`: API key management interface
- `CameraView.swift`: Camera integration for price tag scanning
- `CalculatorView.swift`: Shopping cost calculation interface
- `MainTabView.swift`: Primary tab navigation controller
- `PriceSearchWebView.swift`: Web-based price search interface
- `SearchTabView.swift`: Product search and price comparison
- `ShoppingHistoryView.swift`: Historical shopping data
- `StoreManagementView.swift`: Custom store configuration

### Services
- `BillingService.swift`: Cost tracking and credit management
- `HistoryService.swift`: Prompt history management
- `SettingsService.swift`: User preferences and API key storage
- `OpenAIService.swift`: Legacy OpenAI integration with billing

### Supporting Files
- `AIProviderProtocol.swift`: Protocol definition for AI service providers
- `ShareSheet.swift`: iOS sharing functionality
- `Migration/DataMigration.swift`: User data migration utilities
- `Migration/FileMigration.swift`: File system migration utilities

## Important Implementation Details

### Data Persistence
- Shopping items are stored in UserDefaults with automatic migration from legacy formats
- All AI interactions are tracked for billing and history purposes
- Settings and API keys are persisted securely

### Location Integration
- Uses CoreLocation for tax rate calculations
- Location data is formatted for AI provider consumption
- Graceful fallback when location is unavailable

### Error Handling
- Comprehensive error handling for API failures
- User-friendly error messages for configuration issues
- Fallback mechanisms for AI provider failures

### Cost Tracking
- Real-time cost tracking across all AI interactions
- Token usage estimation with accuracy validation
- Configurable billing decimal places for precision

### Prompt Customization
- Advanced prompt editing system with template support
- Support for dynamic placeholders (e.g., {itemName}, {locationContext})
- Per-task prompt customization (tax rate, price analysis, etc.)
- Enable/disable custom prompts with fallback to defaults
- Reset functionality for individual or all prompts

### Store Management
- Configurable store list with custom search URLs
- Default stores include Broulim's, Walmart, Target
- Support for custom store addition and URL formatting
- Dynamic search URL construction with placeholder replacement

## Testing Approach

The app includes unit tests in `ShoppingAppV2Tests/` and UI tests in `ShoppingAppV2UITests/`. Tests should verify:
- AI provider integration
- Data model calculations
- Shopping list persistence
- Location-based tax calculations
- Migration logic for backwards compatibility
- Billing and cost tracking accuracy

## Key Development Patterns

### Data Flow
1. **User Input** → Camera/Manual entry → `ContentView`
2. **AI Processing** → `AIService` routes to appropriate provider (OpenAI/Perplexity/Gemini)
3. **Data Storage** → `ShoppingListStore` with automatic UserDefaults persistence
4. **Cost Tracking** → All AI interactions logged via `BillingService` and `HistoryService`

### Configuration Management
- Settings stored in `SettingsService` with UserDefaults backing
- API keys managed securely through `APIKeysView`
- Model selection per task type (tax rate, image analysis, text processing)
- Manual tax rate override option for consistent calculations

### Error Handling Strategy
- Graceful degradation when AI services fail
- Retry logic with exponential backoff for critical operations
- User-friendly error messages with actionable guidance
- Fallback mechanisms (e.g., manual tax entry when detection fails)