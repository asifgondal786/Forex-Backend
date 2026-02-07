# Engagement Firestore Schema and Index Plan

## Collections

### ai_activity
- userId (string)
- type (string)
- message (string)
- timestamp (timestamp)
- emoji (string, optional)
- color (string, optional)

### ai_confidence_history
- userId (string)
- current (number)
- trend (string: up/down/flat)
- change_24h (number)
- reason (string)
- historical (array of number)
- timestamp (timestamp)

### ai_alerts
- userId (string)
- type (string)
- icon (string)
- title (string)
- message (string)
- severity (string: info/warning/success)
- action (string, optional)
- timestamp (timestamp)
- active (boolean)
- expiresAt (timestamp, optional)

### ai_explanations
- userId (string)
- decisionId (string)
- type (string)
- factors (array)
- overallReasoning (string)
- timestamp (timestamp)

### ai_nudges
- userId (string)
- type (string: suggestion/praise/alert/tip)
- emoji (string)
- title (string)
- message (string)
- action (string, optional)
- priority (string: low/medium/high)
- displayUntil (timestamp, optional)
- timestamp (timestamp)
- active (boolean)

### user_progress
- userId (string)
- period (string: day/week/month)
- metrics (map)
- timestamp (timestamp)

### user_achievements
- userId (string)
- title (string)
- description (string)
- seen (boolean)
- timestamp (timestamp)

## Index Plan (suggested)
- ai_activity: userId ASC, timestamp DESC
- ai_confidence_history: userId ASC, timestamp DESC
- ai_alerts: userId ASC, active ASC, timestamp DESC
- ai_nudges: userId ASC, active ASC, timestamp DESC
- user_progress: userId ASC, period ASC, timestamp DESC
- user_achievements: userId ASC, seen ASC, timestamp DESC
