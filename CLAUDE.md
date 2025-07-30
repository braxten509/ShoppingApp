# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ShoppingAppV2 is an iOS SwiftUI application that helps users calculate shopping costs by scanning price tags and managing shopping lists. The app uses multiple AI providers (OpenAI, Perplexity, Google Gemini) for price tag analysis and tax rate detection.

## Core Architecture

### Main Components

- **MainTabView**: Primary UI coordinator that manages dependency injection and tab navigation
- **CalculatorView**: Shopping cart and calculation interface
- **AIService**: Centralized AI service coordinator that routes requests to appropriate providers  
- **ShoppingListStore**: Core data store for shopping items with automatic persistence
- **LocationManager**: Handles location detection for tax rate calculations
- **Models/Models.swift**: Contains all data models including ShoppingItem and PriceTagInfo
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
# Build the project - USE IPHONE 16 FOR THE SIMULATOR!
xcodebuild -project ShoppingAppV2.xcodeproj -scheme ShoppingAppV2 -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run tests  
xcodebuild -project ShoppingAppV2.xcodeproj -scheme ShoppingAppV2 -destination 'platform=iOS Simulator,name=iPhone 16' test

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
- `MainTabView.swift`: Main UI controller and dependency injection
- `Models/Models.swift`: All data models and business logic
- `Services/AIService.swift`: AI provider coordination
- `Services/OpenAIService.swift`: Legacy OpenAI integration (contains billing logic)

### UI Components
- `Views/AddItemView.swift`: Manual item addition
- `Views/ItemEditView.swift`: Item editing interface
- `Views/VerifyItemView.swift`: Price tag verification
- `Views/SettingsView.swift`: App configuration
- `Views/BillingView.swift`: Cost tracking interface
- `Views/PromptsHistoryView.swift`: AI interaction history
- `Views/AISettingsView.swift`: AI model selection and configuration
- `Views/APIKeysView.swift`: API key management interface
- `Views/CameraView.swift`: Camera integration for price tag scanning
- `Views/CalculatorView.swift`: Shopping cost calculation interface
- `Views/MainTabView.swift`: Primary tab navigation controller
- `Views/PriceSearchWebView.swift`: Web-based price search interface
- `Views/SearchTabView.swift`: Product search and price comparison
- `Views/ShoppingHistoryView.swift`: Historical shopping data
- `Views/StoreManagementView.swift`: Custom store configuration
- `Views/CustomPriceListsView.swift`: Custom price list management
- `Views/CustomPriceSearchView.swift`: Custom price search interface
- `Views/KeyboardToolbar.swift`: Keyboard accessory view
- `Views/ManualPriceEntryOverlay.swift`: Manual price input overlay
- `Views/PrivacyView.swift`: Privacy policy and settings
- `Views/SecureWebView.swift`: Secure web view component

### Services
- `Services/BillingService.swift`: Cost tracking and credit management
- `Services/HistoryService.swift`: Prompt history management
- `Services/SettingsService.swift`: User preferences and API key storage
- `Services/OpenAIService.swift`: Legacy OpenAI integration with billing
- `Services/CustomPriceListStore.swift`: Custom price list data management
- `Services/PricingService.swift`: Pricing calculations and validation

### Supporting Files
- `AIProviderProtocol.swift`: Protocol definition for AI service providers
- `ShareSheet.swift`: iOS sharing functionality
- `Migration/FileMigration.swift`: File system migration utilities
- `Models/AIModels.swift`: AI model definitions and enums

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
1. **User Input** → Camera/Manual entry → `MainTabView` → `CalculatorView`
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

## Known Issues

### Critical Bugs
- **Custom Price List Item Selection**: When tapping an item on a custom made list, it pops the list and brings it down over and over. This issue has been attempted to be fixed multiple times and requires verbose debugging to resolve.

## Important Development Notes

### Simulator Requirements
- **ALWAYS use iPhone 16 simulator** when testing or building the app. This is a hard requirement specified in the project documentation.

### Dependency Injection Pattern
The app uses a centralized dependency injection pattern through `MainTabView`:
- All major services (`ShoppingListStore`, `LocationManager`, `OpenAIService`, etc.) are instantiated in `MainTabView`
- Services are passed down to child views through initializers
- `AIService` is created as a computed property that combines multiple dependencies

### Token Usage and Cost Estimation
- The app includes sophisticated token estimation logic with ~20% safety margin
- Supports multiple cost tracking decimal places for precision
- All AI interactions are tracked through `BillingService` and `HistoryService`
- Token usage is estimated client-side and validated against actual API responses