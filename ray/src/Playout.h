//
// Created by k14009kk on 2017/06/17.
//

#ifndef MCTS_ROLLOUT_ROLLOUT_H
#define MCTS_ROLLOUT_ROLLOUT_H

void InitializeMtArray();

int Playout(game_info_t *po_game, int turn_col, int my_col, int thread_id);

#endif //MCTS_ROLLOUT_RAYPLAYOUT_H
