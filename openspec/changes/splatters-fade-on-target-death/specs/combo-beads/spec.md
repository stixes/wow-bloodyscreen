## ADDED Requirements

### Requirement: Beads show no points on a dead target
The combo beads SHALL show no filled points while the current target is dead, even if the game still reports points for it, and SHALL show the count again as normal for a living target.

#### Scenario: Killing the target
- **WHEN** a rogue has 3 combo points on a mob and the mob dies, with the corpse still targeted
- **THEN** the beads show no points and stay empty

#### Scenario: Next living target
- **WHEN** the rogue then targets a living mob with 2 combo points on it
- **THEN** the beads show 2 points
