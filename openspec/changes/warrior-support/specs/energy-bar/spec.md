# Spec Delta

## Purpose

A slim, translucent bar for the player's main resource (energy, rage, mana) just below the screen centre, so it sits under the character, visible in combat and out of the way when idle.

## ADDED Requirements

### Requirement: Hide when idle out of combat
With "Hide when idle out of combat" enabled, the bar SHALL be hidden out of combat while the player's power is at its resting level and there are no combo points on the target. The resting level SHALL be empty for rage and full for every other power type. The bar SHALL reappear as soon as any of these stop holding.

#### Scenario: Warrior's rage has decayed
- **WHEN** a warrior is out of combat and rage has dropped to 0
- **THEN** the bar is hidden

#### Scenario: Warrior still has rage
- **WHEN** a warrior is out of combat with rage left
- **THEN** the bar is shown at the out-of-combat opacity

#### Scenario: Rogue at full energy
- **WHEN** a rogue is out of combat at full energy with no combo points
- **THEN** the bar is hidden

#### Scenario: Entering combat
- **WHEN** a player whose bar is hidden enters combat
- **THEN** the bar shows at the in-combat opacity

#### Scenario: Setting turned off
- **WHEN** "Hide when idle out of combat" is disabled
- **THEN** the bar stays visible out of combat at the out-of-combat opacity

### Requirement: Resting level is recognised when power is hidden from addons
When the client does not let addons read the player's power, the bar SHALL treat power as at rest after 3 seconds out of combat with no change in power.

#### Scenario: Power not readable
- **WHEN** the player's power cannot be read, and 3 seconds pass out of combat with no power change
- **THEN** the bar is hidden (with the setting on and no combo points)

#### Scenario: Power still changing
- **WHEN** power keeps changing out of combat (energy regenerating, rage decaying)
- **THEN** the bar stays visible
