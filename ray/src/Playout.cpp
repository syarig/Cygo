#include <cstring>
#include <cstdio>
#include <array>

#include "GoBoard.h"
#include "Rating.h"
#include "Point.h"
#include "Simulation.h"
#include "UctSearch.h"

#include "Playout.h"


std::mt19937_64 *mt_array[THREAD_MAX];

void InitializeMtArray() {
    for (int i = 0; i < THREAD_MAX; i++) {
        if (mt_array[i]) {
            delete mt_array[i];
        }
        mt_array[i] = new std::mt19937_64((unsigned int)(time(NULL) + i));
    }
}

int Playout(game_info_t *po_game, int turn_col, int my_col, int thread_id) {

    Simulation(po_game, turn_col, mt_array[thread_id]);

    double score = (double)CalculateScore(po_game);

    int final_score = score - dynamic_komi[my_col];
    int winner = 0;
    int result = 0;

    if (final_score > 0) {
        result = (turn_col == S_BLACK ? 1 : -1);
        winner = S_BLACK;
    } else if (final_score < 0){
        winner = S_WHITE;
    }

    Statistic(po_game, winner);

    return result;
}
