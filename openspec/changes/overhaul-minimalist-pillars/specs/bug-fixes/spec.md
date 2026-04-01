# Bug Fixes

## MODIFIED Requirements

### Requirement: Gradient stops are always ordered
ShimmerView MUST clamp all gradient stop locations to [0, 1] and enforce non-decreasing order.

#### Scenario: Shimmer animation at boundary phases
Given the shimmer phase is -1 or 2 (boundary values)
When the gradient renders
Then all stops are within [0, 1] and in non-decreasing order with no console warnings

### Requirement: Subscription status is cached and prefetched
MusicService MUST cache MusicSubscription.current with a 5-minute TTL and prefetch at app startup to avoid blocking searches.

#### Scenario: First search after launch
Given the app launched and subscription was prefetched in background
When the user performs their first catalog search
Then the cached subscription is used with no hang

### Requirement: Tags persist correctly with CloudKit
SongAnnotation MUST store tags as a comma-separated string internally, exposing a computed [String] property for API compatibility.

#### Scenario: Save and reload tags
Given the user adds tags "chill" and "bass" to a song
When the app restarts and loads the annotation
Then both tags are present without CoreData materialization errors
