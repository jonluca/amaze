import json

import networkx as nx
import numpy as np
from termcolor import colored


def add_tuples(a, b):
    return tuple(p + q for p, q in zip(a, b))


def AGL_to_str(agl):
    return str(agl.index)


# this function is used to convert networkx to Cytoscape.js JSON format
# returns string of JSON
def convert2cytoscapeJSON(G):
    # load all nodes into nodes array
    final = {}
    final["nodes"] = []
    final["edges"] = []
    for node in G.nodes():
        nx = {}
        nx["data"] = {}
        nx["data"]["id"] = str(node)
        nx["data"]["label"] = str(node)
        final["nodes"].append(nx.copy())
    # load all edges to edges array
    for edge in G.edges():
        nx = {}
        nx["data"] = {}
        nx["data"]["id"] = str(edge[0]) + str(edge[1])
        nx["data"]["source"] = str(edge[0])
        nx["data"]["target"] = str(edge[1])
        final["edges"].append(nx)
    return json.dumps(final)


class AmazeGameLocation:

    def __init__(self, index):
        self.index = index
        self.dirs = {'U': None, 'D': None, 'L': None, 'R': None, }

    def __str__(self):
        return str(self.index)


class AmazeGame:

    def __init__(self, board_size):
        self.board_size = board_size
        self.board = np.zeros((board_size, board_size))
        self.nodes = np.empty((board_size, board_size), dtype=object)
        self.traversed = np.full((board_size, board_size), False)
        self.paths = nx.DiGraph()
        self.ball = (0, 0)
        self.last_loc = None

    def generate_graph(self):
        ball_cells = np.argwhere(self.board == 2)
        if len(ball_cells) > 1:
            raise ValueError("The board must contain at most one ball")
        ind = tuple(int(value) for value in ball_cells[0]) if len(ball_cells) else self.ball
        if not self.is_move_possible(ind):
            raise ValueError("The ball must start on an open cell")
        self.ball = ind
        self.nodes.fill(None)
        self.paths.clear()
        locs = [ind]
        next_loc = None
        while len(locs):
            next_loc = locs.pop()
            if not self.nodes[next_loc]:
                self.nodes[next_loc] = AmazeGameLocation(next_loc)
                self.paths.add_node(self.nodes[next_loc])

            moves = [("U", (-1, 0)), ("D", (1, 0)), ("L", (0, -1)), ("R", (0, 1))]
            for move in moves:
                next_move_loc = add_tuples(move[1], next_loc)
                if self.is_move_possible(next_move_loc):
                    next_attempt = add_tuples(move[1], next_move_loc)
                    weight = 1
                    while self.is_move_possible(next_attempt):
                        next_move_loc = next_attempt
                        next_attempt = add_tuples(move[1], next_move_loc)
                        weight += 1
                    if not self.nodes[next_move_loc]:
                        self.nodes[next_move_loc] = AmazeGameLocation(next_move_loc)
                        self.paths.add_node(self.nodes[next_move_loc])
                        locs.append(next_move_loc)
                    self.paths.add_edge(self.nodes[next_loc], self.nodes[next_move_loc], weight=weight)
                    self.nodes[next_loc].dirs[move[0]] = self.nodes[next_move_loc]
        self.last_loc = next_loc

    def print_board(self):
        printed = ''
        for i in self.board:
            for j in i:
                letter = 'X'
                color = 'white'
                if j == 1:
                    color = 'red'
                    letter = '.'
                elif j == 2:
                    color = 'blue'
                    letter = 'O'
                elif j == 3:
                    color = 'green'
                    letter = 'Y'
                printed += colored(letter, color)
            printed += '\n'
        print(printed)
        # fig_size = plt.rcParams["figure.figsize"]
        # fig_size[0] = 12
        # fig_size[1] = 9
        # plt.rcParams["figure.figsize"] = fig_size
        # nx.draw_networkx(self.paths, pos=nx.spring_layout(self.paths, k=0.7), with_labels=True)
        # plt.savefig('graph.png', dpi=300)

    def save_cyto(self):
        cyto = convert2cytoscapeJSON(self.paths)
        with open('cyto.json', 'w') as out:
            out.write(cyto)

    def is_move_possible(self, move):
        return all(0 <= v < self.board_size for v in move) and self.board[move] != 0

    def make_move(self, letter):
        if letter not in ('U', 'D', 'L', 'R'):
            raise ValueError("Direction must be U, D, L, or R")
        if letter == 'U':
            move = (-1, 0)
        elif letter == 'D':
            move = (1, 0)
        elif letter == 'L':
            move = (0, -1)
        elif letter == 'R':
            move = (0, 1)

        self.board[self.ball] = 3
        next_move_loc = add_tuples(self.ball, move)
        if self.is_move_possible(next_move_loc):
            self.ball = next_move_loc
            self.board[self.ball] = 3
            self.traversed[self.ball] = True
            next_attempt = add_tuples(move, next_move_loc)
            while self.is_move_possible(next_attempt):
                self.ball = next_attempt
                self.board[self.ball] = 3
                self.traversed[self.ball] = True
                next_attempt = add_tuples(move, next_attempt)
        else:
            print('error')
        self.board[self.ball] = 2

    def solve_dfs(self):
        nodes = self.paths.nodes()
        sol = nx.dijkstra_path(self.paths, self.nodes[self.ball], self.nodes[self.last_loc])
        nodes = [n for n in nodes if n not in sol]
        while len(nodes):
            sol += nx.dijkstra_path(self.paths, sol[-1], nodes[0])[1:]
            nodes = [n for n in nodes if n not in sol]
        return sol


def get_dfs_solution(amaze):
    solution = amaze.solve_dfs()
    move_num = 0
    moves = []
    for i in range(len(solution) - 1):
        for letter in ('U', 'D', 'L', 'R'):
            if solution[i].dirs[letter] == solution[i + 1]:
                print(f'Move number {move_num}, move {letter}')
                move_num += 1
                moves.append(letter)
                amaze.make_move(letter)
                amaze.print_board()
                break
    for move in moves:
        print(move)


def main():
    amaze = AmazeGame(13)
    ### 0 = wall, 1 = path, 2 = ball
    amaze.board = np.array([[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1],
                            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1], [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1],
                            [1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1], [1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1],
                            [1, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1], [1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
                            [1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1], [0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0],
                            [1, 1, 1, 1, 0, 0, 0, 1, 0, 1, 0, 1, 0], [1, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 1, 0],
                            [2, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 0]])
    amaze.generate_graph()
    amaze.print_board()

    get_dfs_solution(amaze)


if __name__ == "__main__":
    main()
