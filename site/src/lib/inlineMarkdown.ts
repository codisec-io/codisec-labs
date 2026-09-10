// Converte o subconjunto mínimo de Markdown usado em labs/*/lab.yaml
// (crases para código inline) em HTML seguro. Não é um parser de
// Markdown completo de propósito — os steps são texto curto de uma
// linha, nunca precisaram de mais que isso.
function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

export function renderInlineMarkdown(text: string): string {
  const parts = text.split(/(`[^`]+`)/g);
  return parts
    .map((part) =>
      part.startsWith('`') && part.endsWith('`')
        ? `<code>${escapeHtml(part.slice(1, -1))}</code>`
        : escapeHtml(part)
    )
    .join('');
}
