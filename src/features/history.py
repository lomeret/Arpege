import copy


class HistoryManager:
    """Pile d'annulation/rétablissement basée sur des instantanés d'état."""

    def __init__(self, max_depth=50):
        self.max_depth = max_depth
        self.undo_stack = []
        self.redo_stack = []

    def push(self, state):
        """Enregistre un instantané avant une modification et invalide le redo."""
        self.undo_stack.append(copy.deepcopy(state))
        if len(self.undo_stack) > self.max_depth:
            self.undo_stack.pop(0)
        self.redo_stack.clear()

    def undo(self, current_state):
        """Retourne l'état précédent, ou None si la pile est vide."""
        if not self.undo_stack:
            return None
        self.redo_stack.append(copy.deepcopy(current_state))
        return self.undo_stack.pop()

    def redo(self, current_state):
        """Retourne l'état suivant, ou None si la pile est vide."""
        if not self.redo_stack:
            return None
        self.undo_stack.append(copy.deepcopy(current_state))
        return self.redo_stack.pop()

    def can_undo(self):
        return len(self.undo_stack) > 0

    def can_redo(self):
        return len(self.redo_stack) > 0

    def clear(self):
        self.undo_stack.clear()
        self.redo_stack.clear()
