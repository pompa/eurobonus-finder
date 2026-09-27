# EuroBonus Finder

An iOS app plus Safari extension that shows which shops are EuroBonus partners while the user browses and searches, and helps them earn points through SAS Online Shopping.

## Language

### Shopping

**Partner**:
A shop where purchases earn EuroBonus points through SAS Online Shopping.
_Avoid_: Shop (when the partner status matters), store, merchant

**Badge**:
The EB mark the extension places next to a Partner in Google search results.

**Banner**:
The bar the extension shows at the top of a Partner's website.

**SAS Shopping return**:
The user goes from a Partner's website to SAS Online Shopping, logs in there, and is sent back to the Partner.
_Avoid_: SAS return, affiliate return, pending return

### Getting started

**Setup**:
The app's first-run flow: choosing a region, turning on the extension, granting it website access, and confirming that on the Test page.
_Avoid_: Onboarding, intro

**Test page**:
The page on eurobonus.pompa.se that Setup opens in Safari to confirm the extension runs on every website.
_Avoid_: Verification page, permission check

**Tutorial**:
The coaching the extension does in Safari to show the user how Badges, the Banner and the SAS Shopping return work. The app starts it; the extension runs it.
_Avoid_: Guided test, tour, try-out, extension onboarding

**Tutorial step**:
A single thing the Tutorial teaches. Steps can be completed in any order: seeing a Badge, visiting a Partner, and completing a SAS Shopping return.

**Tutorial progress**:
The set of Tutorial steps the user has completed. The app and the extension share one copy. The Tutorial is finished when every step is in it.

**Coachmark**:
A popover in the Tutorial, anchored to the thing it explains. Closing a Coachmark completes its Tutorial step.
_Avoid_: Popover, tooltip, tip

**Reset**:
Wiping everything the app and the extension have stored, so the user starts again from Setup. Shown to users as "Reset settings".
_Avoid_: Reset onboarding, reset setup
