<p align="center">
  <img src="docs/icon-256.png" width="96" height="96" alt="EuroBonus Finder icon">
</p>

<h1 align="center">Privacy Policy</h1>

<p align="center"><a href="PRIVACY.md" title="English">🇬🇧</a> &nbsp; <a href="PRIVACY.sv.md" title="Svenska">🇸🇪</a></p>

EuroBonus Finder has no accounts, no advertising and no analytics. Your browsing
stays on your device. This page explains exactly what happens, because
"we respect your privacy" is not an explanation.

*Last updated: 17 September 2026.*

## The short version

- The extension checks **on your device** whether the site you are on is a
  EuroBonus partner. That check never leaves your iPhone or iPad.
- The app makes **one** kind of network request: downloading the public list of
  partner shops. It is the same file for everyone in your market and carries no
  identifier for you.
- Nothing is collected, stored on a server, profiled, sold, or shared.

## What stays on your device

The extension keeps a few things in Safari's local extension storage:

- **Your market** — Sweden, Norway, Denmark or Finland — so it loads the right
  partner list.
- **A cached copy of the partner list**, refreshed about once an hour.
- **Which one-time tips you have already seen**, so they do not repeat.

To see whether a site earns points, the extension reads the **address of the
page you are on** (the domain and the first part of the path) and, on Google
results pages, the links in the results so it can badge partner shops. This all
happens inside Safari on your device and is matched against the cached list. It
is never transmitted, logged, or written down anywhere.

Deleting the app removes all of it. There is nothing else to clear.

## The one network request

The extension downloads the partner list from `eb-feed.pompa.se` — a single
static JSON file per market, identical for every user, requested with cookies
and credentials explicitly turned off. The request contains **no user
identifier, no page address, and no information about what you were browsing**;
the only thing it says is which of the four markets you picked.

The file is served as a static object from Cloudflare R2 storage located in the
**European Union**. There is no application server behind it and no database. As
with any request to any website, Cloudflare necessarily sees the connecting IP
address in order to deliver the file; it is not used to identify you, and no
profile, log, or record about you is created from it.

The partner list itself is public information published by SAS, which our
scheduled job fetches once a night. That job runs on a timer and never sees a
user request.

## Leaving for SAS

Tapping **Log in & earn** opens SAS's own website in Safari. From that moment
you are on a SAS page, and
[SAS's privacy policy](https://www.sas.se/legal/privacy-policy/) applies to what
happens there. EuroBonus Finder does not follow you, and cannot see whether you
signed in or what you bought. We never receive your EuroBonus number, your
points balance, or your purchases.

## This website

eurobonus.pompa.se uses [OpenPanel](https://openpanel.dev) for basic, aggregated
visitor statistics — page views and referrers, without cookies and without
cross-site tracking. The site also remembers your chosen language in your
browser's local storage. The app and the extension include none of this; the
analytics exist only on the website you are reading now.

## Children

EuroBonus Finder is a shopping utility, is not directed at children, and
knowingly collects no data from anyone — children included.

## Your rights

Because nothing about you is ever collected, there is nothing held about you to
access, correct, export, or delete. Deleting the app deletes the on-device data
described above.

## Changes

If this policy changes, the updated version is published here and the date at
the top changes with it. The history of every change is public in
[this repository](https://github.com/pompa/eurobonus-finder/commits/main/PRIVACY.md).

## Contact

Questions about privacy: **support@pompa.se**, or
[open an issue](https://github.com/pompa/eurobonus-finder/issues/new).

EuroBonus Finder is an independent project and is not affiliated with SAS,
EuroBonus, or any shopping partner — see [DISCLAIMER.md](DISCLAIMER.md).
