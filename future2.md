# Future idea 2 — Follow requests + public ride sharing

Status: **idea only, not scoped or scheduled.** Captured here so it isn't lost while
the social feed / forums / garage-directory work (see the main plan) goes in first.

## The idea

A user can find another rider by **email or username**, send them a follow request,
and if the other rider accepts, the requester can see that rider's rides **whenever
they choose to share a ride publicly**. Two separate pieces:

1. **Follow requests, not open follow.** Searching by email/username should not
   itself expose anything — it only lets you *send a request*. The target user sees
   incoming requests and explicitly accepts/declines. Nothing is visible until
   accepted (contrast with a Twitter-style "follow anyone freely" model — this one
   is closer to a private, consent-based connection, which fits a rider's real name
   / driving habits being sensitive).
2. **Explicit share, not automatic visibility.** After a ride ends, the user is
   shown an option: **"Share this ride"** — post it to their feed for followers to
   see, or leave it private (the default). Riding is not broadcast automatically;
   sharing is an opt-in per ride (or per-post from the garage).

## Why this is a small addition on top of already-planned social work, not a rebuild

- `SharedRideEntity` already has `isPrivate` and `allowedUserIds` — the per-ride
  visibility model this idea needs already exists in the data layer.
- `RideShareRepository.getFriendsFeed(friendIds)` already expects a list of
  "friend" ids as an input — it was clearly designed assuming a follow graph would
  exist, but that graph was never built. This idea IS that follow graph.
- What's missing, and what this idea would add:
  - A `FollowRequestEntity` (from/to user id, status: pending/accepted/declined,
    createdAt) + repository.
  - A "find people" search by email/username (careful: must not leak whether an
    email exists in the system beyond what's needed to send a request — avoid
    turning this into an email-enumeration oracle).
  - A pending-requests inbox screen (accept/decline).
  - Once accepted, the accepting user's id gets added to the requester's
    `friendIds` set used to call `getFriendsFeed`.
  - A "Share this ride" action on the ride-summary screen and/or a bike's ride
    history — sets `isPrivate: false` (or scopes via `allowedUserIds` to followers
    only, if a followers-only tier is wanted alongside fully public).

## Open questions for later (don't answer now, just flagged)

- Followers-only sharing vs. fully-public sharing — one tier or two?
- Can a follow request be revoked / can a follower be removed after acceptance?
- Does declining silently drop the request, or notify the requester?
- Rate-limiting the email/username search to prevent scraping the user base.
