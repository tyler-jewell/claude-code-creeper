/// Git integration service
///
/// Handles worktree creation, commits, and PR creation via gh CLI.
library git_service;

import 'dart:io';

/// Service for git operations
class GitService {
  GitService._();

  /// Check if directory is a git repository
  static Future<bool> isGitRepo(String path) async {
    final result = await Process.run('git', [
      'rev-parse',
      '--is-inside-work-tree',
    ], workingDirectory: path);
    return result.exitCode == 0;
  }

  /// Get current branch name
  static Future<String?> getCurrentBranch(String path) async {
    final result = await Process.run('git', [
      'branch',
      '--show-current',
    ], workingDirectory: path);
    if (result.exitCode != 0) return null;
    return result.stdout.toString().trim();
  }

  /// Get the default branch (main or master)
  static Future<String> getDefaultBranch(String path) async {
    // Try to get the default branch from remote
    final result = await Process.run('git', [
      'symbolic-ref',
      'refs/remotes/origin/HEAD',
      '--short',
    ], workingDirectory: path);
    if (result.exitCode == 0) {
      final ref = result.stdout.toString().trim();
      return ref.replaceFirst('origin/', '');
    }

    // Fallback: check if main or master exists
    final mainResult = await Process.run('git', [
      'rev-parse',
      '--verify',
      'main',
    ], workingDirectory: path);
    if (mainResult.exitCode == 0) return 'main';
    return 'master';
  }

  /// Create a worktree for isolated changes
  ///
  /// Returns the path to the worktree.
  static Future<WorktreeResult> createWorktree(String projectPath) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final branchName = 'creeper/$timestamp';
    final worktreePath = '$projectPath/.creeper-work';

    // Remove existing worktree if present
    final existingDir = Directory(worktreePath);
    if (existingDir.existsSync()) {
      await Process.run('git', [
        'worktree',
        'remove',
        '--force',
        worktreePath,
      ], workingDirectory: projectPath);
    }

    // Get default branch to base off
    final defaultBranch = await getDefaultBranch(projectPath);

    // Create new worktree with new branch
    final result = await Process.run('git', [
      'worktree',
      'add',
      '-b',
      branchName,
      worktreePath,
      defaultBranch,
    ], workingDirectory: projectPath);

    if (result.exitCode != 0) {
      throw GitException('Failed to create worktree: ${result.stderr}');
    }

    return WorktreeResult(path: worktreePath, branchName: branchName);
  }

  /// Check if there are uncommitted changes
  static Future<bool> hasChanges(String path) async {
    final result = await Process.run('git', [
      'status',
      '--porcelain',
    ], workingDirectory: path);
    return result.stdout.toString().trim().isNotEmpty;
  }

  /// Get list of changed files
  static Future<List<String>> getChangedFiles(String path) async {
    final result = await Process.run('git', [
      'status',
      '--porcelain',
    ], workingDirectory: path);
    if (result.exitCode != 0) return [];

    return result.stdout
        .toString()
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.substring(3).trim())
        .toList();
  }

  /// Stage all changes
  static Future<void> stageAll(String path) async {
    final result = await Process.run('git', [
      'add',
      '-A',
    ], workingDirectory: path);
    if (result.exitCode != 0) {
      throw GitException('Failed to stage changes: ${result.stderr}');
    }
  }

  /// Commit changes
  static Future<void> commit(String path, String message) async {
    final result = await Process.run('git', [
      'commit',
      '-m',
      message,
    ], workingDirectory: path);
    if (result.exitCode != 0) {
      throw GitException('Failed to commit: ${result.stderr}');
    }
  }

  /// Push branch to origin
  static Future<void> push(String path) async {
    final result = await Process.run('git', [
      'push',
      '-u',
      'origin',
      'HEAD',
    ], workingDirectory: path);
    if (result.exitCode != 0) {
      throw GitException('Failed to push: ${result.stderr}');
    }
  }

  /// Create a pull request using gh CLI
  ///
  /// Returns the PR URL.
  static Future<String> createPR({
    required String path,
    required String title,
    required String body,
  }) async {
    // Check if gh is available
    final whichResult = await Process.run('which', ['gh']);
    if (whichResult.exitCode != 0) {
      throw GitException(
        'GitHub CLI (gh) not found. Install with: brew install gh',
      );
    }

    final result = await Process.run('gh', [
      'pr',
      'create',
      '--title',
      title,
      '--body',
      body,
    ], workingDirectory: path);

    if (result.exitCode != 0) {
      throw GitException('Failed to create PR: ${result.stderr}');
    }

    // gh pr create outputs the PR URL
    return result.stdout.toString().trim();
  }

  /// Clean up a worktree
  static Future<void> removeWorktree(String projectPath) async {
    final worktreePath = '$projectPath/.creeper-work';

    final result = await Process.run('git', [
      'worktree',
      'remove',
      '--force',
      worktreePath,
    ], workingDirectory: projectPath);

    // Also delete the branch if it exists
    if (result.exitCode == 0) {
      // Get branch name from worktree before removal
      // Branch was already removed with worktree
    }
  }

  /// Full workflow: create worktree, make changes, commit, push, create PR
  static Future<PRResult?> createPRFromWorktree({
    required String projectPath,
    required String title,
    required String description,
    required List<String> changesApplied,
  }) async {
    // Create worktree
    final worktree = await createWorktree(projectPath);

    try {
      // Note: Claude CLI will be run against worktree.path by the caller
      // After Claude makes changes, we check and create PR

      if (!await hasChanges(worktree.path)) {
        return null; // No changes made
      }

      // Stage and commit
      await stageAll(worktree.path);

      final commitMessage =
          '''
creeper: $title

Changes:
${changesApplied.map((c) => '- $c').join('\n')}

🤖 Generated by Claude Creeper
''';
      await commit(worktree.path, commitMessage);

      // Push
      await push(worktree.path);

      // Create PR
      final prBody =
          '''
## Summary

$description

## Changes

${changesApplied.map((c) => '- $c').join('\n')}

---

🤖 Generated by [Claude Creeper](https://github.com/tylerjewell/claude-code-creeper)
''';
      final prUrl = await createPR(
        path: worktree.path,
        title: 'creeper: $title',
        body: prBody,
      );

      return PRResult(
        url: prUrl,
        branch: worktree.branchName,
        changesApplied: changesApplied,
      );
    } finally {
      // Clean up worktree
      await removeWorktree(projectPath);
    }
  }
}

/// Result of creating a worktree
class WorktreeResult {
  WorktreeResult({required this.path, required this.branchName});

  final String path;
  final String branchName;
}

/// Result of creating a PR
class PRResult {
  PRResult({
    required this.url,
    required this.branch,
    required this.changesApplied,
  });

  final String url;
  final String branch;
  final List<String> changesApplied;
}

/// Git operation exception
class GitException implements Exception {
  GitException(this.message);
  final String message;

  @override
  String toString() => 'GitException: $message';
}
