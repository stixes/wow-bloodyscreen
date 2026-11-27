# Spec Delta

## MODIFIED Requirements

### Requirement: Hide when idle out of combat
With "Hide when idle out of combat" enabled, the bar SHALL be hidden out of
combat while the player's power is at its resting level and there are no combo
points on the target. The resting level SHALL be empty for rage and full for
every other power type. The bar SHALL reappear as soon as any of these stop
holding. This SHALL NOT hide the bar while the Poised indicator is lit.

#### Scenario: Warrior's rage has decayed
- **WHEN** a warrior is out of combat and rage has dropped to 0
- **THEN** the bar is hidden

#### Scenario: Warrior still has rage
- **WHEN** a warrior is out of combat with rage left
- **THEN** the bar is shown at the out-of-combat opacity

#### Scenario: Rogue at full energy
- **WHEN** a rogue is out of combat at full energy with no combo points and no
  Poised indicator (the aura is not on the player)
- **THEN** the bar is hidden

#### Scenario: Poised is lit instead
- **WHEN** a rogue is out of combat at full energy with no combo points and the
  Poised indicator is lit
- **THEN** the bar is shown, not hidden

#### Scenario: Entering combat
- **WHEN** a player whose bar is hidden enters combat
- **THEN** the bar shows at the in-combat opacity

#### Scenario: Setting turned off
- **WHEN** "Hide when idle out of combat" is disabled
- **THEN** the bar stays visible out of combat at the out-of-combat opacity

## ADDED Requirements

### Requirement: Poised border
While the game reports the Poised aura on the player, the energy bar SHALL mark
its border white, SHALL stay visible whatever "Hide when idle out of combat"
says, and SHALL use the in-combat opacity. When the aura is no longer on the
player the border SHALL return to its normal colour and the normal opacity rules
apply again. The indicator SHALL appear only for a player the game gives the
aura to, and never for any other class or form.

#### Scenario: Opener charged
- **WHEN** a rogue is out of combat at full energy and gains Poised
- **THEN** the bar's border is white, the bar is visible at the in-combat
  opacity, and the bar's fill and number are unchanged

#### Scenario: Opener spent
- **WHEN** the rogue uses an Energy ability that consumes Poised
- **THEN** the border is back to its normal colour and the out-of-combat opacity
  rules apply again

#### Scenario: Poised lost by taking damage or regressing
- **WHEN** the rogue enters combat, or Energy falls below maximum while out of
  combat, while the border is white
- **THEN** the border returns to its normal colour

#### Scenario: Other classes never see it
- **WHEN** a warrior, a hunter, a druid in cat form or a rogue below the level
  Poised is learned is out of combat at full power
- **THEN** the border never changes colour

#### Scenario: The game does not report the aura
- **WHEN** the aura cannot be read because the API is missing or the data is
  hidden from addons
- **THEN** the border never changes, the bar behaves exactly as it did before
  this feature, and no part of the addon is switched off
