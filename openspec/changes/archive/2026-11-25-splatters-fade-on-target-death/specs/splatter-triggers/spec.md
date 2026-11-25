## ADDED Requirements

### Requirement: Combo point splatters fade when the target dies
With combo point splatters (Automatic on a rogue or cat-form druid, or the "Combo points" trigger), a dead target SHALL count as having no combo points: its splatters SHALL fade out the usual way and SHALL NOT appear again while that dead target stays targeted, even if the game still reports points for it.

#### Scenario: Killing the target
- **WHEN** a rogue has 3 combo points on a mob and the mob dies, with the corpse still targeted
- **THEN** the 3 splatters fade out once and do not come back

#### Scenario: Next living target
- **WHEN** after the kill the rogue targets a living mob that has combo points on it
- **THEN** splatters for those points appear as on any target switch

#### Scenario: Targeting a corpse
- **WHEN** a rogue targets a dead mob
- **THEN** no combo point splatters are shown

#### Scenario: Dead state unreadable
- **WHEN** the game doesn't let the addon tell whether the target is dead
- **THEN** splatters follow the combo point count as before this change

#### Scenario: Crit triggers
- **WHEN** a warrior's target dies with crit splatters up
- **THEN** the splatters behave as before this change
