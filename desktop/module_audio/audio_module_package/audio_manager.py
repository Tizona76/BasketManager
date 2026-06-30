"""
audio_manager.py

This module defines a generic AudioManager for a Pygame project.

IMPORTANT FOR DEVELOPER:
- Do NOT change the public method names or their arguments.
- You are free to add private helper methods or attributes if needed.
- The goal is to provide a reusable, clean audio layer:
  * background music per "context" (e.g. 'menu', 'match', 'victory', 'defeat')
  * sound effects (e.g. 'click', 'hover', 'basket', 'whistle')
"""

import pygame
from typing import Dict, Optional


class AudioManager:
    def __init__(self) -> None:
        """
        Initialize internal state only.
        Do NOT call pygame.init() here.
        Do NOT load sounds or music files yet.

        This constructor should:
        - set internal flags (initialized, muted, etc.)
        - prepare dictionaries for music / sfx mapping
        """
        self.initialized: bool = False
        self.muted: bool = False
        self.current_context: Optional[str] = None

        # Default volumes (0.0 to 1.0)
        self.music_volume: float = 0.5
        self.sfx_volume: float = 0.7

        # Mapping between context names and music file paths
        # Example expected keys: "menu", "menu_season", "match", "victory", "defeat"
        self.music_files: Dict[str, str] = {}

        # Mapping between event names and loaded pygame.mixer.Sound objects
        # Example expected keys: "click", "hover", "basket", "whistle"
        self.sfx_sounds: Dict[str, "pygame.mixer.Sound"] = {}

    def init_audio(self) -> None:
        """
        Initialize pygame.mixer and load audio assets.

        TODO for developer:
        - Initialize pygame.mixer (if not already initialized).
        - Configure mixer frequency / channels if needed.
        - Load all music and SFX files into the dictionaries:
            self.music_files[context_name] = "path/to/music_file.ogg"
            self.sfx_sounds[event_name] = pygame.mixer.Sound("path/to/sfx.wav")
        - Apply initial volumes (self.music_volume, self.sfx_volume).
        - Set self.initialized = True when done.

        This method will be called ONCE at game start by the main program.
        """
        raise NotImplementedError("init_audio() must be implemented by the developer.")

    def set_context(self, context: str) -> None:
        """
        Change background music according to the given context.

        :param context: A logical context name, e.g.:
                        'menu', 'menu_season', 'match', 'victory', 'defeat'

        TODO for developer:
        - If audio is not initialized, return safely.
        - If the context is the same as self.current_context, you may ignore.
        - Fade out current music if needed.
        - Look up music file in self.music_files using the context key.
        - Start playing the new music in loop with the current music volume.
        - Store the current context in self.current_context.
        """
        raise NotImplementedError("set_context() must be implemented by the developer.")

    def play_sfx(self, event: str) -> None:
        """
        Play a short sound effect corresponding to a logical event.

        :param event: A logical event name, e.g.:
                      'click', 'hover', 'basket', 'whistle', etc.

        TODO for developer:
        - If audio is not initialized, return safely.
        - Look up the event in self.sfx_sounds.
        - Play the associated sound once with the current SFX volume.
        - If muted, do NOT play any sound.
        """
        raise NotImplementedError("play_sfx() must be implemented by the developer.")

    def set_volume(self, music_volume: float, sfx_volume: float) -> None:
        """
        Update music and SFX volumes.

        :param music_volume: Float between 0.0 and 1.0 for background music.
        :param sfx_volume: Float between 0.0 and 1.0 for sound effects.

        TODO for developer:
        - Clamp values between 0.0 and 1.0.
        - Store them in self.music_volume and self.sfx_volume.
        - Immediately apply new volumes:
            * on the current music channel
            * on all loaded SFX sounds (set_volume on each Sound)
        """
        raise NotImplementedError("set_volume() must be implemented by the developer.")

    def toggle_mute(self) -> None:
        """
        Toggle global mute/unmute for all audio.

        TODO for developer:
        - If currently unmuted:
            * remember current volumes (you can store them in temp vars)
            * set music and SFX volumes to 0.0
            * update pygame mixer accordingly
            * set self.muted = True
        - If currently muted:
            * restore previous volumes
            * update pygame mixer accordingly
            * set self.muted = False
        """
        raise NotImplementedError("toggle_mute() must be implemented by the developer.")
