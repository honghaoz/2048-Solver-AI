// Copyright © 2019 ChouTi. All rights reserved.

import QuartzCore
import UIKit

class GameBoardView: UIView {
  /// GameModel dimension
  var dimension: Int { return gameModel.dimension }

  /// padding: paddings around the board view
  var padding: CGFloat = 8.0 { didSet { updateTileWidth() } }
  /// paddings betwwen tiles
  var tilePadding: CGFloat = 3.0 { didSet { updateTileWidth() } }

  // TileWidth is updated automatically
  var tileWidth: CGFloat = 0.0

  /// Background tiles provide a grid like background layout
  var backgroundTiles = [[TileViewType]]()

  // Reason to use (TileViewType?, TileViewType?):
  // For animation convenience. When merging two tiles are followed by a condense action, both two tiles' frame need to be updated. Thus, the tuple.1 will store the tile underneath and provide the tile view
  var forgroundTiles = [[(TileViewType?, TileViewType?)]]()

  /// GameModel for GameBoardView
  var gameModel: Game2048! {
    didSet {
      if superview != nil {
        updateTileWidth()
        setupBackgroundTileViews()
        setupForgroundTileViews()
        updateBackgroundTileViews()
        updateForgroundTileViews()
      }
    }
  }

  // MARK: - Init Methods

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    setupViews()
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupViews()
  }

  override var bounds: CGRect {
    didSet {
      // If views are not set up, set up first then update
      if backgroundTiles.isEmpty {
        setupBackgroundTileViews()
        setupForgroundTileViews()
      }
      // If bounds changed, update tile views
      updateTileWidth()
      updateBackgroundTileViews()
      updateForgroundTileViews()
    }
  }

  private func setupViews() {
    layer.borderColor = UIColor.black.cgColor
    layer.borderWidth = 5.0
  }

  private func setupBackgroundTileViews() {
    precondition(gameModel != nil, "GameModel must not be nil")
    // Remove old ones
    backgroundTiles.forEach { $0.forEach { $0.removeFromSuperview() } }
    backgroundTiles.removeAll(keepingCapacity: false)
    // Layout tiles
    for i in 0..<dimension {
      var tiles = [TileViewType]()
      for j in 0..<dimension {
        let tile = TileView(frame: tileFrameForCoordinate((i, j)))
        tile.number = 0
        addSubview(tile)
        tiles.append(tile)
      }
      backgroundTiles.append(tiles)
    }
  }

  private func setupForgroundTileViews() {
    precondition(gameModel != nil, "GameModel must not be nil")
    forgroundTiles.forEach { $0.forEach { $0.0?.removeFromSuperview() } }
    forgroundTiles.forEach { $0.forEach { $0.1?.removeFromSuperview() } }
    forgroundTiles.removeAll(keepingCapacity: false)

    for _ in 0..<dimension {
      var tiles = [(TileViewType?, TileViewType?)]()
      for _ in 0..<dimension {
        tiles.append((nil, nil))
      }
      forgroundTiles.append(tiles)
    }
  }

  private func updateBackgroundTileViews() {
    precondition(gameModel != nil, "GameModel must not be nil")
    // Update background tiles' frame
    for i in 0..<dimension {
      for j in 0..<dimension {
        log.debug("i: \(i), j: \(j)")
        backgroundTiles[i][j].frame = tileFrameForCoordinate((i, j))
      }
    }
  }

  private func updateForgroundTileViews() {
    precondition(gameModel != nil, "GameModel must not be nil")
    for i in 0..<dimension {
      for j in 0..<dimension {
        if let tile = forgroundTiles[i][j].0 {
          tile.frame = tileFrameForCoordinate((i, j))
        }
      }
    }
  }

  func cleanForgroundTileViews() {
    for i in 0..<dimension {
      for j in 0..<dimension {
        forgroundTiles[i][j].0?.removeFromSuperview()
        forgroundTiles[i][j].1?.removeFromSuperview()
        forgroundTiles[i][j] = (nil, nil)
      }
    }
  }

  /// Directly mutate the game board.
  func setGameBoardWithBoard(_ board: [[Int]]) {
    precondition(board.count == dimension, "dimension must be equal.")
    cleanForgroundTileViews()

    for i in 0..<dimension {
      for j in 0..<dimension {
        if board[i][j] > 0 {
          let tile = TileView(frame: tileFrameForCoordinate((i, j)))
          tile.number = board[i][j]
          tile.numberLabel.font = tile.numberLabel.font.withSize(CGFloat(SharedFontSize.tileFontSizeForDimension(dimension)))
          addSubview(tile)
          forgroundTiles[i][j] = (tile, nil)
        }
      }
    }
  }
}

// MARK: Update View Actions

extension GameBoardView {
  func removeWithRemoveActions(_ removeActions: [RemoveAction], completion: (() -> Void)? = nil) {
//        logDebug("removeWithRemoveActions: ")
//        GameModelHelper.printOutGameBoard(self.currentDisplayingGameBoard())
    let count = removeActions.count
    for (index, action) in removeActions.enumerated() {
      let i = action.removeCoordinate.0
      let j = action.removeCoordinate.1

      log.debug("Removed: (\(i), \(j))")
      let tile = forgroundTiles[i][j].0!
      let underneathTile = forgroundTiles[i][j].1
      forgroundTiles[i][j] = (nil, nil)
      // Animation
      UIView.animate(withDuration: sharedAnimationDuration * 2,
                     animations: { () -> Void in
                       tile.alpha = 0.0
                       underneathTile?.alpha = 0.0
                     }, completion: { (_) -> Void in
                       tile.removeFromSuperview()
                       underneathTile?.removeFromSuperview()

                       // If this is the very last actions, call completion block
                       if index == count - 1 {
//                        logDebug("after removeWithRemoveActions: ")
//                        GameModelHelper.printOutGameBoard(self.currentDisplayingGameBoard())
                         completion?()
                       }
      })
    }
  }

  /**
   When game model is updated, view controller should call this method and passed in corresponding MoveActions and InitActions
   Note: this method will update MoveActions first and then InitActions

   - parameter moveActions: a list of actions which specify how tiles are merged or moved
   - parameter initActions: a list of actions which specify how new tiles are inserted
   */
  func updateWithMoveActions(_ moveActions: [MoveAction], initActions: [InitAction], completion: (() -> Void)? = nil) {
    updateWithMoveActions(moveActions, completion: {
      self.updateWithInitActions(initActions, completion: {
        completion?()
      })
    })
  }

  /**
   Insert new tile views using InitActions

   - parameter initActions: a list of actions which specify how new tiles are inserted
   */
  private func updateWithInitActions(_ initActions: [InitAction], completion: (() -> Void)? = nil) {
    log.debug("updateWithInitActions: ")
    GameModelHelper.printOutGameBoard(currentDisplayingGameBoard())
    let count = initActions.count
    if count == 0 {
      completion?()
      return
    }

    for (index, action) in initActions.enumerated() {
      let initCoordinate = action.initCoordinate
      let number = action.initNumber

      log.debug("Init: \(initCoordinate), \(number)")
      let tile = TileView(frame: tileFrameForCoordinate(initCoordinate))
      tile.number = number
      tile.numberLabel.font = tile.numberLabel.font.withSize(CGFloat(SharedFontSize.tileFontSizeForDimension(dimension)))

      // Store new tile views
      forgroundTiles[initCoordinate.0][initCoordinate.1].0 = tile
      addSubview(tile)

      // Blink pattern: 0 -> 1
      tile.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
      tile.alpha = 0.0
      UIView.animate(withDuration: sharedAnimationDuration * 2,
                     animations: { () -> Void in
                       tile.alpha = 1.0
                      tile.transform = .identity
                     },
                     completion: { (_) -> Void in
                       // If this is the very last actions, call completion block
                       if index == count - 1 {
                         completion?()
                       }
      })
    }
  }

  /**
   Move or merge tile views using MoveActions

   - parameter moveActions: a list of actions which specify how tiles are merged or moved
   - parameter completion:  an optional completion clousure, which will be called once all move actions are done
   */
  private func updateWithMoveActions(_ moveActions: [MoveAction], completion: (() -> Void)? = nil) {
    log.debug("updateWithMoveActions: ")
    GameModelHelper.printOutGameBoard(currentDisplayingGameBoard())

    let count = moveActions.count
    // If there's no MoveActions, execute completion closure
    if count == 0 {
      completion?()
      return
    }

    for (index, action) in moveActions.enumerated() {
      if action.fromCoordinates.count == 1 {
        // Move Action
        let from = action.fromCoordinates[0]
        let to = action.toCoordinate

        log.debug("Move: from: \(from) -> to: \(to)")

        let fromView = forgroundTiles[from.0][from.1].0!
        // There may exist an underneath tile
        let fromUnderneath = forgroundTiles[from.0][from.1].1

        // Set from tile to to tile and clean from tile
        forgroundTiles[to.0][to.1] = forgroundTiles[from.0][from.1]
        forgroundTiles[from.0][from.1] = (nil, nil)

        // Animation
        UIView.animate(withDuration: sharedAnimationDuration,
                       animations: { () -> Void in
                         fromView.frame = self.tileFrameForCoordinate(to)
                         fromUnderneath?.frame = fromView.frame
                       }, completion: { (_) -> Void in
                         // If this is the very last actions, call completion block
                         if index == count - 1 {
                           completion?()
                         }
        })
      } else {
        // Merge Action
        let from1 = action.fromCoordinates[0]
        let from2 = action.fromCoordinates[1]
        let to = action.toCoordinate

        log.debug("Move: from1: \(from1) + from2: \(from2) -> to: \(to)")

        // Make sure the inserting tile are under the inserted tile
        insertSubview(forgroundTiles[from1.0][from1.1].0!, belowSubview: forgroundTiles[from2.0][from2.1].0!)

        let fromTileView = forgroundTiles[from1.0][from1.1].0!
        let toTileView = forgroundTiles[to.0][to.1].0!

        forgroundTiles[from1.0][from1.1] = (nil, nil)

        // Put fromTileView underneath toTileView
        forgroundTiles[to.0][to.1] = (toTileView, fromTileView)

        UIView.animate(withDuration: sharedAnimationDuration,
                       animations: { () -> Void in
                         fromTileView.frame = self.tileFrameForCoordinate(to)
                       }, completion: { (_) -> Void in
                         fromTileView.removeFromSuperview()

                         // Double tile number and animate this tile
                         toTileView.number *= 2
                         toTileView.flashTile(completion: nil)

                         // If this is the very last actions, call completion block
                         if index == count - 1 {
                           DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + sharedAnimationDuration) {
                             completion?()
                           }
                         }
        })
      }
    }
  }
}

// MARK: Property helpers

extension GameBoardView {
  /**
   Update tileWidth when related properties are modified
   */
  func updateTileWidth() {
    tileWidth = (bounds.width - padding * 2 - tilePadding * (CGFloat(dimension) - 1)) / CGFloat(dimension)
  }
}

// MARK: Generic helpers

extension GameBoardView {
  /**
   Return the tile frame for a tile coordinate

   - parameter coordinate: tile coordinate, within range [0 ..< dimension, 0 ..< dimension]

   - returns: CGRect frame
   */
  func tileFrameForCoordinate(_ coordinate: (Int, Int)) -> CGRect {
    let y = padding + (tilePadding + tileWidth) * CGFloat(coordinate.0)
    let x = padding + (tilePadding + tileWidth) * CGFloat(coordinate.1)
    return CGRect(x: x, y: y, width: tileWidth, height: tileWidth)
  }

  func currentDisplayingGameBoard() -> [[Int]] {
    var result = [[Int]]()
    for i in 0..<dimension {
      var row = [Int]()
      for j in 0..<dimension {
        if let tile = forgroundTiles[i][j].0 {
          row.append(tile.number)
        } else {
          row.append(0)
        }
      }
      result.append(row)
    }

    return result
  }

  func currentMaxTileNumber() -> Int {
    var maxNumber = 0
    for i in 0..<dimension {
      for j in 0..<dimension {
        if let tile = forgroundTiles[i][j].0 {
          if tile.number > maxNumber {
            maxNumber = tile.number
          }
        }
      }
    }
    return maxNumber
  }
}
