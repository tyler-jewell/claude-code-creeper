/// Constants used throughout the creeper system.
library;

/// Default model to use for migrations.
const String defaultModel = 'haiku';

/// Supported migration file extension.
const String migrationExtension = '.jsonl';

/// Key used to identify migration metadata in JSONL files.
const String migrationMetadataKey = '_migration';

/// Maximum retries for migration verification.
const int maxVerifyRetries = 3;
