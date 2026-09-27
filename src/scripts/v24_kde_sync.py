#!/usr/bin/env python3
"""Refresh only KDE/Qt colors from the active Serpantinum palette."""
import v24_appearance_sync as sync
state = sync.load_manifest()
if sync.sync_kde(sync.palette("dark"), state):
    sync.save_manifest(state)
print("KDE/Qt palette updated. Reopen applications to load their new colors.")
