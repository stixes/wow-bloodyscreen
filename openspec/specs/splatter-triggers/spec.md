# splatter-triggers Specification

## Purpose

Decides when blood splatters appear on the player's screen: which game events count as a trigger, how the chosen trigger applies to each character, and how saved choices carry over between versions.

## Requirements

### Requirement: Automatic trigger is the default
The Trigger setting SHALL offer "Automatic" alongside the four original triggers (combo points, and three crit variants), and Automatic SHALL be the default for new installs and after a settings reset.

#### Scenario: Fresh install
- **WHEN** the addon loads with no saved settings
- **THEN** the Trigger setting shows "Automatic"

#### Scenario: Reset to defaults
- **WHEN** the player runs `/bs reset`
- **THEN** the Trigger setting is "Automatic"

### Requirement: Automatic follows combo points on characters that have them
With Automatic selected, a rogue, or a druid in cat form, SHALL get one splatter per combo point on the current target, exactly as the "Combo points" trigger does, and crits SHALL add no splatters.

#### Scenario: Rogue builds combo points
- **WHEN** a rogue with Automatic selected has 3 combo points on the target
- **THEN** 3 splatters are on screen

#### Scenario: Rogue crits
- **WHEN** a rogue with Automatic selected lands a critical hit on the target
- **THEN** no splatter is added for the crit

### Requirement: Automatic uses timed crits on characters without combo points
With Automatic selected, any character that is not a rogue or a cat-form druid SHALL get a splatter for each critical hit it lands on its target. Each splatter SHALL fade once the "Hide the splatters after" time has passed since it appeared. Combo points SHALL add no splatters.

#### Scenario: Warrior crits
- **WHEN** a warrior with Automatic selected lands two critical hits on the target while auto-attacking
- **THEN** 2 splatters are on screen

#### Scenario: Crit splatters fade on the timer
- **WHEN** the timer (5 s by default) has passed since a warrior's crit splatter appeared
- **THEN** that splatter fades away, in or out of combat

#### Scenario: Combo point events on a warrior
- **WHEN** the client reports combo points for a warrior with Automatic selected
- **THEN** no splatter appears

### Requirement: Automatic re-resolves when a druid changes form
When a druid with Automatic selected shifts into or out of cat form, the trigger in effect SHALL switch between combo points and timed crits, and splatters from the previous trigger SHALL be cleared.

#### Scenario: Druid leaves cat form
- **WHEN** a druid with 2 combo-point splatters on screen shifts from cat form to bear form
- **THEN** the splatters are cleared and later crits produce splatters

#### Scenario: Druid enters cat form
- **WHEN** a druid in bear form shifts into cat form and gains combo points
- **THEN** splatters follow the combo points

### Requirement: Automatic applies per character on a shared account
Automatic SHALL resolve per character at login, so characters of different classes on the same account each get the matching behaviour from one shared setting.

#### Scenario: Rogue main, warrior alt
- **WHEN** the account's Trigger setting is Automatic and the player logs in on a warrior after playing a rogue
- **THEN** the warrior gets crit splatters, and the rogue still gets combo point splatters on its next login

### Requirement: Saved "Combo points" choice migrates to Automatic
When settings saved by an earlier version have "Combo points" selected, the addon SHALL switch them to Automatic on first load. Saved crit triggers SHALL be kept as they are.

#### Scenario: Upgrade with Combo points
- **WHEN** a player upgrades from 0.17.0 with "Combo points" selected
- **THEN** the Trigger setting shows "Automatic" and a rogue sees no difference

#### Scenario: Upgrade with a crit trigger
- **WHEN** a player upgrades with "Crits - hide when combat ends" selected
- **THEN** that trigger is kept
