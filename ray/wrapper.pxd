from ray cimport cray

cdef class Ray:
    cdef:
        cray.game_info_t *game
        cray.game_info_t **po_games

    cpdef alloc_po_game(self, int tid=?)

    cpdef free_po_game(self, int tid=?)

    cpdef copy_game(self, int tid=?)

    cpdef put_stone(self, int x, int y, int color, int tid=?, bint playout=?)

    cpdef int playout(self, int turn_col, int my_col, int tid=?)

    cpdef print_board(self)

    cpdef set_komi(self, double komi)

    cpdef gtp_boardsize(self, int size)

    cpdef gtp_clearboard(self)

