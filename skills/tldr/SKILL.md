---
description: One-sentence, plain-English summary of where things stand right now. Run /tldr whenever the conversation has become too long or technical to follow. No jargon, no code, no lists — just the situation in one sentence.
---

# TL;DR — One Sentence, Plain English

The user is non-technical and the conversation has gotten too dense to parse. Give them the situation in ONE sentence a smart friend with no coding background would understand.

## What to write

Exactly one sentence, under 30 words, that answers: **what is the state of things right now, and what (if anything) is needed from the user?**

If the user passed an argument (e.g. `/tldr the build failure`), summarize that topic specifically. Otherwise summarize the most recent work or problem in this conversation.

## Rules

- **One sentence. Full stop.** Not two. Not a sentence plus a bullet. If you cannot fit it, you have not found the point yet.
- **Plain English.** No file names, function names, commands, branch names, error text, acronyms, or version numbers. Say "the login page" not `LoginScreen.tsx`. Say "the app's database" not "RDS prod PG16".
- **State, not story.** Where things are now, not how we got here.
- **Say what is needed from the user, if anything.** "...and I need you to say yes before I change it." If nothing is needed, say what happens next.
- **If something is broken or unverified, say so.** Do not smooth it over. "The fix is written but I have not been able to confirm it works" is a valid sentence.
- **No preamble, no headers, no bold, no emoji, no closing offer.** The reply IS the sentence.

## Examples

Good:
- "The password-reset bug is fixed and tested, and I'm waiting for your okay to open the pull request."
- "The app build failed because one setting was in the wrong place; I know the fix but have not applied it yet."
- "I found three places the error could be coming from and have not yet confirmed which one it is."

Bad:
- "I've updated `eas.json` to restore the `build.testflight.env` block and re-ran `expo doctor`..." (jargon, file names)
- "Great question! Here's a quick summary: ..." (preamble)
- Anything with a second sentence.

## After /tldr

Stay in this register for the rest of the turn only. The user can run `/tldr` again any time the conversation gets dense.
