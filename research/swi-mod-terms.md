# SWI team's terms for mods built on SWI

Research for [#93](https://github.com/ecarlste/x4-pirates-life-mod/issues/93), on the map [#89](https://github.com/ecarlste/x4-pirates-life-mod/issues/89). Researched 2026-11-10.

Question: the SWI build of A Pirate's Life depends on SWI and diff-patches SWI's own `md/notifications.xml` (Enhanced Bailing). Does it need the SWI team's permission to publish on Nexus? Whom do we ask, and how? How do other add-ons credit and depend on SWI?

Tags: **[read]** = a source says it (link or path given). **[inferred]** = my conclusion. **[snippet]** = read only from a search-engine summary, because the Nexus web page refuses automated fetches (HTTP 403). Nexus page data (descriptions, requirements, authors) came from Nexus's public GraphQL API (`api.nexusmods.com/v2/graphql`, `legacyModsByDomain`), which has no permissions field.

## Short answer

- **No written rule requires permission for an add-on that ships no SWI files.** I found no SWI policy on submods anywhere public: not on the Nexus page, the SWI website, its FAQ or its compatibility page. [read, see below]
- **But SWI's Nexus permissions are "ask first" for modifying its files and using its assets.** [snippet] A diff patch ships none of SWI's files, so it isn't redistribution or asset use. [inferred] Whether a diff patch of their script counts as "modifying my files" is a grey area. [inferred]
- **SWI lists "Change boarding/ejecting system" as incompatible** on its Nexus page, and "Change bailing system" on its website. Our bail hook is exactly that kind of mod. So publishing it as SWI-compatible touches something the team has stated an opinion on. [read]
- **Add-ons that change SWI's gameplay have asked.** Dangerous Interworlds (a big SWI rebalance) thanks "Mik and the rest of the X4 Star Wars modding team for letting me release this!" [read] Pure content add-ons (Reaper's Ship Pack) don't mention asking. [read]
- **Recommendation: ask, as a courtesy, before the Nexus upload,** on the SWI Discord. Our DESIGN.md already says to. It costs little and the team can flag conflicts with their Enhanced Bailing. Don't block launch on a reply. [inferred]

## 1. SWI's Nexus page (mod 349)

- **Author and uploader:** author "SW Interworlds Team", uploader `Mikska`. Version 0.91HF1, updated 2026-01-03. [read, Nexus API for [mod 349](https://www.nexusmods.com/x4foundations/mods/349)]
- **Permissions** (Nexus permission fields; not in the API, from search snippets only): getting permission is required before modifying the files and before using any of their assets; conversion to other games is not allowed; assets may not be used in paid mods. Parts that belong to other creators need those creators' permission. [snippet, [mod 349](https://www.nexusmods.com/x4foundations/mods/349)] I couldn't read the exact wording or the "Author notes" field. Check them by hand in a browser before relying on them.
- **Requirements:** the five DLCs only. No Nexus mod requirements. "SWI has no requirements other than the official DLCs." "Current X4 version supported: 8.0 HF4". [read, Nexus API description]
- **Contact:** "Latest news, teasers, helpdesk, and bug reports are on Discord" (`https://discord.gg/JbqMzcfS3Y`). "More details and credits are on the SWI Website." [read, Nexus API description]
- **Mod compatibility section** (quoted): "Anything in these general categories is NOT compatible: … Change boarding/ejecting system …". And: "Any old or outdated SWI Submods are going to break your game. Do not use any SWI submods from earlier major versions." It calls them "submods", so the team expects them to exist. [read, Nexus API description]
- **Feature list:** "New bailing system. Now AI vs AI can bail, including non-military L and XL ships." [read]
- **Mods requiring SWI:** 70 Nexus mods list SWI as a requirement. [read, Nexus API `modsRequiringThisMod.totalCount`]
- No sticky-post text was available: the posts tab needs the web page, which refuses automated fetches. [read: HTTP 403]

## 2. SWI's website and manifest

- **Credits page** ([SWI website](https://sites.google.com/view/swinterworlds/Home)): Mik (founder, author, models), Shuulo (author, programmer, project management, balancing, economy, AI), Kuertee (MD, UI, bounty hunting, RPG mechanics), Elratie, Lok and Land (art; Land also MD and library work). [read]
- **Enhanced Bailing isn't originally SWI's:** the credits thank "MoonShadowElf … for adopting and granting permission to integrate Enhanced Bailing mod", and Rovermicrover "for permission to integrate some of his mods". So the team asks before taking other people's work in, and expects the same. [read] The block we patch is that integrated Enhanced Bailing code. [read, bounty hunter `research/headhunter-wings.md` on branch `research/pirates-mod-capture`] Whether MoonShadowElf also needs to be asked: probably not, since we patch SWI's copy and ship none of it. [inferred]
- **Assets:** "All models, music, sound and other assets are property of and all rights reserved by STAR WARS" (Lucasfilm/Disney). [read]
- **Contact:** "All communication on the mod is done via Discord." [read]
- **Compatibility page** ([X4 Mods and Compatibility](https://sites.google.com/view/swinterworlds/x4-mods-and-compatibility)): mods that "Change bailing system" will likely conflict. "Some light QoL mods can still work … basically mods that add small things/new orders without change to assets." Nothing about submods, permissions or a policy for mod makers. [read]
- **FAQ** ([FAQ and Known Issues](https://sites.google.com/view/swinterworlds/faq-and-known-issues)): nothing about submods or permissions. [read]
- **Manifest** (`/mnt/e/x4-dev/reference/mods/swi-0.91hf1/starwarsmod_m1/content.xml`): `id="SW Interworlds"`, `author="MikSa Shuulo Elratie Kuertee Lok Land"`, `version="091"`, `<dependency version="800"/>`, the five DLCs `optional="false"`. No readme or license file in the extension folders; only `content.xml`, catalogs and `ui/`. [read]
- No ModDB page or Egosoft-forum policy turned up in searches. [read: searches returned none]

## 3. How other SWI add-ons credit and depend on SWI

From each mod's Nexus description and requirements (Nexus API). [read]

| Add-on | Requirement note on SWI | Credit / permission wording |
|---|---|---|
| [Reaper's Ship Pack (SWI)](https://www.nexusmods.com/x4foundations/mods/1321) 2.08 | "Will not function without this mod, at all. My mod only contains xml edits and doesnt contain any ship data." | No credit or permission line. "If you encounter bugs or other issues, please contact me through the SWI Discord." |
| [Dangerous Interworlds](https://www.nexusmods.com/x4foundations/mods/913) (rebalance) | listed, no note | "Thanks to Mik and the rest of the X4 Star Wars modding team for letting me release this!" Support thread "in #modding-and-patches channel" of the SWI Discord. |
| [SWI Clone Wars Expansion](https://www.nexusmods.com/x4foundations/mods/943) | "0.71 or higher" | "Credits: All core assets and total conversion foundations are created by the SWI Dev Team!" |
| [SWI Sandbox Tweaks](https://www.nexusmods.com/x4foundations/mods/1515) (by Land, an SWI team member) | "this is an SWI submod" | Thanks "Shuulo, Kuertee, DeadAir, and the rest of the SWI team"; says it exists so users get "a safe and up to date option that won't generate helpdesk tickets for the team." |
| [UI Extensions for SWI](https://www.nexusmods.com/x4foundations/mods/2134) | listed | "Credits: … Star Wars Interworlds Team - for the Star Wars Interworlds mod. kuertee - for the UI Extensions and HUD and permission to make this patch mod." |
| [Closed Loop Reborn](https://www.nexusmods.com/x4foundations/mods/1024) | "Required since this mod is a submod for X4 SWI" | none found |
| [Resurgent-class Star Destroyer](https://www.nexusmods.com/x4foundations/mods/1017) | "Mandatory as this is a sub-mod for this total conversion mod" | none found |
| [SWI addons canonical data](https://www.nexusmods.com/x4foundations/mods/524) | "Without it my addons don't work" | says it is made with the permission of SWI's creator [snippet] |
| [Careers](https://www.nexusmods.com/x4foundations/mods/1534), [InterGalactic Bank](https://www.nexusmods.com/x4foundations/mods/1577) | listed | link the SWI Discord; no permission line |

Patterns: [inferred from the table]
- Everyone lists SWI (349) as a Nexus requirement, often with a note saying it's a submod and naming the SWI version.
- Content-only add-ons rarely mention permission. Add-ons that change SWI's own systems or balance tend to thank the team for letting them release, or credit the team for the foundation.
- Support goes through the SWI Discord, in its modding channel (`#modding-and-patches`, as named by Dangerous Interworlds).
- `content.xml`: `<dependency id="SW Interworlds" optional="false"/>` (see the bounty hunter's [publishing research](https://github.com/ecarlste/x4-swi-bounty-hunter/blob/research/publishing-8-00-extension/research/publishing-8-00-extension.md#4-how-swi-add-ons-declare-the-dependency)).

## 4. Assets

- We ship none of SWI's files: no models, textures, text or copies of their scripts, only our own XML diff patches against them. That's within DESIGN.md's "Treat SWI files as reference only and never redistribute their assets." [inferred; DESIGN.md, "Design pillars and compatibility architecture"]
- Their Nexus permissions require asking before using their assets, ban conversion and ban use in paid mods. [snippet] None of this applies to a diff patch that ships no SWI content. [inferred]
- Star Wars IP belongs to Lucasfilm/Disney (their own disclaimer). [read] Keep our page free of SWI or Star Wars artwork unless it's our own screenshots; name SWI only to say what it needs. [inferred]
- Don't put the mod on Nexus with Donation Points or any paid tier tied to SWI content; their permissions bar commercial asset use, and staying free avoids the question. [inferred]

## Recommendation

1. **Ask the SWI team before the Nexus upload**, as a courtesy. Reasons: DESIGN.md already commits to it; their "ask first" modification permission makes a diff patch a grey area; we change bailing, which they list as incompatible; and comparable gameplay add-ons thanked the team for permission. [inferred]
2. **Where:** the SWI Discord (`https://discord.gg/JbqMzcfS3Y`), in the modding channel (`#modding-and-patches`). Address Shuulo (programming, balancing) and Mik (founder, Nexus uploader `Mikska`). Fallback if Discord gets no reply in a week or so: a private message to `Mikska` on Nexus. [inferred]
3. **Don't block launch on silence.** No published rule requires a reply. If there's no answer before episode 1, publish, note in the description that we asked, and take it down or change it if the team objects. If they say no, don't publish the SWI build. [inferred]
4. **On the Nexus page:** SWI (349) as a requirement with the note "Required: this is an SWI submod. Built for SWI 0.91 HF1 on X4 8.00 HF4." In the description: say it patches SWI's Enhanced Bailing, ships no SWI files, and is unofficial; a Credits section naming the SW Interworlds Team (Mik, Shuulo, Kuertee, Land and the rest), MoonShadowElf for Enhanced Bailing, and "thanks to the SWI team for letting me release this" once they agree; "Report bugs to me, not the SWI team" plus where. [inferred]
5. **Before relying on 349's permissions**, read the Permissions and credits section by hand in a browser (search snippets only here). [inferred]

### Draft message

> Hi Shuulo, Mik and the SWI team,
>
> I'm making A Pirate's Life, a piracy and ship-capture mod for X4, and I'd like to release a version built for SWI 0.91 HF1 (X4 8.00) on Nexus, listed as an SWI submod.
>
> What it does on SWI: it adds capture operations (your wingmen wear a target down and keep its shields off so it bails) and makes captured ships arrive intact. To do that it diff-patches SWI's `md/notifications.xml`, inside your Enhanced Bailing block, so our code runs the bail check. It keeps your Enhanced Bailing formula and doesn't raise the bail chance. It ships none of SWI's files, models or text, only our own XML patches.
>
> I know "change bailing system" is on your incompatible list, so I wanted to ask before publishing. Are you OK with this being released? Is there anything you'd like me to avoid, or say on the page? I'll credit the SWI team (and MoonShadowElf for Enhanced Bailing), say clearly that it's unofficial, and send bug reports to me, not your helpdesk.
>
> Thanks for SWI!
> Erik

## Open questions

- The exact text of 349's Permissions and credits section and its Author notes (read by hand).
- Whether the SWI Discord has a pinned modding policy in its channels (needs a Discord account; not public).
- Whether the team wants submods announced or listed somewhere, e.g. a submods channel.
