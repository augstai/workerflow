const FILLER_PATTERNS = [
  /\buh+\b/gi,
  /\bum+\b/gi,
  /\byou know\b/gi,
  /\blike\b/gi,
  /\bkind of\b/gi,
  /\bsort of\b/gi
];

export function cleanSpokenCommand(input) {
  let value = input.trim();
  for (const pattern of FILLER_PATTERNS) {
    value = value.replace(pattern, " ");
  }

  value = value.replace(/\s+/g, " ").trim();
  if (!value) {
    return "";
  }

  return `${value.charAt(0).toUpperCase()}${value.slice(1)}`;
}

export function classifyTask(input) {
  const task = cleanSpokenCommand(input);
  const lower = task.toLowerCase();
  const dictation = /^(write|type|paste|draft|say)\b/.test(lower) && !/\b(fix|run|test|refactor|debug|commit|diff)\b/.test(lower);

  return {
    mode: dictation ? "dictation" : "action",
    task,
    risk: estimateRisk(task)
  };
}

function estimateRisk(task) {
  const lower = task.toLowerCase();
  if (/\b(push|deploy|delete|drop|migrate|payment|auth|production|prod)\b/.test(lower)) {
    return "high";
  }
  if (/\b(fix|change|edit|refactor|install|upgrade)\b/.test(lower)) {
    return "medium";
  }
  return "low";
}
