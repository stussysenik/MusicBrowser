# A-Z Drag-to-Scrub Section Index

## MODIFIED Requirements

### Requirement: Section index supports continuous drag gesture
The SectionIndexRail MUST respond to a continuous DragGesture, mapping vertical position to letter selection via GeometryReader. Each letter change triggers haptic feedback and scrolls the song list.

#### Scenario: User drags finger down the A-Z rail
Given the user touches the A-Z rail and drags downward
When the finger crosses from one letter zone to the next
Then the active letter updates, haptic fires, and ScrollViewReader scrolls to the first song matching that letter

#### Scenario: User lifts finger from rail
Given the user is actively dragging the rail
When the finger is lifted
Then the active letter indicator and floating bubble fade out with animation

### Requirement: Floating bubble shows current letter during drag
A floating bubble overlay MUST appear to the left of the rail during drag interaction, displaying the currently selected letter in large text.

#### Scenario: Bubble appears during drag
Given the user is dragging the A-Z rail
When a letter is active
Then a 52x52 bubble with the letter appears 62pt to the left of the rail

### Requirement: Rail adapts to available height
Letter heights MUST be computed dynamically from GeometryReader, fitting all 27 letters (A-Z + #) into available vertical space.

#### Scenario: Rail on different screen sizes
Given the rail is displayed on screens of varying height
When the view appears
Then each letter occupies `availableHeight / 27` vertical space

## REMOVED Requirements

### Requirement: Individual tap buttons per letter
The previous tap-only Button-per-letter implementation MUST be removed in favor of the drag gesture.
