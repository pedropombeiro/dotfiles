export const EnvProtection = async ({ project, client, $, directory, worktree }) => {
  /**
   * Matches .env files and all variants:
   * .env, .env.local, .env.production, .env.development, .env.test, etc.
   * Handles paths like /foo/.env, /foo/.env.local, .env, ../.env.production
   *
   * Allows safe template files: .env.example, .env.sample, .env.template
   */
  const SAFE_SUFFIXES = /\.(?:example|sample|template)$/i;
  const ENV_FILE_PATTERN = /(^|[/\\])\.env(\.[a-zA-Z0-9_.]+)?$/;

  /** Checks if a string contains a reference to a .env file */
  const containsEnvRef = (str) => {
    if (!str) return false;
    // Match .env variants as standalone path segments (word boundary or path separator)
    const matches = str.match(
      /\.env(\.[a-zA-Z0-9_.]+)?/gi,
    );
    if (!matches) return false;
    // Only flag if at least one match is NOT a safe template suffix
    return matches.some((m) => !SAFE_SUFFIXES.test(m));
  };

  /** Checks if a file path points to a .env variant */
  const isEnvFile = (filePath) => {
    if (!filePath) return false;
    if (SAFE_SUFFIXES.test(filePath)) return false;
    return ENV_FILE_PATTERN.test(filePath);
  };

  const ERROR_MSG = "Access to .env files is not allowed";

  return {
    "tool.execute.before": async (input, output) => {
      const tool = input.tool;
      const args = output.args || {};

      // Tools that have a direct filePath argument: read, edit, patch
      if (["read", "edit", "patch"].includes(tool)) {
        if (isEnvFile(args.filePath)) {
          throw new Error(ERROR_MSG);
        }
      }

      // bash: scan the command string for .env references
      if (tool === "bash") {
        if (containsEnvRef(args.command)) {
          throw new Error(ERROR_MSG);
        }
      }

      // grep: block if targeting .env files via path or include pattern
      if (tool === "grep") {
        if (isEnvFile(args.path) || containsEnvRef(args.include)) {
          throw new Error(ERROR_MSG);
        }
      }

      // glob: block if the pattern or path targets .env files
      if (tool === "glob") {
        if (containsEnvRef(args.pattern) || isEnvFile(args.path)) {
          throw new Error(ERROR_MSG);
        }
      }
    },
  };
};
