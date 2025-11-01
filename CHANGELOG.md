# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.2] - 2025-10-31

### Fixed
- Fixed compatibility issue with deepl-rb 3.x by pinning to deepl-rb ~> 2.5
- Fixed `free_api` parameter default value causing auto-detection to be skipped

## [0.3.1] - 2025-10-31

### Added
- Automatic detection of DeepL API endpoint (Free vs Pro)
- Helpful tip message when Free API is detected

### Fixed
- "Invalid DeepL API key" error for users with Free API keys
- Users no longer need to manually specify `free_api: true` parameter

### Changed
- API endpoint validation now tries Pro API first, then falls back to Free API
- Both `translate_with_deepl` and `translate_metadata_with_deepl` actions now support auto-detection

## [0.3.0] - 2025-01-19

### Added
- Metadata translation feature for App Store Connect metadata files
- `translate_metadata_with_deepl` action for translating description.txt, keywords.txt, etc.
- Support for translating multiple languages in one go
- Automatic language mapping between App Store metadata directories and DeepL codes

### Fixed
- Language mapping between App Store metadata directories and DeepL codes
- DeepL API call signature in translate_metadata_with_deepl

## [0.2.0] - Earlier release

### Added
- Initial `translate_with_deepl` action
- Support for .xcstrings file translation
- Interactive language selection with translation progress percentages
- Formality options for supported languages
- Batch translation with progress tracking
- Automatic backup creation before translation
- Translation progress persistence and resume capability

## [0.1.0] - Initial release

### Added
- Basic plugin structure
- DeepL API integration
