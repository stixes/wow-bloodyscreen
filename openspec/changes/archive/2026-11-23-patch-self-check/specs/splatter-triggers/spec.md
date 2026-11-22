# Spec Delta

## MODIFIED Requirements

### Requirement: Automatic follows combo points on characters that have them
With Automatic selected, a rogue, or a druid in cat form, SHALL get one splatter per combo point on the current target, exactly as the "Combo points" trigger does, and crits SHALL add no splatters, as long as the game lets the addon read combo points.

#### Scenario: Rogue builds combo points
- **WHEN** a rogue with Automatic selected has 3 combo points on the target
- **THEN** 3 splatters are on screen

#### Scenario: Rogue crits
- **WHEN** a rogue with Automatic selected lands a critical hit on the target
- **THEN** no splatter is added for the crit

### Requirement: Crits count when the target takes them, from anyone
With a crit trigger in effect (one of the three crit triggers, or Automatic on a character without combo points), every critical hit the player's current target takes while the player is in combat SHALL add a splatter, whoever landed it: the player, a pet, or another player. A crit SHALL count whether or not the player is auto-attacking or has just cast. Hits that are not critical, heals and misses SHALL add none.

#### Scenario: Crit while not attacking
- **WHEN** the player is in combat but not auto-attacking, has not cast anything recently, and the target takes a critical hit
- **THEN** a splatter appears

#### Scenario: Another player's crit
- **WHEN** the player is in combat and another player or a pet lands a critical hit on the player's target
- **THEN** a splatter appears

#### Scenario: Crit on something else
- **WHEN** a unit that is not the player's current target takes a critical hit
- **THEN** no splatter appears

#### Scenario: Normal hit
- **WHEN** the target takes a hit that is not critical
- **THEN** no splatter appears

#### Scenario: Combo point characters on Automatic
- **WHEN** a rogue with Automatic selected, whose combo points can be read, watches its target take a critical hit from anyone
- **THEN** no splatter is added for the crit

## ADDED Requirements

### Requirement: Automatic falls back to timed crits when combo points can't be read
With Automatic selected, when the game no longer lets the addon read combo points, a rogue or a druid in cat form SHALL get timed crit splatters exactly as a character without combo points does. The explicit "Combo points" trigger SHALL show no splatters while combo points can't be read. When combo points become readable again, Automatic SHALL follow them again.

#### Scenario: Rogue after a patch that hides combo points
- **WHEN** combo points can't be read and a rogue with Automatic selected is in combat while its target takes two critical hits
- **THEN** 2 splatters are on screen, and each fades once the timer has passed

#### Scenario: Cat druid after the same patch
- **WHEN** combo points can't be read and a druid in cat form with Automatic selected is in combat while its target takes a critical hit
- **THEN** a splatter appears

#### Scenario: Explicit Combo points trigger
- **WHEN** combo points can't be read and a rogue has "Combo points" selected
- **THEN** no splatters appear, from combo points or from crits

#### Scenario: Combo points readable again
- **WHEN** a later check finds combo points readable again for a rogue with Automatic selected
- **THEN** splatters follow combo points again and crits add none
