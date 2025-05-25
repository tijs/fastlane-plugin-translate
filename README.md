# fastlane-plugin-translate

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-translate)

## About translate

Automatically translate iOS `Localizable.xcstrings` files using DeepL API. This plugin helps you efficiently manage app localization by translating untranslated strings while preserving your existing translations.

## Features

- 🔍 **Auto-discovery**: Automatically finds your `Localizable.xcstrings` file
- 📊 **Translation analysis**: Shows translation progress for each language
- 🎯 **Smart targeting**: Only translates untranslated strings (state: "new" with empty values)
- 💾 **Progress tracking**: Saves progress between runs to avoid re-translating
- 🎭 **Formality support**: Automatically detects and offers formality options for supported languages
- 📝 **Context extraction**: Uses comments from xcstrings as translation context
- 🔄 **Batch processing**: Efficiently handles large numbers of strings
- 🛡️ **Error recovery**: Comprehensive error handling with user choices
- 📄 **Automatic backups**: Creates timestamped backups before translation
- ✅ **Validation**: Ensures output file is valid JSON

## Getting Started

### Install from RubyGems (Recommended)

```bash
fastlane add_plugin translate
```

### Install from GitHub (Latest Development Version)

Add to your `Gemfile`:

```ruby
gem "fastlane-plugin-translate", git: "https://github.com/tijs/fastlane-plugin-translate"
```

Then run:

```bash
bundle install
```

## Setup

1. **Get a DeepL API key** from <https://www.deepl.com/pro#developer>
2. **Set your API key** as an environment variable:

   ```bash
   export DEEPL_AUTH_KEY="your-deepl-api-key-here"
   ```

## Usage

### Basic Usage

```ruby
# Automatically detect xcstrings file and show language selection
translate_with_deepl
```

### Specify Target Language

```ruby
# Translate to German
translate_with_deepl(target_language: "de")

# Translate to French with formal style
translate_with_deepl(
  target_language: "fr", 
  formality: "more"
)
```

### Custom Configuration

```ruby
# Full configuration example
translate_with_deepl(
  xcstrings_path: "./MyApp/Localizable.xcstrings",
  target_language: "es",
  formality: "prefer_more",
  batch_size: 15,
  free_api: true
)
```

## Supported Languages

The plugin supports all languages available in both Apple's App Store Connect and DeepL API:

### Full DeepL Support

- 🇩🇪 German (de) - *supports formality*
- 🇫🇷 French (fr) - *supports formality*  
- 🇮🇹 Italian (it) - *supports formality*
- 🇪🇸 Spanish (es) - *supports formality*
- 🇳🇱 Dutch (nl) - *supports formality*
- 🇵🇱 Polish (pl) - *supports formality*
- 🇵🇹 Portuguese (pt-BR, pt-PT) - *supports formality*
- 🇯🇵 Japanese (ja) - *supports formality*
- 🇷🇺 Russian (ru) - *supports formality*
- 🇬🇧 English (en-US, en-GB)
- 🇨🇳 Chinese (zh-Hans, zh-Hant)
- 🇰🇷 Korean (ko)
- And many more...

*Languages marked with "supports formality" offer formal/informal translation options*

## Parameters

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `api_token` | DeepL API authentication key | `ENV['DEEPL_AUTH_KEY']` | Yes |
| `xcstrings_path` | Path to Localizable.xcstrings file | Auto-detected | No |
| `target_language` | Target language code (e.g., "de", "fr") | User prompted | No |
| `batch_size` | Number of strings per API call | 20 | No |
| `free_api` | Use DeepL Free API endpoint | false | No |
| `formality` | Translation formality level | Auto-detected | No |

### Formality Options

For supported languages, you can specify:

- `default` - Standard formality
- `more` - More formal language
- `less` - Less formal language  
- `prefer_more` - Formal if available, otherwise default
- `prefer_less` - Informal if available, otherwise default

## Example Output

```
🔍 Found xcstrings file: ./Kilowatt/Localizable.xcstrings
✅ DeepL API key validated
💾 Backup created: ./Kilowatt/Localizable.xcstrings.backup_20241201_143022

📋 Available languages for translation:
1. German (de): 45.2% translated (127 remaining) [supports formality]
2. French (fr): 21.8% translated (220 remaining) [supports formality]
3. Spanish (es): 18.1% translated (231 remaining) [supports formality]

🎭 German supports formality options. Choose style:
→ more (formal)

🔄 Translating from EN to DE
📝 Found 127 untranslated strings

🔄 Translating batch 1/7 (20 strings)...
✅ Batch 1 completed (20 strings)
🔄 Translating batch 2/7 (20 strings)...
✅ Batch 2 completed (20 strings)
...

📝 Updating xcstrings file with 127 translations...
💾 Updated xcstrings file
✅ Updated xcstrings file is valid JSON

🎉 Translation completed!
📊 Translated 127 strings for German (de)
📄 Backup saved: ./Kilowatt/Localizable.xcstrings.backup_20241201_143022
🗑️  You can delete the backup after verifying results
```

## Error Handling

The plugin provides comprehensive error recovery:

### Rate Limiting

```
⚠️ Rate limit exceeded for batch 3/10
1. Wait 60s and retry
2. Skip this batch  
3. Abort translation
```

### Translation Errors

```
❌ Translation error for batch 2/10: Network timeout
1. Skip this batch
2. Retry batch
3. Abort translation
```

### API Quota Issues

```
❌ DeepL quota exceeded. Upgrade your plan or wait for reset.
```

## Shared Values

The action sets the following shared values for use in other lanes:

- `TRANSLATE_WITH_DEEPL_TRANSLATED_COUNT` - Number of translated strings
- `TRANSLATE_WITH_DEEPL_TARGET_LANGUAGE` - Target language code
- `TRANSLATE_WITH_DEEPL_BACKUP_FILE` - Path to backup file

```ruby
lane :translate_and_notify do
  count = translate_with_deepl(target_language: "de")
  
  slack(
    message: "✅ Translated #{count} German strings!",
    channel: "#localization"
  )
end
```

## Progress Tracking

The plugin automatically saves translation progress:

```
📈 Found existing progress: 45 strings translated
Continue from where you left off?
1. Yes, continue
2. No, start fresh
```

Progress files are automatically cleaned up after successful completion.

## Context Support

When xcstrings files contain comments, they're used as translation context:

```json
{
  "Hello World": {
    "comment": "Greeting message shown on app launch",
    "localizations": { ... }
  }
}
```

This comment becomes context for better translation quality.

## Requirements

- Ruby >= 2.6
- Fastlane >= 2.0.0
- DeepL API account (Free or Pro)

## Development

### Setup

1. Clone the repository
2. Run `bundle install`

### Testing

#### Unit Tests (RSpec)

Run the full test suite:

```bash
bundle exec rspec
```

Run specific test files:

```bash
bundle exec rspec spec/translate_with_deepl_action_spec.rb
bundle exec rspec spec/language_registry_spec.rb
bundle exec rspec spec/deepl_language_mapper_spec.rb
```

#### Code Quality

Run RuboCop for style checking:

```bash
bundle exec rubocop
```

Auto-fix correctable issues:

```bash
bundle exec rubocop -a
```

#### Manual Testing

To test the plugin manually with a real project:

```bash
# Export your DeepL API key
export DEEPL_AUTH_KEY="your-api-key-here"

# Test the plugin
bundle exec fastlane translate_with_deepl
```

### Requirements

- Ruby >= 3.4
- Fastlane >= 2.0.0
- DeepL API account (Free or Pro) for manual testing

## Issues and Feedback

For bugs, feature requests, or questions, please [create an issue](https://github.com/yourusername/fastlane-plugin-translate/issues).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## About fastlane

[fastlane](https://fastlane.tools) is the easiest way to automate beta deployments and releases for your iOS and Android apps. To get started with fastlane, check out [fastlane.tools](https://fastlane.tools).
