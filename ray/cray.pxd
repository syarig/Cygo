
cdef extern from "src/GoBoard.h":
    ctypedef struct game_info_t
    const int PURE_BOARD_SIZE
    const int RESIGN
    int pure_board_size
    int CalculateScore( game_info_t *game )
    void SetBoardSize( int size )
    game_info_t *AllocateGame();
    void FreeGame( game_info_t *game );
    void CopyGame( game_info_t *dst, game_info_t *src )
    void InitializeConst()
    void InitializeBoard( game_info_t *game )
    void SetKomi( double new_komi )
    void PutStone( game_info_t *game, int pos, int color )

cdef extern from "src/DynamicKomi.h":
    void SetHandicapNum( int num )

cdef extern from "src/Message.h":
    void PrintBoard( game_info_t *game )

cdef extern from "src/Nakade.h":
    void InitializeNakadeHash()

cdef extern from "src/Point.h":
    int StringToInteger( char *cpos )
    void IntegerToString( int pos, char *cpos )

cdef extern from "src/Playout.h":
    void InitializeMtArray()
    int Playout(game_info_t *po_game, int turn_col, int my_col, int thread_id)

cdef extern from "src/UctSearch.h":
    const int THREAD_MAX
    void SetParameter()
    void InitializeSearchSetting()
    void InitializeUctSearch()
    void Statistic( game_info_t *game, int winner )

cdef extern from "src/Rating.h":
    char po_params_path[1024]
    void InitializeRating()

cdef extern from "src/UctRating.h":
    char uct_params_path[1024]
    void InitializeUctRating()
    void SetNeighbor()


cdef extern from "src/ZobristHash.h":
    void InitializeHash()
    void InitializeUctHash()
