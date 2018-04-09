"""Policy players"""
import numpy as np
from alphago import go
from operator import itemgetter


class GreedyPolicyPlayer(object):
    """A player that uses a greedy policy (i.e. chooses the highest probability
       move each turn)
    """

    def __init__(self, policy_function, pass_when_offered=False, move_limit=None):
        self.policy = policy_function
        self.pass_when_offered = pass_when_offered
        self.move_limit = move_limit

    def get_move(self, state):
        # check move limit
        if self.move_limit is not None and len(state.history) > self.move_limit:
            return go.PASS

        # check if pass was offered and we want to pass
        if self.pass_when_offered:
            if len(state.history) > 100 and state.history[-1] == go.PASS:
                return go.PASS

        # list with sensible moves
        sensible_moves = [move for move in state.get_legal_moves(include_eyes=False)]

        # check if there are sensible moves left to do
        if len(sensible_moves) > 0:
            move_probs = self.policy.eval_state(state, sensible_moves)
            max_prob = max(move_probs, key=itemgetter(1))
            return max_prob[0]

        # No 'sensible' moves available, so do pass move
        return go.PASS


class ProbabilisticPolicyPlayer(object):
    """A player that samples a move in proportion to the probability given by the
       policy.
       By manipulating the 'temperature', moves can be pushed towards totally random
       (high temperature) or towards greedy play (low temperature)
    """

    def __init__(self, policy_function, temperature=1.0, pass_when_offered=False,
                 move_limit=None, greedy_start=None):
        assert(temperature > 0.0)
        self.policy = policy_function
        self.move_limit = move_limit
        self.beta = 1.0 / temperature
        self.pass_when_offered = pass_when_offered
        if greedy_start is None:
            self.greedy_start = move_limit * 2

    def apply_temperature(self, distribution):
        log_probabilities = np.log(distribution)
        # apply beta exponent to probabilities (in log space)
        log_probabilities = log_probabilities * self.beta
        # scale probabilities to a more numerically stable range (in log space)
        log_probabilities = log_probabilities - log_probabilities.max()
        # convert back from log space
        probabilities = np.exp(log_probabilities)
        # re-normalize the distribution
        return probabilities / probabilities.sum()

    def get_move(self, state):
        hist_len = len(state.history)
        # check move limit
        if self.move_limit is not None and hist_len > self.move_limit:
            return go.PASS

        # check if pass was offered and we want to pass
        if self.pass_when_offered:
            if hist_len > 100 and state.history[-1] == go.PASS:
                return go.PASS

        # list with 'sensible' moves
        sensible_moves = [move for move in state.get_legal_moves(include_eyes=False)]

        # check if there are 'sensible' moves left to do
        if len(sensible_moves) > 0:

            move_probs = self.policy.eval_state(state, sensible_moves)

            if hist_len >= self.greedy_start:
                # greedy

                max_prob = max(move_probs, key=itemgetter(1))
                return max_prob[0]
            else:
                # probabilistic

                # zip(*list) is like the 'transpose' of zip;
                # zip(*zip([1,2,3], [4,5,6])) is [(1,2,3), (4,5,6)]
                moves, probabilities = zip(*move_probs)
                # apply 'temperature' to the distribution
                probabilities = self.apply_temperature(probabilities)
                # numpy interprets a list of tuples as 2D, so we must choose an
                # _index_ of moves then apply it in 2 steps
                choice_idx = np.random.choice(len(moves), p=probabilities)
                return moves[choice_idx]

        # No 'sensible' moves available, so do pass move
        return go.PASS

    def get_moves(self, states):
        """Batch version of get_move. A list of moves is returned (one per state)
        """
        sensible_move_lists = [list(st.get_legal_moves(include_eyes=False)) for st in states]
        all_moves_distributions = self.policy.batch_eval_state(states, sensible_move_lists)
        move_list = [None] * len(states)

        for i, move_probs in enumerate(all_moves_distributions):
            # if len(move_probs) == 0 or len(states[i].history) > self.move_limit:
            move_probs_list = list(move_probs)
            n_moves = len(move_probs_list)
            hist_len = len(states[i].history)

            if n_moves == 0 or hist_len > self.move_limit:
                move_list[i] = go.PASS
            else:
                if hist_len >= self.greedy_start:
                    # greedy

                    # max_prob = max(move_probs, key=itemgetter(1))
                    max_prob = max(move_probs_list, key=itemgetter(1))
                    move_list[i] = max_prob[0]
                else:
                    # probabilistic

                    moves, probabilities = zip(*move_probs_list)
                    # apply 'temperature' to the distribution
                    probabilities = self.apply_temperature(probabilities)
                    # numpy interprets a list of tuples as 2D, so we must choose an
                    # _index_ of moves then apply it in 2 steps
                    choice_idx = np.random.choice(n_moves, p=probabilities)
                    move_list[i] = moves[choice_idx]
        return move_list

class RolloutPlayer(object):
    """A player that samples a move in proportion to the probability given by the
       policy.
       By manipulating the 'temperature', moves can be pushed towards totally random
       (high temperature) or towards greedy play (low temperature)
    """

    def __init__(self, rollout_function, temperature=1.0, pass_when_offered=False,
                 move_limit=None, greedy_start=None):
        assert(temperature > 0.0)
        self.policy = rollout_function
        self.move_limit = move_limit
        self.beta = 1.0 / temperature
        self.pass_when_offered = pass_when_offered
        self.greedy_start = greedy_start

    def apply_temperature(self, distribution):
        log_probabilities = np.log(distribution)
        # apply beta exponent to probabilities (in log space)
        log_probabilities = log_probabilities * self.beta
        # scale probabilities to a more numerically stable range (in log space)
        log_probabilities = log_probabilities - log_probabilities.max()
        # convert back from log space
        probabilities = np.exp(log_probabilities)
        # re-normalize the distribution
        return probabilities / probabilities.sum()

    def get_move(self, state):
        # check move limit
        if self.move_limit is not None and len(state.history) > self.move_limit:
            return go.PASS

        # check if pass was offered and we want to pass
        if self.pass_when_offered:
            if len(state.history) > 100 and state.history[-1] == go.PASS:
                return go.PASS

        # list with 'sensible' moves
        sensible_moves = [move for move in state.get_legal_moves(include_eyes=False)]

        # check if there are 'sensible' moves left to do
        if len(sensible_moves) > 0:

            move_probs = self.policy.eval_state(state, sensible_moves)

            if self.greedy_start is not None and len(state.history) >= self.greedy_start:
                # greedy

                max_prob = max(move_probs, key=itemgetter(1))
                return max_prob[0]
            else:
                # probabilistic

                # zip(*list) is like the 'transpose' of zip;
                # zip(*zip([1,2,3], [4,5,6])) is [(1,2,3), (4,5,6)]
                moves, probabilities = zip(*move_probs)
                # apply 'temperature' to the distribution
                probabilities = self.apply_temperature(probabilities)
                # numpy interprets a list of tuples as 2D, so we must choose an
                # _index_ of moves then apply it in 2 steps
                choice_idx = np.random.choice(len(moves), p=probabilities)
                return moves[choice_idx]

        # No 'sensible' moves available, so do pass move
        return go.PASS

    def get_moves(self, states):
        """Batch version of get_move. A list of moves is returned (one per state)
        """
        sensible_move_lists = [[move for move in st.get_legal_moves(include_eyes=False)]
                               for st in states]
        all_moves_distributions = self.policy.batch_eval_state(states, sensible_move_lists)
        move_list = [None] * len(states)
        for i, move_probs in enumerate(all_moves_distributions):
            move_probs_list = list(move_probs)
            if len(move_probs_list) == 0 or len(states[i].history) > self.move_limit:
                move_list[i] = go.PASS
            else:
                if self.greedy_start is not None and len(states[i].history) >= self.greedy_start:
                    # greedy

                    max_prob = max(move_probs_list, key=itemgetter(1))
                    move_list[i] = max_prob[0]
                else:
                    # probabilistic

                    moves, probabilities = zip(*move_probs_list)
                    # apply 'temperature' to the distribution
                    probabilities = self.apply_temperature(probabilities)
                    # numpy interprets a list of tuples as 2D, so we must choose an
                    # _index_ of moves then apply it in 2 steps
                    choice_idx = np.random.choice(len(moves), p=probabilities)
                    move_list[i] = moves[choice_idx]
        return move_list


class ValuePlayer(object):
    """A player that samples a move in proportion to the probability given by the
       value policy.

       By manipulating the 'temperature', moves can be pushed towards totally random
       (high temperature) or towards greedy play (low temperature)

       greedy_start can be used to force greedy play as of move #greedy_start
    """

    def __init__(self, value_function, temperature=1.0, pass_when_offered=False,
                 move_limit=None, greedy_start=None):
        assert(temperature > 0.0)
        self.pass_when_offered = pass_when_offered
        self.greedy_start = greedy_start
        self.beta = 1.0 / temperature
        self.move_limit = move_limit
        self.value = value_function

    def apply_temperature(self, distribution):
        log_probabilities = np.log(distribution)
        # apply beta exponent to probabilities (in log space)
        log_probabilities = log_probabilities * self.beta
        # scale probabilities to a more numerically stable range (in log space)
        log_probabilities = log_probabilities - log_probabilities.max()
        # convert back from log space
        probabilities = np.exp(log_probabilities)
        # re-normalize the distribution
        return probabilities / probabilities.sum()

    def get_move(self, state):
        # check move limit
        if self.move_limit is not None and len(state.history()) > self.move_limit:
            return go.PASS

        # check if pass was offered and we want to pass
        if self.pass_when_offered:
            if len(state.history) > 100 and state.history[-1] == go.PASS:
                return go.PASS

        # list with 'sensible' moves
        sensible_moves = [move for move in state.get_legal_moves(include_eyes=False)]

        # check if there are 'sensible' moves left to do
        if len(sensible_moves) > 0:
            # list with legal moves
            legal_moves = [move for move in state.get_legal_moves()]

            # generate all possible next states
            state_list = [state.copy() for _ in legal_moves]
            for st, mv in zip(state_list, legal_moves):
                st.do_move(mv)

            # evaluate all possble states
            probabilities = [self.value.eval_state(next_state) for next_state in state_list]

            if self.greedy_start is not None and len(state.history) >= self.greedy_start:
                # greedy play

                move_probs = zip(legal_moves, probabilities)
                max_prob = max(move_probs, key=itemgetter(1))
                return max_prob[0]
            else:
                # probabilistic play

                # apply 'temperature' to the distribution
                probabilities = self.apply_temperature(probabilities)

                # numpy interprets a list of tuples as 2D, so we must choose an
                # _index_ of moves then apply it in 2 steps
                choice_idx = np.random.choice(len(legal_moves), p=probabilities)
                return legal_moves[choice_idx]

        # No 'sensible' moves available, so do pass move
        return go.PASS
