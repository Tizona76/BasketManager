Audio module for a Pygame project
=================================

Goal
----
Implement a generic AudioManager class for a Pygame game.

You ONLY work on:
- audio_manager.py

Optionally you can also edit:
- demo_audio.py (if you need minor adjustments for testing)

Please DO NOT change:
- The public method names and signatures of the AudioManager class:
  * __init__(self)
  * init_audio(self)
  * set_context(self, context: str)
  * play_sfx(self, event: str)
  * set_volume(self, music_volume: float, sfx_volume: float)
  * toggle_mute(self)

You are allowed to:
- Add private helper methods (e.g. _load_music(), _load_sfx(), etc.)
- Add private attributes if needed.
- Choose reasonable default mixer settings (frequency, channels, etc.).

Expected behavior
-----------------
1) init_audio()
   - Initialize pygame.mixer.
   - Load music and SFX assets.
   - Fill self.music_files and self.sfx_sounds dictionaries.
   - Apply initial volumes (self.music_volume, self.sfx_volume).
   - Set self.initialized = True when done.

2) set_context(context)
   - Changes the current background music according to the given context.
   - Examples of context keys:
       "menu"
       "menu_season"
       "match"
       "victory"
       "defeat"
   - If context is unknown, fail gracefully (do nothing).
   - If muted, you may still switch the track but keep volume at 0.

3) play_sfx(event)
   - Plays a short sound effect corresponding to an event name.
   - Example event keys:
       "click"
       "hover"
       "basket"
       "whistle"
   - If event is unknown or not loaded, do nothing.
   - If audio is muted, do nothing.

4) set_volume(music_volume, sfx_volume)
   - Clamp values between 0.0 and 1.0.
   - Update internal volumes.
   - Immediately apply them to the currently playing music and all SFX.

5) toggle_mute()
   - If not muted:
       * Save current volumes in temporary attributes.
       * Set volumes to 0.0 (music + SFX).
       * Apply to mixer.
       * Set self.muted = True.
   - If already muted:
       * Restore previous volumes.
       * Apply to mixer.
       * Set self.muted = False.

Assets
------
You can assume audio files are located in folders such as:
- "assets/audio/music/..."
- "assets/audio/sfx/..."

You are free to propose a simple, clean organization for the files
and document it in comments inside audio_manager.py.

Testing
-------
Use demo_audio.py to test your implementation.

Controls:
- 1, 2, 3, 4 : change music context
- C, P, S    : play SFX
- M          : toggle mute
- ESC / close window: quit

Deliverables
------------
- A working implementation of the AudioManager class in audio_manager.py
- Updates or comments in demo_audio.py if needed to test your work
- Short comments in code explaining:
  * where music files are loaded
  * where SFX files are loaded
  * how contexts and events are mapped
