
import gtp
from libc.stdio cimport sprintf
from libc.stdlib cimport malloc
from ray cimport cray

(EMPTY, BLACK, WHITE, OB, MAX) = range(5)

cdef class Ray:
    def __cinit__(self, char *up_path, char *sp_path):
        sprintf(cray.uct_params_path, "%s/uct_params", up_path)
        sprintf(cray.po_params_path, "%s/sim_params", sp_path)

        self.po_games = <cray.game_info_t **>malloc(cray.THREAD_MAX * sizeof(cray.game_info_t *))
        self.game = cray.AllocateGame()
        cray.InitializeBoard(self.game)

        cray.InitializeConst()
        cray.InitializeRating()
        cray.InitializeUctRating()
        cray.InitializeUctSearch()
        cray.InitializeSearchSetting()
        cray.InitializeHash()
        cray.InitializeUctHash()
        cray.SetNeighbor()
        cray.InitializeMtArray()

    cpdef alloc_po_game(self, int tid=0):
        self.po_games[tid] = cray.AllocateGame()

    cpdef free_po_game(self, int tid=0):
        cray.FreeGame(self.po_games[tid])

    cpdef copy_game(self, int tid=0):
        cray.CopyGame(self.po_games[tid], self.game)

    cpdef put_stone(self, int x, int y, int color, int tid=0, bint playout=False):
        cdef:
            bytes gtp_pos = gtp.gtp_vertex((x, y)).encode('utf8')
            int point = cray.StringToInteger(gtp_pos)

        if point != cray.RESIGN:
            if not playout:
                cray.PutStone(self.game, point, color)
            else:
                cray.PutStone(self.po_games[tid], point, color)


    cpdef int playout(self, int turn_col, int my_col, int tid=0):
        return cray.Playout(self.po_games[tid], turn_col, my_col, tid)

    cpdef print_board(self):
        cray.PrintBoard(self.game)

    cpdef set_komi(self, double komi):
        cray.SetKomi(komi)

    cpdef gtp_boardsize(self, int size):
        if cray.pure_board_size != size and 0 < size <= cray.PURE_BOARD_SIZE:
            cray.SetBoardSize(size)
            cray.SetParameter()
            cray.SetNeighbor()
            cray.InitializeNakadeHash()

        cray.FreeGame(self.game)
        self.game = cray.AllocateGame()
        cray.InitializeBoard(self.game)
        cray.InitializeSearchSetting()
        cray.InitializeUctHash()
        cray.InitializeMtArray()

    cpdef gtp_clearboard(self):
        cray.SetHandicapNum(0)
        cray.FreeGame(self.game)
        self.game = cray.AllocateGame()
        cray.InitializeBoard(self.game)
        cray.InitializeSearchSetting()
        cray.InitializeUctHash()
        cray.InitializeMtArray()

    def __dealloc__(self):
        cray.FreeGame(self.game)


