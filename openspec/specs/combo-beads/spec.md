# combo-beads Specification

## Purpose

Shows the player's combo points on the current target as a row of blood-bead baubles under the energy bar, for the characters that build combo points.

## Requirements

### Requirement: Beads show only for characters with combo points
The combo bead row SHALL be shown for rogues and for druids in cat form, and hidden for every other class and druid form, whatever combo point maximum the client reports.

#### Scenario: Rogue
- **WHEN** a rogue has the energy bar enabled
- **THEN** the bead row is shown under the bar

#### Scenario: Warrior
- **WHEN** a warrior has the energy bar enabled
- **THEN** no beads are shown

#### Scenario: Druid changes form
- **WHEN** a druid shifts from cat form to bear form
- **THEN** the bead row disappears, and it returns when the druid shifts back into cat form

### Requirement: Beads show no points on a dead target
The combo beads SHALL show no filled points while the current target is dead, even if the game still reports points for it, and SHALL show the count again as normal for a living target.

#### Scenario: Killing the target
- **WHEN** a rogue has 3 combo points on a mob and the mob dies, with the corpse still targeted
- **THEN** the beads show no points and stay empty

#### Scenario: Next living target
- **WHEN** the rogue then targets a living mob with 2 combo points on it
- **THEN** the beads show 2 points
