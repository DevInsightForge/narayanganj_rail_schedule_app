# Narayanganj Rail Schedule

Mobile-first Flutter app for browsing Narayanganj commuter rail departures with clean architecture, BLoC state management, bundled offline schedule data, persisted selections, and remote schedule refresh support.

## Project Overview

Narayanganj Rail Schedule is a commuter app for the Dhaka-Narayanganj rail route. It is built to answer the most important passenger question quickly: what is the next train for my trip, and do I need to leave now?

Instead of showing the schedule as a dense timetable, the app turns it into a simple mobile-friendly board with the next departure, travel path, and backup options.

## Summary

- check the next available commuter train at a glance
- switch direction, boarding, and destination quickly
- see trip timing, station sequence, and later backup trains
- keep working with fallback schedule data using `API > local storage > bundled static`

## Showcase

### Header And Decision Panel

![Header and decision panel](docs/screenshots/01-header-decision-panel.png)

### Journey Trace Panel

![Journey trace panel](docs/screenshots/02-journey-trace-panel.png)

### Upcoming Trains Panel

![Upcoming trains panel](docs/screenshots/03-upcoming-trains-panel.png)

## Release & Compliance

- Google Play pre-release checklist: `docs/google_play_compliance.md`
