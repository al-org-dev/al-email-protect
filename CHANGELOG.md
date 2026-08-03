# Changelog

## 1.0.1 — 2026-08-03

- Added `al_email_protect_html`, a filter that rewrites `mailto:` anchors inside already-rendered HTML. al-folio's social
  links come from the third-party `jekyll-socials` gem, which owns the whole block and offers no hook to render the email
  entry differently — capturing its output and rewriting it afterwards is the only interception point, and it works
  regardless of which gem produced the markup. Percent-encoded targets (as `encode_email` produces) are decoded first,
  visible address text is replaced so the plaintext does not survive, non-`mailto:` links and unusable addresses are left
  untouched, and the filter is a pass-through when the feature is off.

## 1.0.0 — 2026-08-02

- Initial release of `al_email_protect`, implementing the email obfuscation proposed in
  [alshedivat/al-folio#3540](https://github.com/alshedivat/al-folio/issues/3540) (source PR
  [#3532](https://github.com/alshedivat/al-folio/pull/3532)).
- Addresses are split server-side and never appear as `user@host` or `mailto:` in the built HTML.
- `{% al_email_protect_link %}` tag, `al_email_obfuscate` filter, and `_styles` / `_scripts` asset tags.
- Vanilla-JS runtime (no jQuery), with a clipboard fallback for non-secure contexts and keyboard activation.
