"""
demo_audio.py

Small demo script to test the AudioManager independently of the main game.

Controls:
- 1 : set context "menu"
- 2 : set context "match"
- 3 : set context "victory"
- 4 : set context "defeat"
- C : play SFX "click"
- P : play SFX "basket"
- S : play SFX "whistle"
- M : toggle mute
- ESC or window close: quit
"""

import pygame
from audio_manager import AudioManager


def main() -> None:
    pygame.init()
    screen = pygame.display.set_mode((800, 600))
    pygame.display.set_caption("AudioManager demo")
    clock = pygame.time.Clock()

    audio = AudioManager()
    audio.init_audio()
    audio.set_context("menu")

    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False

            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False

                elif event.key == pygame.K_1:
                    audio.set_context("menu")
                elif event.key == pygame.K_2:
                    audio.set_context("match")
                elif event.key == pygame.K_3:
                    audio.set_context("victory")
                elif event.key == pygame.K_4:
                    audio.set_context("defeat")

                elif event.key == pygame.K_c:
                    audio.play_sfx("click")
                elif event.key == pygame.K_p:
                    audio.play_sfx("basket")
                elif event.key == pygame.K_s:
                    audio.play_sfx("whistle")
                elif event.key == pygame.K_m:
                    audio.toggle_mute()

        screen.fill((20, 20, 20))
        pygame.display.flip()
        clock.tick(60)

    pygame.quit()


if __name__ == "__main__":
    main()
