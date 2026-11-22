# Spec Delta

## ADDED Requirements

### Requirement: "Disable in raids" setting
The settings panel SHALL offer a "Disable in raids" checkbox in the Blood splatters section. While it is ticked and the player is inside a raid instance, no splatter SHALL appear from any trigger (combo points, the crit triggers, Automatic), overriding the other trigger requirements. A raid group outside a raid instance SHALL NOT count as in a raid.

#### Scenario: Warrior crits in a raid
- **WHEN** a warrior with "Disable in raids" ticked is in combat inside a raid instance and the target takes a critical hit
- **THEN** no splatter appears

#### Scenario: Rogue in a raid
- **WHEN** a rogue with "Disable in raids" ticked builds combo points inside a raid instance
- **THEN** no splatter appears, and the combo beads under the energy bar still show the points

#### Scenario: Setting off in a raid
- **WHEN** "Disable in raids" is not ticked and the player's target takes a critical hit in combat inside a raid instance
- **THEN** splatters appear as the trigger in effect says

#### Scenario: Raid group out in the world
- **WHEN** a player with "Disable in raids" ticked is in a raid group outside any instance and the target takes a critical hit in combat
- **THEN** a splatter appears

#### Scenario: Battleground with only the raid setting
- **WHEN** a player with only "Disable in raids" ticked is in a battleground
- **THEN** splatters appear as usual

### Requirement: "Disable in battlegrounds" setting
The settings panel SHALL offer a "Disable in battlegrounds" checkbox in the Blood splatters section. While it is ticked and the player is inside a battleground or an arena, no splatter SHALL appear from any trigger, overriding the other trigger requirements.

#### Scenario: Crits in a battleground
- **WHEN** a player with "Disable in battlegrounds" ticked is in combat inside a battleground and the target takes a critical hit
- **THEN** no splatter appears

#### Scenario: Arena
- **WHEN** a player with "Disable in battlegrounds" ticked is inside an arena
- **THEN** no splatter appears

#### Scenario: Raid with only the battleground setting
- **WHEN** a player with only "Disable in battlegrounds" ticked is in combat inside a raid instance and the target takes a critical hit
- **THEN** a splatter appears

### Requirement: "Disable in raids" is off by default
"Disable in raids" SHALL be unticked for new installs, after `/bs reset`, and for players upgrading from a version without it.

#### Scenario: Fresh install
- **WHEN** the addon loads with no saved settings
- **THEN** "Disable in raids" is unticked

#### Scenario: Upgrade
- **WHEN** a player upgrades from a version without the setting
- **THEN** "Disable in raids" is unticked and every other saved setting is kept

#### Scenario: Reset
- **WHEN** the player ticks "Disable in raids" and runs `/bs reset`
- **THEN** it is unticked again

### Requirement: "Disable in battlegrounds" is on by default
"Disable in battlegrounds" SHALL be ticked for new installs, after `/bs reset`, and for players upgrading from a version without it. A player's saved choice to untick it SHALL be kept across reloads and upgrades.

#### Scenario: Fresh install
- **WHEN** the addon loads with no saved settings
- **THEN** "Disable in battlegrounds" is ticked

#### Scenario: Upgrade
- **WHEN** a player upgrades from a version without the setting
- **THEN** "Disable in battlegrounds" is ticked and every other saved setting is kept

#### Scenario: Unticked stays unticked
- **WHEN** a player unticks "Disable in battlegrounds" and reloads or upgrades
- **THEN** it is still unticked

#### Scenario: Reset
- **WHEN** the player unticks "Disable in battlegrounds" and runs `/bs reset`
- **THEN** it is ticked again

### Requirement: Splatters stop at once when the setting takes effect
When a disable setting starts to apply (the player enters the instance, or ticks the box while inside), splatters on screen SHALL be cleared. When it stops applying (the player leaves, or unticks the box), the trigger in effect SHALL work again from the next event, with no splatters carried over.

#### Scenario: Ticking the box inside a raid
- **WHEN** a player inside a raid instance has splatters on screen and ticks "Disable in raids"
- **THEN** the splatters are cleared and no new ones appear

#### Scenario: Leaving the raid
- **WHEN** a player with "Disable in raids" ticked leaves the raid instance
- **THEN** crits on the target in combat splatter again

#### Scenario: Unticking the box inside a raid
- **WHEN** a player inside a raid instance unticks "Disable in raids"
- **THEN** the next crit on the target in combat adds a splatter

### Requirement: Preview works while splatters are disabled
`/bs test` and the settings panel's Preview button SHALL show the splatters even while a disable setting applies.

#### Scenario: Test inside a raid
- **WHEN** a player with "Disable in raids" ticked runs `/bs test` inside a raid instance
- **THEN** all splatters are shown for a few seconds and then fade

### Requirement: Disable settings leave the energy bar alone
The disable settings SHALL NOT change the energy bar or the combo beads.

#### Scenario: Energy bar in a battleground
- **WHEN** a player with "Disable in battlegrounds" ticked and the energy bar enabled is in a battleground
- **THEN** the energy bar and combo beads show as they do anywhere else

### Requirement: Splatters stay on when the instance type can't be read
If the client doesn't tell the addon what kind of instance the player is in, splatters SHALL behave as if the player were outside any instance.

#### Scenario: Instance type unavailable
- **WHEN** both disable settings are ticked and the client gives no readable instance type
- **THEN** crits on the target in combat splatter as usual
