import pygame
from audio_manager import AudioManager

def main():
    # Initialisation Pygame (fenêtre + clock)
    pygame.init()
    screen = pygame.display.set_mode((800, 600))
    pygame.display.set_caption("AudioManager demo")
    clock = pygame.time.Clock()

    # Initialisation de l'audio
    audio = AudioManager()
    audio.init_audio()        # charge les sons / configure mixer
    audio.set_context("menu") # essaie de jouer la musique de menu (menu.ogg)

    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False

            elif event.type == pygame.KEYDOWN:
                # Quitter avec ESC
                if event.key == pygame.K_ESCAPE:
                    running = False

                # Changer de contexte (musique de fond)
                elif event.key == pygame.K_1:
                    print("Contexte: menu")
                    audio.set_context("menu")
                elif event.key == pygame.K_2:
                    print("Contexte: match")
                    audio.set_context("match")
                elif event.key == pygame.K_3:
                    print("Contexte: victory")
                    audio.set_context("victory")
                elif event.key == pygame.K_4:
                    print("Contexte: defeat")
                    audio.set_context("defeat")

                # Effets sonores
                elif event.key == pygame.K_c:
                    print("SFX: click")
                    audio.play_sfx("click")
                elif event.key == pygame.K_b:
                    print("SFX: basket")
                    audio.play_sfx("basket")
                elif event.key == pygame.K_w:
                    print("SFX: whistle")
                    audio.play_sfx("whistle")

                # Mute / unmute
                elif event.key == pygame.K_m:
                    print("Toggle mute")
                    audio.toggle_mute()

        # On affiche juste un fond gris foncé
        screen.fill((30, 30, 30))
        pygame.display.flip()
        clock.tick(60)

    pygame.quit()

if __name__ == "__main__":
    main()
