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
