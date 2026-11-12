// The lowercase-paths check's rule: every path the mod ships (each deploy.include entry and
// everything under it) is lowercase, X4's convention since 3.0. A mixed-case loose file loads on one
// setup and silently not on another.

// deploy.include's entries, read as deploy.sh reads them: # starts a comment, trailing whitespace
// dropped, blank lines skipped
export function includeEntries(include: string): string[] {
  return include
    .split("\n")
    .map((line) => line.replace(/#.*/, "").replace(/\s+$/, ""))
    .filter(Boolean);
}

// The files (repo-relative, / separated) that ship and have an uppercase letter, sorted
export function uppercasePaths(include: string, files: string[]): string[] {
  const entries = includeEntries(include);
  const ships = (file: string) => entries.some((entry) => file === entry || file.startsWith(`${entry}/`));
  return files.filter((file) => ships(file) && /[A-Z]/.test(file)).sort();
}
