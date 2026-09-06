# AmazeSolver

The repository now also includes **[Prism Roll for iOS](ios/README.md)**: a native 3D maze-painting game with unlimited, timed, and limited-move modes, daily challenges and streaks, collectible coins, 12 ball skins, four world themes, rewarded ads, and Game Center/StoreKit integration. Open `ios/PrismRoll.xcodeproj` to play in the simulator. The original solver and its notes remain below.

There is a pretty fun game called "Amaze!!!", [iOS link](https://itunes.apple.com/us/app/amaze/id1452526406?mt=8), in which the premise is to cover a full game board with paint. 

I have been playing it somewhat obsessively while traveling for the past few months (as seen by the fact that I'm on level 14073 - don't mind that, though, as the levels actually reset and wrap around to the beginning after a hundred or so, which was a disappoinment).

![screenshot](screenshot.jpg)

I wanted to see if I could come up with an algorithm and representation of the game in Python.


## Rules

You start as a ball placed on the grid. You can swipe in 4 directions - up, down, left and right. 

You travel as far on the grid as possible in that direction. Below you can see the progression of 4 turns. 

Initial board, a move right, a move up, and a move right.

![initial game](screen1.png)

The goal is to completely cover the board in paint.

The game itself is trivial (and in fact I wish it was harder, perhaps a limitation on the number of moves, or the amount of paint you can lay down, or a timer). So trivial, in fact, that I recreated it in javascript to play around with it. I adapted some of the code from [here](http://jsfiddle.net/n8j1s/4y22135r/) and made it a little more functional and changed it to Amaze!!!.  


## Goal

I wanted to see how easy it would be to build an AI that would A) solve the puzzle and B) see if I could find a way to actually find the *optimal* solution. The latter seems significantly more difficult than the former.

Note: After giving this some more thought I realized it's just a modification of the traveling salesman problem... What a bummer, to find out the problem you're trying to find an optimal solution to is NP hard. 

We can model our moves as a directed graph. You can't actually stop at every position on the board. You can make each valid ending point a node, and the outgoing four cardinal directions can be the edges to other valid ending nodes.

It's still not clear to me if you *have* to visit every node, but you do have to visit (traverse over) every empty block. We might be able to abstract over this - since we know every level in the game is solvable, simply visiting all valid locations encompasses every valid path.

If a nodes final location is on the path of two other nodes, you don't need to visit that node, but you might have to visit that node to clear the blocks on that nodes path?

The graph for the first example is below. The node names are the indices of the board on a 2D array. The board is 13x13, and the starting position is (12,0)

![graph](graph.png)
