## ADDED Requirements

### Requirement: Delta added
Fixture requirement that exists only in an in-flight change delta.

#### Scenario: Delta works
- **WHEN** anything
- **THEN** something

## MODIFIED Requirements

### Requirement: Alpha covered
Fixture requirement modified by the change, which adds a scenario.

#### Scenario: Alpha works
- **WHEN** anything
- **THEN** something

#### Scenario: Alpha also works
- **WHEN** anything else
- **THEN** something else

## REMOVED Requirements

### Requirement: Removed thing
**Reason**: Fixture: headings in a REMOVED section are ignored.
**Migration**: None.

## RENAMED Requirements

- FROM: `### Requirement: Old name`
- TO: `### Requirement: New name`
