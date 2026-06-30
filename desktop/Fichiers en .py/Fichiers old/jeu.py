        # ------ États et configuration ------
        self.etat = "menu"  # Ancienne variable `etat`
        self.clock = pygame.time.Clock()
        self.running = True
    def executer(self):
        """Remplace la boucle principale existante"""
        while self.running:
            self._gerer_evenements()
            self._mettre_a_jour()
            self._afficher()
            self.clock.tick(30)  # Conservez votre FPS actuel
    def _gerer_evenements(self):
        """Migre la gestion des événements"""
        for event in pygame.event.get():
            # Événements globaux
            if event.type == pygame.QUIT:
                self.running = False
            
            # Délègue aux méthodes d'état
            if self.etat == "menu":
                self._gerer_menu(event)
            elif self.etat == "selection":
                self._gerer_selection(event)
    def _gerer_menu(self, event):
        """Migrez ici le code de gestion du menu"""
        if event.type == pygame.MOUSEBUTTONDOWN:
            pos = pygame.mouse.get_pos()
            if bouton_creer.collidepoint(pos):  # Conservez vos boutons existants
                self.etat = "selection"
            elif bouton_gestion_menu.collidepoint(pos):
                self.etat = "gestion"
    def _afficher(self):
        """Migrez ici les appels aux anciennes fonctions dessiner_*()"""
        self.FENETRE.fill(self.COULEURS['BLANC'])
        
        if self.etat == "menu":
            dessiner_menu()  # Appel temporaire à l'ancienne fonction
        elif self.etat == "selection":
            dessiner_selection()
        
        pygame.display.flip()
