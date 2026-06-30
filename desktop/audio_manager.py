import pygame
import os
from typing import Dict, Optional

class AudioManager:
    def __init__(self) -> None:
        self.initialized: bool = False
        self.muted: bool = False
        self.current_context: Optional[str] = None
        self.music_volume: float = 0.5
        self.sfx_volume: float = 0.7
        self._music_dir = os.path.join("assets", "audio", "music")
        self._sfx_dir = os.path.join("assets", "audio", "sfx")
        self.music_files: Dict[str, str] = {}
        self.sfx_sounds: Dict[str, "pygame.mixer.Sound"] = {}
        self._prev_music_volume: Optional[float] = None
        self._prev_sfx_volume: Optional[float] = None

    def init_audio(self) -> None:
        if self.initialized:
            return
        try:
            pygame.mixer.init(frequency=44100, size=-16, channels=2, buffer=512)
        except Exception as e:
            print(f"[AudioManager] Warning: mixer.init() failed: {e}")
        self.music_files = {
            "menu": os.path.join(self._music_dir, "menu.wav"),
            "match": os.path.join(self._music_dir, "match.wav"),
            "victory": os.path.join(self._music_dir, "victory.wav"),
            "defeat": os.path.join(self._music_dir, "defeat.wav"),
            "tournois": os.path.join(self._music_dir, "tournois.wav"),
        }

        sfx_map = {
            "click": os.path.join(self._sfx_dir, "click.wav"),
            "basket": os.path.join(self._sfx_dir, "basket.wav"),
            "whistle": os.path.join(self._sfx_dir, "whistle.wav"),
        }
        for key, path in sfx_map.items():
            if os.path.exists(path):
                try:
                    snd = pygame.mixer.Sound(path)
                    snd.set_volume(self.sfx_volume)
                    self.sfx_sounds[key] = snd
                except Exception as e:
                    print(f"[AudioManager] Failed to load SFX '{key}' from {path}: {e}")
            else:
                print(f"[AudioManager] SFX file not found for '{key}': {path}")
        try:
            pygame.mixer.music.set_volume(self.music_volume)
        except Exception:
            pass
        self.initialized = True
        print("[AudioManager] init_audio: completed.")

    def set_context(self, context: str) -> None:
        if not self.initialized:
            print("[AudioManager] set_context called before init_audio(). Ignoring.")
            return
        if context == self.current_context:
            return
        path = self.music_files.get(context)
        if not path:
            print(f"[AudioManager] Unknown music context '{context}'.")
            return
        if not os.path.exists(path):
            print(f"[AudioManager] Music file for context '{context}' not found: {path}")
            self.current_context = context
            return
        try:
            try:
                pygame.mixer.music.fadeout(300)
            except Exception:
                pass
            pygame.mixer.music.load(path)
            vol = 0.0 if self.muted else self.music_volume
            pygame.mixer.music.set_volume(vol)
            pygame.mixer.music.play(-1)
            self.current_context = context
            print(f"[AudioManager] set_context: playing '{context}' -> {path}")
        except Exception as e:
            print(f"[AudioManager] Failed to play music for '{context}': {e}")

    def play_sfx(self, event: str) -> None:
        if not self.initialized:
            print("[AudioManager] play_sfx called before init_audio(). Ignoring.")
            return
        if self.muted:
            return
        snd = self.sfx_sounds.get(event)
        if not snd:
            return
        try:
            snd.set_volume(self.sfx_volume)
            snd.play()
        except Exception as e:
            print(f"[AudioManager] Failed to play SFX '{event}': {e}")

    def set_volume(self, music_volume: float, sfx_volume: float) -> None:
        def clamp(v: float) -> float:
            try:
                vfl = float(v)
            except Exception:
                vfl = 0.0
            return max(0.0, min(1.0, vfl))
        self.music_volume = clamp(music_volume)
        self.sfx_volume = clamp(sfx_volume)
        if not self.initialized:
            return
        try:
            pygame.mixer.music.set_volume(0.0 if self.muted else self.music_volume)
        except Exception:
            pass
        for snd in self.sfx_sounds.values():
            try:
                snd.set_volume(0.0 if self.muted else self.sfx_volume)
            except Exception:
                pass
        print(f"[AudioManager] set_volume: music={self.music_volume}, sfx={self.sfx_volume}")

    def toggle_mute(self) -> None:
        if not self.initialized:
            self.muted = not self.muted
            print(f"[AudioManager] toggle_mute before init. muted={self.muted}")
            return
        if not self.muted:
            self._prev_music_volume = self.music_volume
            self._prev_sfx_volume = self.sfx_volume
            try:
                pygame.mixer.music.set_volume(0.0)
            except Exception:
                pass
            for snd in self.sfx_sounds.values():
                try:
                    snd.set_volume(0.0)
                except Exception:
                    pass
            self.muted = True
            print("[AudioManager] toggle_mute: muted")
        else:
            restore_music = self._prev_music_volume if self._prev_music_volume is not None else self.music_volume
            restore_sfx = self._prev_sfx_volume if self._prev_sfx_volume is not None else self.sfx_volume
            try:
                pygame.mixer.music.set_volume(restore_music)
            except Exception:
                pass
            for snd in self.sfx_sounds.values():
                try:
                    snd.set_volume(restore_sfx)
                except Exception:
                    pass
            self.muted = False
            print("[AudioManager] toggle_mute: unmuted")
