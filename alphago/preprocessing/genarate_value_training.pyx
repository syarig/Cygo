import os
import sys
import h5py
import warnings
import numpy as np
from alphago import go
from alphago.models.policy import CNNPolicy
from alphago.util import save_gamestate_to_sgf
from alphago.util import sgf_iter_states
from alphago.ai import ProbabilisticPolicyPlayer
from alphago.preprocessing.preprocessing import Preprocess
from util import find_file, chunk_iter

# default settings
DEFAULT_N_TRAINING_PAIRS = 30000000
DEFAULT_MAX_GAME_DEPTH = 500
# play more random
DEFAULT_TEMPERATURE_SL = 1.4
# play greedy
DEFAULT_TEMPERATURE_RL = .0001
DEFAULT_BATCH_SIZE = 10
DEAULT_RANDOM_MOVE = 450
DEFAULT_FILE_NAME = "value_planes.hdf5"

# output values for win and lose
WIN = 1
LOSE = -1


def init_hdf5(h5f, n_features, bd_size):
    try:
        states = h5f.require_dataset(
            'states',
            dtype=np.uint8,
            shape=(1, n_features, bd_size, bd_size),
            maxshape=(None, n_features, bd_size, bd_size),
            # 'None' dimension allows it to grow arbitrarily
            exact=False,
            # allow non-uint8 datasets to be loaded, coerced to uint8
            # TODO chunk size influences speed a lot, find out what high and low values do exactly
            chunks=(1, n_features, bd_size, bd_size),
            # approximately 10MB chunks (bigger for more compression,
            # OK because accessed *in order*)
            compression="lzf")
        winners = h5f.require_dataset(
            'winners',
            dtype=np.int8,
            shape=(1, 1),
            maxshape=(None, 1),
            exact=False,
            chunks=(1024, 1),
            compression="lzf")
    except Exception as e:
        raise e
    return states, winners


def play_batch(player_RL, player_SL, batch_size, preprocessor, i_rand_move, next_idx, sgf_path):
    """Play a batch of games in parallel and return one training pair from each game.

    As described in Silver et al, the method for generating value net training data is as follows:

    * pick a number between 1 and 450
    * use the supervised-learning policy to play a game against itself up to that number of moves.
    * now go off-policy and pick a totally random move
    * play out the rest of the game with the reinforcement-learning policy
    * save the state that occurred *right after* the random move,
    * and the end result of the game, as the training pair
    """

    def do_move(states, moves):
        for st, mv in zip(states, moves):
            if not st.is_end_of_game:
                # Only do more moves if not end of game already
                st.do_move(mv)
        return states

    def do_rand_move(states):
        """Do a uniform-random move over legal moves and record info for
           training. Only gets called once per game.
        """

        # get legal moves and play one at random
        legal_moves = [st.get_legal_moves() for st in states]
        rand_moves = [lm[np.random.choice(len(lm))] for lm in legal_moves]
        states = do_move(states, rand_moves)

        return states

    # Lists of game training pairs (1-hot)
    states = [go.GameState() for _ in range(batch_size)]

    # play player_SL moves
    for _ in range(i_rand_move - 1):
        # Get moves (batch)
        batch_moves = player_SL.get_moves(states)
        # Do moves (black)
        states = do_move(states, batch_moves)

    # remove games that are finished
    states = [state for state in states if not state.is_end_of_game]

    # Make random move
    states = do_rand_move(states)

    # copy all states, these are the generated training data
    states_list = [st.copy() for st in states]  # For later 1hot preprocessing

    # color is random move player colorfrom alphago.util import sgf_iter_states
    color = go.WHITE if i_rand_move % 2 == 0 else go.BLACK

    # play moves with player_RL till game ends
    while True:
        # Get moves (batch)
        batch_moves = player_RL.get_moves(states)
        # Do moves (black)
        states = do_move(states, batch_moves)

        # check if all games are finished
        done = [st.is_end_of_game for st in states]

        if all(done):
            break

    if sgf_path is not None:
        # number different sgf
        sgf_id = next_idx

        for gm in states:
            # add leading '0'
            file_name = str(sgf_id)
            while len(file_name) < 10:
                file_name = '0' + file_name

            # determine winner
            winner_game = 'WHITE' if gm.get_winner() == go.WHITE else 'BLACK'
            random_player = 'WHITE' if color == go.WHITE else 'BLACK'

            # generate file name
            file_name += '_winner_' + winner_game + '_active-player_' + \
                         random_player + '_move_' + str(i_rand_move) + '.sgf'
            # save sgf
            save_gamestate_to_sgf(gm, sgf_path, file_name,
                                  result=winner_game + ' ' + str(i_rand_move))
            # increment sgf id count
            sgf_id += 1

    # Concatenate training examples
    # Convert states to 1-hot and concatenate. X's are game state objects.
    training_states = None if len(states_list) == 0 else np.concatenate(
        [preprocessor.state_to_tensor(state) for state in states_list], axis=0)

    # get winners list relative to 'random move' player color (color)
    # winner BLACK & color Black -> WIN
    # winner WHITE & color WHITE -> WIN
    # winner BLACK & color WHITE -> LOSE
    # winner WHITE & color Black -> LOSE
    actual_batch_size = len(states)
    winners = np.array([WIN if st.get_winner() == color else
                        LOSE for st in states]).reshape(actual_batch_size, 1)
    return training_states, winners


def generate_data(player_RL, player_SL, hdf5_file, n_training_pairs,
                  batch_size, bd_size, features, verbose, sgf_path):
    # used features
    preprocessor = Preprocess(features)
    n_features = preprocessor.output_dim
    # temporary hdf5 file
    tmp_file = os.path.join(os.path.dirname(hdf5_file), ".tmp." + os.path.basename(hdf5_file))
    # open hdf5 file
    h5f = h5py.File(tmp_file, 'w')
    # initialize a new hdf5 file
    h5_states, h5_winners = init_hdf5(h5f, n_features, bd_size)

    # random move distribution administration
    distribution = {key: 0 for key in range(DEAULT_RANDOM_MOVE)}

    if verbose:
        print(str(hdf5_file) + " file initialized.")
        max_value = str(n_training_pairs)

    next_idx = 0
    while True:
        # Randomly choose turn to play uniform random. Move prior will be from SL
        # policy. Moves after will be from RL policy.
        i_rand_move = np.random.choice(range(DEAULT_RANDOM_MOVE))

        # play games
        states, winners = play_batch(player_RL, player_SL, batch_size, preprocessor,
                                     i_rand_move, next_idx, sgf_path)

        if states is not None:
            try:
                # get actual batch size in case any pair was removed
                actual_batch_size = len(states)
                # increment random distribution
                distribution[i_rand_move] += actual_batch_size

                # add states and winners to hdf5 file
                h5_states.resize((next_idx + actual_batch_size, n_features, bd_size, bd_size))
                h5_winners.resize((next_idx + actual_batch_size, 1))
                h5_states[next_idx:] = states
                h5_winners[next_idx:] = winners

                # count saved pairs
                next_idx += actual_batch_size
            except Exception as e:
                warnings.warn("Unknown error occured during batch save to HDF5 file: {}".format(hdf5_file))  # noqa: E501
                raise e

        if verbose:
            # primitive progress indication
            current = str(next_idx)
            while len(current) < len(max_value):
                current = ' ' + current

            line = 'Progress: ' + current + '/' + max_value

            sys.stdout.write('\b' * len(line))
            sys.stdout.write('\r')
            sys.stdout.write(line)
            sys.stdout.flush()

        # stop data generation when at least n_trainings_pairs have been created
        if n_training_pairs <= next_idx:
            break

    # processing complete: rename tmp_file to hdf5_file
    h5f.close()
    os.rename(tmp_file, hdf5_file)
    if verbose:
        print("Value training data succesfull created.")

        # show random move distribution
        print("\nRandom move distribution:")
        for key in range(DEAULT_RANDOM_MOVE):
            print("Random move: " + str(key) + " " + str(distribution[key]))


def generate_sgf(player_RL, player_SL, n_training_pairs, batch_size, features, verbose, sgf_path):
    # used features
    preprocessor = Preprocess(features)

    # random move distribution administration
    distribution = {key: 0 for key in range(DEAULT_RANDOM_MOVE)}

    if verbose:
        max_value = str(n_training_pairs)

    next_idx = 0
    while True:
        # Randomly choose turn to play uniform random. Move prior will be from SL
        # policy. Moves after will be from RL policy.
        i_rand_move = np.random.choice(range(DEAULT_RANDOM_MOVE))

        # play games
        states, winners = play_batch(player_RL, player_SL, batch_size, preprocessor,
                                     i_rand_move, next_idx, sgf_path)
        if states is not None:
            try:
                # get actual batch size in case any pair was removed
                actual_batch_size = len(states)
                # increment random distribution
                distribution[i_rand_move] += actual_batch_size

                # count saved pairs
                next_idx += actual_batch_size
            except Exception as e:
                print(e)

        if verbose:
            # primitive progress indication
            current = str(next_idx)
            while len(current) < len(max_value):
                current = ' ' + current

            line = 'Progress: ' + current + '/' + max_value

            sys.stdout.write('\b' * len(line))
            sys.stdout.write('\r')
            sys.stdout.write(line)
            sys.stdout.flush()

        # stop data generation when at least n_trainings_pairs have been created
        if n_training_pairs <= next_idx:
            break

    # processing complete: rename tmp_file to hdf5_file
    if verbose:
        print("Value training data succesfull created.")

        # show random move distribution
        print("\nRandom move distribution:")
        for key in range(DEAULT_RANDOM_MOVE):
            print("Random move: " + str(key) + " " + str(distribution[key]))


def convert_games(sgf_from, batch_size, preprocessor):
    """Read the given SGF file into an iterable of (input,output) pairs
    for neural network training

    Each input is a GameState converted into one-hot neural net features
    Each output is an action as an (x,y) pair (passes are skipped)

    If this game's size does not match bd_size, a SizeMismatchError is raised
    """
    batch_files = chunk_iter(find_file('sgf', sgf_from), batch_size)
    for batch_file in batch_files:

        states = []
        winners = []
        i_rand_move = None
        n_files = 0
        for file_name in batch_file:
            with open(file_name, 'r') as file_object:
                state_action_iterator = sgf_iter_states(file_object.read(), include_end=False)

            name, ext = os.path.splitext(os.path.basename(file_name))
            splited_underbar = name.split("_")
            i_rand_move = int(splited_underbar[-1])

            try:
                for i, (state, move, player) in enumerate(state_action_iterator):
                    if i == i_rand_move - 1:
                        states.append(state)
                        break
            except Exception as e:
                print(e)
                continue

            winners.append(WIN if splited_underbar[2] == splited_underbar[4] else LOSE)
            n_files += 1


        if len(states) == n_files and len(winners) == n_files:
            training_states = np.concatenate([preprocessor.state_to_tensor(state) for state in states], axis=0)
            winners = np.array(winners).reshape(n_files, 1)
        else:
            training_states = winners = None

        yield i_rand_move, training_states, winners


def generate_data_from_sgf(hdf5_file, batch_size, bd_size, features, verbose, sgf_from):
    # used features
    preprocessor = Preprocess(features)
    n_features = preprocessor.output_dim
    # temporary hdf5 file
    tmp_file = os.path.join(os.path.dirname(hdf5_file), ".tmp." + os.path.basename(hdf5_file))
    # open hdf5 file
    h5f = h5py.File(tmp_file, 'w')
    # initialize a new hdf5 file
    h5_states, h5_winners = init_hdf5(h5f, n_features, bd_size)

    # random move distribution administration
    distribution = {key: 0 for key in range(DEAULT_RANDOM_MOVE)}

    if verbose:
        print(str(hdf5_file) + " file initialized.")

    next_idx = 0

    for i_rand_move, states, winners in convert_games(sgf_from, batch_size, preprocessor):

        if states is not None:
            try:
                # get actual batch size in case any pair was removed
                actual_batch_size = len(states)
                # increment random distribution
                distribution[i_rand_move] += actual_batch_size

                # add states and winners to hdf5 file
                h5_states.resize((next_idx + actual_batch_size, n_features, bd_size, bd_size))
                h5_winners.resize((next_idx + actual_batch_size, 1))
                h5_states[next_idx:] = states
                h5_winners[next_idx:] = winners

                # count saved pairs
                next_idx += actual_batch_size
            except Exception as e:
                warnings.warn("Unknown error occured during batch save to HDF5 file: {}".format(hdf5_file))  # noqa: E501
                raise e

        if verbose:
            # primitive progress indication
            current = str(next_idx)
            line = 'Progress: ' + current

            sys.stdout.write('\b' * len(line))
            sys.stdout.write('\r')
            sys.stdout.write(line)
            sys.stdout.flush()

    # processing complete: rename tmp_file to hdf5_file
    h5f.close()
    os.rename(tmp_file, hdf5_file)
    if verbose:
        print("Value training data succesfull created.")

        # show random move distribution
        print("\nRandom move distribution:")
        for key in range(DEAULT_RANDOM_MOVE):
            print("Random move: " + str(key) + " " + str(distribution[key]))



def handle_arguments(cmd_line_args=None):
    """Run generate data. command-line args may be passed in as a list
    """

    import argparse
    parser = argparse.ArgumentParser(description='Play games used for training'
                                     'value network (third phase of pipeline). '
                                     'The final policy from the RL phase plays '
                                     'against itself and training pairs for value '
                                     'network are generated from the outcome in each '
                                     'games, following an off-policy, uniform random move')
    # required arguments
    parser.add_argument("SL_weights_path", help="Path to file with supervised learning policy weights.")  # noqa: E501
    parser.add_argument("RL_weights_path", help="Path to file with reinforcement learning policy weights.")  # noqa: E501
    parser.add_argument("model_path", help="Path to network architecture file.")
    # optional arguments
    parser.add_argument("--verbose", "-v", help="Turn on verbose mode", default=False, action="store_true")  # noqa: E501
    parser.add_argument("--outfile", "-o", help="Destination to write data (hdf5 file) Default: " + DEFAULT_FILE_NAME, default=DEFAULT_FILE_NAME)  # noqa: E501
    parser.add_argument("--sgf-path", help="If set all sgf will be saved here. Default: None", default=None)  # noqa: E501
    parser.add_argument("--n-training-pairs", help="Number of training pairs to generate. Default: " + str(DEFAULT_N_TRAINING_PAIRS), type=int, default=DEFAULT_N_TRAINING_PAIRS)  # noqa: E501
    parser.add_argument("--batch-size", help="Number of games to run in parallel. Default: " + str(DEFAULT_BATCH_SIZE), type=int, default=DEFAULT_BATCH_SIZE)  # noqa: E501
    parser.add_argument("--features", "-f", help="Comma-separated list of features to compute and store or 'all'. Default: all", default='all')  # noqa: E501
    parser.add_argument("--sl-temperature", help="Distribution temperature of players using SL policies. Default: " + str(DEFAULT_TEMPERATURE_SL), type=float, default=DEFAULT_TEMPERATURE_SL)  # noqa: E501
    parser.add_argument("--rl-temperature", help="Distribution temperature of players using RL policies. Default: " + str(DEFAULT_TEMPERATURE_RL), type=float, default=DEFAULT_TEMPERATURE_RL)  # noqa: E501
    parser.add_argument("--sgf-from", "-F", help="from sgf to hdf5", default=None)  # noqa: E501
    parser.add_argument("--generate-sgf-only", "-S", help="from sgf to hdf5", default=False, action="store_true")  # noqa: E501

    # show help or parse arguments
    if cmd_line_args is None:
        args = parser.parse_args()
    else:
        args = parser.parse_args(cmd_line_args)

    # list with features used for value network
    # features = policy_SL.preprocessor.feature_list
    if args.features.lower() == 'all':
        features = [
            "board",
            "ones",
            "turns_since",
            "liberties",
            "capture_size",
            "self_atari_size",
            "liberties_after",
            "ladder_capture",
            "ladder_escape",
            "sensibleness",
            "color"]
    else:
        features = args.features.split(",")

    # always add colour feature
    if "color" not in features:
        features.append("color")

    # Load SL architecture and weights from file
    policy_SL = CNNPolicy.load_model(args.model_path)
    policy_SL.model.load_weights(args.SL_weights_path)
    # create SL player
    player_SL = ProbabilisticPolicyPlayer(policy_SL, temperature=args.sl_temperature,
                                          move_limit=DEFAULT_MAX_GAME_DEPTH)

    # Load RL architecture and weights from file
    policy_RL = CNNPolicy.load_model(args.model_path)
    policy_RL.model.load_weights(args.RL_weights_path)
    # Create RL player
    # TODO is it better to use greedy player?
    player_RL = ProbabilisticPolicyPlayer(policy_RL, temperature=args.rl_temperature,
                                          move_limit=DEFAULT_MAX_GAME_DEPTH)

    # check if folder exists
    if args.sgf_path is not None and not os.path.exists(args.sgf_path):
        os.makedirs(args.sgf_path)

    # generate data
    if args.sgf_from is None:
        if args.generate_sgf_only:
            generate_sgf(player_RL, player_SL, args.n_training_pairs,
                         args.batch_size, features, args.verbose, args.sgf_path)
        else:
            generate_data(player_RL, player_SL, args.outfile, args.n_training_pairs, args.batch_size,
                          policy_SL.model.input_shape[-1], features, args.verbose, args.sgf_path)
    else:
       generate_data_from_sgf(args.outfile, args.batch_size, policy_SL.model.input_shape[-1],
                              features, args.verbose, args.sgf_from)


if __name__ == '__main__':
    handle_arguments()
