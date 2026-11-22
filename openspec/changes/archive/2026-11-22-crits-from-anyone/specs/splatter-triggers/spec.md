## ADDED Requirements

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
- **WHEN** a rogue with Automatic selected watches its target take a critical hit from anyone
- **THEN** no splatter is added for the crit

### Requirement: Crit splatters appear only while the player is in combat
Crits on the target SHALL add no splatters while the player is out of combat, for example when targeting a mob someone else is fighting. Splatters already on screen SHALL keep fading on their usual timer. The player's own opening crit, the hit that starts combat, SHALL count.

#### Scenario: Watching someone else's fight
- **WHEN** the player is out of combat and targets a mob another player is critting
- **THEN** no splatter appears

#### Scenario: Opening crit
- **WHEN** the player's first hit on a mob is a critical hit and starts combat
- **THEN** a splatter appears for it

#### Scenario: Leaving combat with splatters up
- **WHEN** the player leaves combat with timed crit splatters on screen
- **THEN** they fade when their timer runs out, and later crits on the target add none until the player is in combat again

### Requirement: No setting or command limits crits to the player's own
The addon SHALL NOT offer a setting or slash command that restricts crit splatters to the player's own hits. `/bs help` SHALL NOT list one, and `/bs strict` SHALL do nothing beyond what any unknown command does.

#### Scenario: Help text
- **WHEN** the player runs `/bs help`
- **THEN** no "strict" command is listed

#### Scenario: Old command
- **WHEN** the player types `/bs strict on`
- **THEN** crit splatters still come from every crit on the target

### Requirement: Saved strict choice is dropped on upgrade
When settings saved by an earlier version contain the strict choice, the addon SHALL remove it on first load and SHALL keep every other saved setting, including the chosen trigger.

#### Scenario: Upgrade with strict on
- **WHEN** a player upgrades from 0.18.x with "Crits - hide after the timer (shared)" selected
- **THEN** that trigger is kept, and crits from anyone on the target now splatter

## MODIFIED Requirements

### Requirement: Automatic uses timed crits on characters without combo points
With Automatic selected, any character that is not a rogue or a cat-form druid SHALL get a splatter for each critical hit its target takes, from anyone. Each splatter SHALL fade once the "Hide the splatters after" time has passed since it appeared. Combo points SHALL add no splatters.

#### Scenario: Warrior crits
- **WHEN** the target of a warrior with Automatic selected takes two critical hits
- **THEN** 2 splatters are on screen

#### Scenario: Crit splatters fade on the timer
- **WHEN** the timer (5 s by default) has passed since a warrior's crit splatter appeared
- **THEN** that splatter fades away, in or out of combat

#### Scenario: Combo point events on a warrior
- **WHEN** the client reports combo points for a warrior with Automatic selected
- **THEN** no splatter appears
