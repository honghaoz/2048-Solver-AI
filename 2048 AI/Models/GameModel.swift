// Copyright © 2019 ChouTi. All rights reserved.

import Foundation

protocol Game2048Delegate: AnyObject {
  func game2048DidReset(_ game2048: Game2048, removeActions: [RemoveAction])
  func game2048DidStartNewGame(_ game2048: Game2048)
  func game2048DidUpdate(_ game2048: Game2048, moveActions: [MoveAction], initActions: [InitAction], score: Int)
  func game2048DidEnd(_ game2048: Game2048)
}

class Game2048: NSObject {
  let dimension: Int

  /// Target score to win
  var targetScore: Int = 0

  /// Current score
  var score: Int = 0

  // Store pointers to Tiles, this will give a chance to modify tiles in place
  var gameBoard: SquareGameBoard<UnsafeMutablePointer<Tile>>

  /// A queue which will store upcomming commands, this queue if helpful for delaying too fast operation
  var commandQueue = [MoveCommand]()
  var commandQueueSize = 100

  /// Game delegate, normally this shoudl be the controller
  weak var delegate: Game2048Delegate?

  /**
   Init a new game2048

   - parameter d: dimensin of game
   - parameter t: target value, e.g. 2048. if pass in 0, means target is unlimited

   - returns: an initialized Game2048
   */
  init(dimension d: Int, target t: Int) {
    self.dimension = d
    self.targetScore = t

    // Initialize gameBoard
    self.gameBoard = SquareGameBoard(dimension: d, initialValue: { UnsafeMutablePointer<Tile>.allocate(capacity: 1) })
    super.init()
    // Allocate memory and initialize it
    allocateGameBoard()
  }

  deinit {
    // Be sure to deallocate memory
    deallocateGameBoard()
  }
}

// MARK: Game Logics

extension Game2048 {
  func reset() {
    score = 0
    commandQueue.removeAll(keepingCapacity: true)
    let removedCoordinates = emptyGameBoard()
    var removeActions = [RemoveAction]()
    for coordinate in removedCoordinates {
      let action = RemoveAction(actionType: .Remove, removeCoordinate: coordinate)
      removeActions.append(action)
    }

    delegate?.game2048DidReset(self, removeActions: removeActions)
  }

  func start() {
    precondition(!GameModelHelper.gameBoardFull(&gameBoard), "Game is not empty, before starting a new game, please reset a game")

    // TODO: Different dimension could insert different numbers of tiles
    let resultInitActions = GameModelHelper.performInsertCommand(&gameBoard, multipleTimes: 2)

    delegate?.game2048DidStartNewGame(self)
    delegate?.game2048DidUpdate(self, moveActions: [], initActions: resultInitActions, score: score)
  }

  func playWithCommand(_ command: MoveCommand) {
    if commandQueue.count > commandQueueSize {
      // Queue is wedged. This should actually never happen in practice.
      return
    }
    commandQueue.append(command)
    executeCommandQueue()
  }

  private func executeCommandQueue() {
    while !commandQueue.isEmpty {
      let command = commandQueue[0]
      commandQueue.remove(at: 0)
      performMoveCommand(command)
    }
  }

  private func performMoveCommand(_ moveCommand: MoveCommand) {
    let (resultMoveActions, increasedScores) = GameModelHelper.performMoveCommand(moveCommand, onGameBoard: &gameBoard)

    var resultInitActions = [InitAction]()
    if !resultMoveActions.isEmpty {
      resultInitActions.append(GameModelHelper.performInsertCommand(&gameBoard))
    }

    // Update
    score += increasedScores
    delegate?.game2048DidUpdate(self, moveActions: resultMoveActions, initActions: resultInitActions, score: score)

    // Check end state
    if GameModelHelper.isGameEnded(&gameBoard) {
      delegate?.game2048DidEnd(self)
    }
  }
}

// MARK: Fundamental Helpers

extension Game2048 {
  /**
   Allocate memory for game board and initialize it with .Empty
   */
  func allocateGameBoard() {
    GameModelHelper.allocInitGameBoard(&gameBoard)
  }

  func resetGameBoardWithIntBoard(_ intGameBoard: [[Int]], score: Int) {
    self.score = score
    GameModelHelper.resetGameBoard(&gameBoard, withGameBoard: intGameBoard)
  }

  /**
   Set all values in game board to .Empty
   PRE: gameboard memory is allocated
   */
  func emptyGameBoard() -> [(Int, Int)] {
    return GameModelHelper.emptyGameBoard(&gameBoard)
  }

  /**
   Destory value in game board and deallocate memory
   */
  func deallocateGameBoard() {
    GameModelHelper.deallocGameBoard(&gameBoard)
  }
}

// MARK: Expose to AI

extension Game2048 {
  /**
   Return a copy of gameBoard (a 2d matrix contains integers, 0 stands for .Empty)

   - returns: 2d array of Int
   */
  func currentGameBoard() -> [[Int]] {
    var result = [[Int]]()
    for i in 0..<dimension {
      var row = [Int]()
      for j in 0..<dimension {
        switch gameBoard[i, j].pointee {
        case .Empty:
          row.append(0)
        case let .Number(num):
          row.append(num)
        }
      }
      result.append(row)
    }
    return result
  }

  /**
   Get next state for a game board

   - parameter gameBoard: 2d array with Int type, representation for a game board
   - parameter command:   a valid command

   - returns: next game board and increased scores
   */
  func nextStateFromGameBoard(_ gameBoard: [[Int]], withCommand command: MoveCommand, shouldCheckGameEnd _: Bool = false, shouldInsertNewTile: Bool = false) -> ([[Int]], Int) {
    precondition(gameBoard.count == dimension, "dimension must be equal")
    // Init a temp game board
    var tempGameBoard: SquareGameBoard<UnsafeMutablePointer<Tile>> = SquareGameBoard(dimension: dimension, initialValue: { UnsafeMutablePointer<Tile>.allocate(capacity: 1) })

    // Alloc memory
    GameModelHelper.allocInitGameBoard(&tempGameBoard, withGameBoard: gameBoard)

//        printOutGameBoard(tempGameBoard)

    var increasedScore: Int = 0

    // Mutate tempGameBoard
    switch command.direction {
    case .up:
      for i in 0..<dimension {
        var tilePointers = tempGameBoard.getColumn(i, reversed: true)
        let (_, score) = GameModelHelper.processOneDimensionTiles(&tilePointers)
        increasedScore += score
      }
    case .down:
      for i in 0..<dimension {
        var tilePointers = tempGameBoard.getColumn(i, reversed: false)
        let (_, score) = GameModelHelper.processOneDimensionTiles(&tilePointers)
        increasedScore += score
      }
    case .left:
      for i in 0..<dimension {
        var tilePointers = tempGameBoard.getRow(i, reversed: true)
        let (_, score) = GameModelHelper.processOneDimensionTiles(&tilePointers)
        increasedScore += score
      }
    case .right:
      for i in 0..<dimension {
        var tilePointers = tempGameBoard.getRow(i, reversed: false)
        let (_, score) = GameModelHelper.processOneDimensionTiles(&tilePointers)
        increasedScore += score
      }
    }

    if shouldInsertNewTile {
      GameModelHelper.insertTileAtRandomLocation(&tempGameBoard)
    }

    // Create a new game board: [[Int]]
    var resultBoard = [[Int]]()
    for i in 0..<dimension {
      var row = [Int]()
      for j in 0..<dimension {
        switch tempGameBoard[i, j].pointee {
        case .Empty:
          row.append(0)
        case let .Number(tileNumber):
          row.append(tileNumber)
        }
      }
      resultBoard.append(row)
    }

    // Dealloc temp memory
    GameModelHelper.deallocGameBoard(&tempGameBoard)

//        logDebug("increasedScore: \(increasedScore)")
    return (resultBoard, increasedScore)
  }

  func isGameBoardEnded(_ gameBoard: [[Int]]) -> Bool {
    precondition(gameBoard.count == dimension, "dimension must be equal")

    // PreCheck
    for i in 0..<dimension {
      for j in 0..<dimension {
        if gameBoard[i][j] == 0 {
          return false
        }
      }
    }

    // Init a temp game board
    var tempGameBoard: SquareGameBoard<UnsafeMutablePointer<Tile>> = SquareGameBoard(dimension: dimension, initialValue: { UnsafeMutablePointer<Tile>.allocate(capacity: 1) })

    // Alloc memory
    GameModelHelper.allocInitGameBoard(&tempGameBoard, withGameBoard: gameBoard)

    let result = GameModelHelper.isGameEnded(&tempGameBoard)

    // Dealloc temp memory
    GameModelHelper.deallocGameBoard(&tempGameBoard)

    return result
  }
}

// MARK: Debug Methods

extension Game2048 {
  func printOutGameState() {
    GameModelHelper.printOutGameBoard(gameBoard)
  }
}
