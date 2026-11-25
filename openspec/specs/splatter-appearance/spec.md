# splatter-appearance Specification

## Purpose

Decides how a blood splatter looks when it appears on the player's screen: how big it is relative to the screen, how much each splatter varies in size and rotation, and how a saved size carries over between versions.

## Requirements

### Requirement: Splatter size is a share of the screen height
The Splatter size setting SHALL be a percentage of the screen height, shown in the settings panel as `%`. A splatter at a given setting SHALL cover the same share of the screen at any resolution, UI scale or "Use UI Scale" choice.

#### Scenario: Same look at 1080p and 4K
- **WHEN** a player with Splatter size 35% plays first at 1920×1080 and then at 3840×2160
- **THEN** a splatter spans about 35% of the screen height in both cases

#### Scenario: UI scale changes nothing
- **WHEN** a player changes the game's UI scale with splatters on screen and then gets new splatters
- **THEN** the new splatters cover the same share of the screen as before the change

#### Scenario: Settings panel shows a percentage
- **WHEN** the player opens the settings panel
- **THEN** the Splatter size slider shows its value with a `%` sign, not `px`

### Requirement: Default size matches the original's look
The default Splatter size SHALL be 35% of the screen height (the original's 266 units on its 768-unit-high screen), for new installs and after a settings reset.

#### Scenario: Fresh install
- **WHEN** the addon loads with no saved settings
- **THEN** the Splatter size setting is 35%

#### Scenario: Reset to defaults
- **WHEN** the player runs `/bs reset`
- **THEN** the Splatter size setting is 35%

### Requirement: Saved pixel sizes carry over unchanged
On the first login after upgrading, a saved size in pixels SHALL be converted once to the percentage that gives the same splatter size on the player's current screen, rounded to a whole percent and kept within the slider's range. A saved size equal to the old default (266) SHALL become the new default instead, since it was never changed.

#### Scenario: Old default becomes the new default
- **WHEN** a player whose saved size is the old default of 266 logs in for the first time after upgrading
- **THEN** their Splatter size setting is 35%

#### Scenario: Custom size kept on upgrade
- **WHEN** a player who had Splatter size set to a custom pixel value logs in for the first time after upgrading
- **THEN** their splatters are the same size on screen as before the upgrade, within one percent of the screen height

#### Scenario: Converted only once
- **WHEN** the same player later changes resolution or UI scale
- **THEN** the saved percentage stays as it is and splatters follow the new screen size

### Requirement: Each splatter varies slightly in size
Each splatter SHALL get its own random size within about 15% above or below the set size, chosen each time it appears. The variation SHALL have no setting.

#### Scenario: A set of combo points
- **WHEN** a rogue builds 5 combo points
- **THEN** the 5 splatters differ visibly but slightly in size, and on average match the Splatter size setting

#### Scenario: Preview shows the variation
- **WHEN** the player runs `/bs test`
- **THEN** the previewed splatters vary in size the same way

### Requirement: Each splatter has a random rotation
Each splatter SHALL be turned by a random angle (any angle from 0° to 360°), chosen each time it appears.

#### Scenario: Same shape, different angle
- **WHEN** the same splatter shape appears twice
- **THEN** it is usually turned differently each time

### Requirement: A splatter always fits the drawing area
A splatter, after its size variation, SHALL never be larger than the drawing area's width or height, and SHALL lie fully inside the drawing area.

#### Scenario: Small drawing area
- **WHEN** the drawing area is set smaller than the splatter size
- **THEN** splatters shrink to fit the drawing area and stay fully inside it

### Requirement: /bs debug reports the screen and splatter size
`/bs debug` SHALL print and save one line with the screen height in UI units, the UI scale, the physical resolution where the game provides it, and the resulting base splatter size.

#### Scenario: Checking a size report
- **WHEN** the player runs `/bs debug`
- **THEN** chat and the saved variables include a screen line with those values
