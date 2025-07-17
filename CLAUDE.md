# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ShoppingAppV2 is an iOS SwiftUI application that helps users calculate shopping costs by scanning price tags and managing shopping lists. The app uses multiple AI providers (OpenAI, Perplexity, Google Gemini) for price tag analysis, tax rate detection, and ingredient analysis.

## Core Architecture

### Main Components

- **ContentView**: Primary UI coordinator that manages the shopping experience
- **AIService**: Centralized AI service coordinator that routes requests to appropriate providers
- **ShoppingListStore**: Core data store for shopping items with automatic persistence
- **LocationManager**: Handles location detection for tax rate calculations
- **Models.swift**: Contains all data models including ShoppingItem, PriceTagInfo, and additive analysis

### AI Integration

The app supports multiple AI providers through a unified interface:
- **OpenAI**: Used for legacy functionality and fallback scenarios
- **Perplexity**: Used for price guessing and web search capabilities  
- **Google Gemini**: Used for image analysis and text processing

AI provider selection is configurable per task type through SettingsService:
- `selectedModelForTaxRate`: Model used for tax rate detection
- `selectedModelForPhotoPrice`: Model used for price tag image analysis
- `selectedModelForTagIdentification`: Model used for ingredient analysis and price guessing

### Data Models

- **ShoppingItem**: Core shopping item with quantity tracking, tax calculations, and additive information
- **PriceTagInfo**: Extracted information from price tag images
- **AdditiveInfo**: Detailed information about food additives with risk levels
- **PromptHistoryItem**: Tracks AI interactions for billing and history

### Service Architecture

- **BillingService**: Tracks API costs and credit usage
- **HistoryService**: Manages prompt history and interaction tracking
- **SettingsService**: Manages user preferences and API keys

## Key Features

1. **Price Tag Scanning**: Camera integration for OCR price extraction
2. **Tax Rate Detection**: Location-based tax rate calculation
3. **Quantity Management**: Dynamic quantity controls with cost calculations
4. **Additive Analysis**: Health-focused ingredient risk assessment
5. **Multi-Provider AI**: Configurable AI provider selection
6. **Billing Tracking**: Comprehensive cost tracking across all AI interactions
7. **Prompt Customization**: Advanced prompt editing system for tailoring AI interactions

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
- `PromptCustomizationView.swift`: AI prompt editing interface

### Services
- `BillingService.swift`: Cost tracking and credit management
- `HistoryService.swift`: Prompt history management
- `SettingsService.swift`: User preferences and API key storage

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

## Testing Approach

The app includes unit tests in `ShoppingAppV2Tests/` and UI tests in `ShoppingAppV2UITests/`. Tests should verify:
- AI provider integration
- Data model calculations
- Shopping list persistence
- Location-based tax calculations