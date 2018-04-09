cimport numpy as np

cdef:
    char _WHITE
    char _BLACK
    char _EMPTY


cdef class GameState:
    """State of a game of Go and some basic functions to interact with it
    """
    cdef:
        public np.ndarray board, check_board, liberty_counts, stone_ages
        public unsigned char size
        public char current_player
        public tuple ko
        public float komi
        public list handicaps, history, liberty_sets, group_sets
        public list __legal_move_cache, __legal_eyes_cache
        public long num_black_prisoners, num_white_prisoners, passes_white, passes_black
        public bint enforce_superko, is_end_of_game
        public set previous_hashes
        public unsigned long long current_hash

    cpdef list get_groups_around(self, tuple position)

    cdef bint on_board(self, long x, long y)

    cpdef list get_neighbors(self, tuple position)

    cdef bint is_eyeish(self, tuple position, long owner)

    cpdef bint is_eye(self, tuple position, long owner, object stack=*)

    cpdef list get_legal_moves(self, bint include_eyes=*)
