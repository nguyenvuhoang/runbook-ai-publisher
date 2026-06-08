export function redactSecrets(markdown: string): string {
  let result = markdown;

  const replacements: Array<[RegExp, string]> = [
    [/password\s*=\s*['"]?[^'"\s]+['"]?/gi, "password=<REDACTED_PASSWORD>"],
    [/pwd\s*=\s*['"]?[^'"\s]+['"]?/gi, "pwd=<REDACTED_PASSWORD>"],
    [/token\s*=\s*['"]?[^'"\s]+['"]?/gi, "token=<REDACTED_TOKEN>"],
    [/secret\s*=\s*['"]?[^'"\s]+['"]?/gi, "secret=<REDACTED_SECRET>"],
    [/api[_-]?key\s*=\s*['"]?[^'"\s]+['"]?/gi, "api_key=<REDACTED_API_KEY>"],
    [/-----BEGIN RSA PRIVATE KEY-----[\s\S]*?-----END RSA PRIVATE KEY-----/gi, "<REDACTED_PRIVATE_KEY>"],
    [/-----BEGIN PRIVATE KEY-----[\s\S]*?-----END PRIVATE KEY-----/gi, "<REDACTED_PRIVATE_KEY>"],
  ];

  for (const [pattern, replacement] of replacements) {
    result = result.replace(pattern, replacement);
  }

  return result;
}