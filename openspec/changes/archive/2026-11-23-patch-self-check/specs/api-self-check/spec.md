# Spec Delta

## Purpose

At every login the addon checks that the game still gives it what it relies on, so a WoW Forever patch that breaks something is caught on the first login: it switches off only the parts that can't work, tells the player once per game build in a single short line, and keeps the results so the owner can read them.

## ADDED Requirements

### Requirement: Checks run at every login and stay silent when all pass
At every login and UI reload the addon SHALL check the game behaviour it relies on: the character's class, its power type, primary power and maximum, combo points on the target, and the settings panel. When every check passes, the addon SHALL print nothing and every part SHALL work as before.

#### Scenario: Fresh install, nothing changed
- **WHEN** the addon loads for the first time on a client where every check passes
- **THEN** no chat message is printed and splatters, beads and the energy bar work as usual

#### Scenario: Ordinary login
- **WHEN** the player logs in on the same game build as last time and every check passes
- **THEN** no chat message is printed

### Requirement: Only the broken part is switched off
When a check finds that a part's game input can't be used, the addon SHALL switch that part off for the session and keep every other part working. The parts are the energy bar, combo points (combo splatters and beads), crit splatters, and the settings panel. A part that is off SHALL cause no Lua errors.

#### Scenario: Primary power can no longer be shown
- **WHEN** the client refuses the player's power value in the energy bar
- **THEN** the energy bar is hidden, and splatters still work

#### Scenario: Combo points can't be read
- **WHEN** neither combo point source gives a readable count
- **THEN** a rogue gets no combo splatters and no beads, and the energy bar still shows energy

#### Scenario: Class can't be read
- **WHEN** the character's class can't be read
- **THEN** combo points are off, Automatic gives crit splatters as for any class without combo points, and the one-line message names combo points whatever the class

#### Scenario: Settings panel missing
- **WHEN** the client's settings API doesn't accept the addon's panel
- **THEN** `/bs` prints the command list instead of opening the panel, and everything else works

### Requirement: An empty or zero reading is never a failure
A reading that is merely empty or zero at login, such as combo points with no target or a class not yet known, SHALL be recorded but SHALL NOT switch a part off or produce a message. A part SHALL be switched off only when a call fails, a needed value is hidden from addons, or a needed API is missing with no fallback.

#### Scenario: Login with no target
- **WHEN** a rogue logs in with no target and the combo point read gives nothing
- **THEN** combo points stay on and no message is printed

#### Scenario: Class not known yet at login
- **WHEN** the class or power type reads as empty at login
- **THEN** no part is switched off and no message is printed

#### Scenario: Fallback still works
- **WHEN** the preferred combo point source fails but the other source gives a readable count
- **THEN** combo points stay on and no message is printed, and the record notes the fallback

### Requirement: One short line names everything found at login
When one or more parts are switched off at login, the addon SHALL print exactly one short chat line naming them and pointing to `/bs debug`. It SHALL NOT print a separate line for the settings panel or for unreadable combo points about the same failure.

#### Scenario: Two parts broken
- **WHEN** a patch breaks both the energy bar and the settings panel
- **THEN** one line is printed, naming the energy bar and the settings panel as off

### Requirement: Each broken part is announced once per game build and addon version
Each switched-off part SHALL be announced at most once per game build and addon version, across all characters on the account. Later logins on the same build and version SHALL print nothing about it while the part stays off. After the game build or the addon version changes, the checks' findings SHALL be announced again.

#### Scenario: Next login on the same build
- **WHEN** the player logs in again on the same build and the energy bar is still broken
- **THEN** no message is printed and the energy bar stays hidden

#### Scenario: Game patched
- **WHEN** the game build changes and the energy bar is still broken
- **THEN** the one-line message is printed again on the first login

#### Scenario: Addon updated
- **WHEN** the addon is updated to a new version on the same game build and the energy bar is still broken
- **THEN** the one-line message is printed again on the first login

#### Scenario: Part the character doesn't use
- **WHEN** combo points are broken and a warrior logs in
- **THEN** no message names combo points, and a rogue logging in later on the same build is told

#### Scenario: Alt finds a new failure
- **WHEN** an alt of another class logs in on the same build and a part that was fine on the first character is broken for it
- **THEN** one line names that part

### Requirement: Crit flag is checked on the first hit on the target
The addon SHALL check whether the critical-hit flag is readable on every combat event on the player's target, whatever trigger is in effect. The first time in a session it is hidden from addons, crit splatters SHALL be off for the session; while a crit trigger is in effect the player SHALL be told in one line, at most once per game build.

#### Scenario: Crit flag readable
- **WHEN** the player's target takes its first hit of the session and the crit flag is readable
- **THEN** nothing is printed and crit splatters work as usual

#### Scenario: Crit flag hidden after a patch
- **WHEN** the first hit on the target carries a crit flag hidden from addons
- **THEN** one line says crit splatters are off, and later hits print nothing more

### Requirement: Results are kept in the saved variables
The addon SHALL save the latest check results in its saved variables, one readable line per check with what was seen, together with the date and the game build they were taken on, so they can be read after a `/reload` or logout.

#### Scenario: Owner reads the record
- **WHEN** the player logs in, then reloads the UI
- **THEN** the saved variables hold a self-check record with the build, the date and one line per check

### Requirement: /bs debug re-runs the checks
`/bs debug` SHALL re-run the login checks, print and save their result lines with its other diagnostics, and switch parts off or back on to match. It SHALL NOT print the one-line announcement. No other command or setting SHALL be added for the self-check.

#### Scenario: Re-check after a wrong result
- **WHEN** a part was switched off at login and its check passes when the player runs `/bs debug`
- **THEN** the part works again and the debug output shows the check as passed

#### Scenario: Help text
- **WHEN** the player runs `/bs help`
- **THEN** no separate self-test command is listed
