//
//  ViewController.swift
//  2048 Solver
//
//  Created by Honghao Zhang on 3/6/15.
//  Copyright (c) 2015 Honghao Zhang. All rights reserved.
//

import UIKit
//import AVFoundation

class ViewController: UIViewController {

    var scoreView: ScoreView!
    var bestScoreView: ScoreView!
    var targetView: ScoreView!
    
    var gameBoardView: GameBoardView!
    
    var gameModel: Game2048!
    var commandQueue = [MoveCommand]()
    var commandCalculationQueue = NSOperationQueue()
    
    typealias ActionTuple = (moveActions: [MoveAction], initActions: [InitAction], score: Int)
    var actionQueue = [ActionTuple]()
    
    var kUserCommandQueueSize: Int = 3
    var kAiCommandQueueSize: Int = 20
    
    var isGameEnd: Bool = false
    
    var isAnimating: Bool = false
    var isAiRunning: Bool = false
    
    var views = [String: UIView]()
    var metrics = [String: CGFloat]()
    
    var ai: AI!
    var aiRandom: AIRandom!
    var aiGreedy: AIGreedy!
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        logLevel = .Info
        logLevel = .Debug
        
        setupGameModel()
        setupViews()
        setupSwipeGestures()
        setupAI()
        otherSetups()

        gameModel.start()
    }
    
    func setupGameModel() {
        gameModel = Game2048(dimension: 4, target: 0)
        gameModel.delegate = self
        gameModel.commandQueueSize = kAiCommandQueueSize
    }
    
    func setupViews() {
        view.backgroundColor = SharedColors.BackgroundColor

        metrics["padding"] = 5.0
        
        // GameBoardView
        gameBoardView = GameBoardView()
        gameBoardView.backgroundColor = view.backgroundColor
        gameBoardView.gameModel = gameModel
        
        gameBoardView.setTranslatesAutoresizingMaskIntoConstraints(false)
        views["gameBoardView"] = gameBoardView
        view.addSubview(gameBoardView)
        
        // GameBoard Size
        let gameBoardWidth = screenWidth * 0.9
        gameBoardView.addConstraint(NSLayoutConstraint(item: gameBoardView, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 0.0, constant: gameBoardWidth))
        gameBoardView.addConstraint(NSLayoutConstraint(item: gameBoardView, attribute: .Width, relatedBy: .Equal, toItem: gameBoardView, attribute: .Height, multiplier: 1.0, constant: 0.0))
        
        // GameBoard center horizontally
        view.addConstraint(NSLayoutConstraint(item: view, attribute: .CenterX, relatedBy: .Equal, toItem: gameBoardView, attribute: .CenterX, multiplier: 1.0, constant: 0.0))
        let cCenterY = NSLayoutConstraint(item: view, attribute: .CenterY, relatedBy: .Equal, toItem: gameBoardView, attribute: .CenterY, multiplier: 1.0, constant: 0.0)
        // 3.5 inch Screen has a smaller height, this will be broken
        cCenterY.priority = 750
        view.addConstraint(cCenterY)
        
        // ScoreView
        scoreView = ScoreView()
        scoreView.setTranslatesAutoresizingMaskIntoConstraints(false)
        views["scoreView"] = scoreView
        view.addSubview(scoreView)
        
        scoreView.titleLabel.text = "SCORE"
        scoreView.numberLabelMaxFontSize = is3_5InchScreen ? 20 : 28
        scoreView.numberLabel.textAlignment = .Right
        scoreView.number = 0
        
        // BestScoreView
        bestScoreView = ScoreView()
        bestScoreView.setTranslatesAutoresizingMaskIntoConstraints(false)
        views["bestScoreView"] = bestScoreView
        view.addSubview(bestScoreView)
        
        bestScoreView.titleLabel.text = "BEST"
        bestScoreView.numberLabelMaxFontSize = is3_5InchScreen ? 20 : 28
        bestScoreView.numberLabel.textAlignment = .Right
        bestScoreView.number = 999999 // TODO: Record best score
        
        // TargetView
        targetView = ScoreView()
        targetView.setTranslatesAutoresizingMaskIntoConstraints(false)
        views["targetView"] = targetView
        view.addSubview(targetView)
        
        targetView.titleLabel.text = "TARGET"
        targetView.numberLabelMaxFontSize = 38
        targetView.number = 2048
//        targetView.numberLabel.text = "∞"
        
        metrics["targetViewHeight"] = gameBoardWidth / 3.0
        // TargetView is square
        targetView.addConstraint(NSLayoutConstraint(item: targetView, attribute: .Height, relatedBy: .Equal, toItem: targetView, attribute: .Width, multiplier: 1.0, constant: 0.0))
        
        // H
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:[scoreView]-padding-[targetView]", options: NSLayoutFormatOptions.AlignAllTop, metrics: metrics, views: views))
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:[bestScoreView]-padding-[targetView]", options: NSLayoutFormatOptions.AlignAllBottom, metrics: metrics, views: views))
        
        // V
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:[scoreView]-padding-[bestScoreView(==scoreView)]-padding-[gameBoardView]", options: NSLayoutFormatOptions.AlignAllLeading, metrics: metrics, views: views))
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:[targetView(targetViewHeight)]-padding-[gameBoardView]", options: NSLayoutFormatOptions.AlignAllTrailing, metrics: metrics, views: views))
        
        // Target view top spacing >= 22
        view.addConstraint(NSLayoutConstraint(item: targetView, attribute: NSLayoutAttribute.Top, relatedBy: NSLayoutRelation.GreaterThanOrEqual, toItem: view, attribute: NSLayoutAttribute.Top, multiplier: 1.0, constant: 22))
        
        // Must call this before start game
        view.layoutIfNeeded()
    }
    
    func setupSwipeGestures() {
        let upSwipe = UISwipeGestureRecognizer(target: self, action: Selector("up:"))
        upSwipe.numberOfTouchesRequired = 1
        upSwipe.direction = UISwipeGestureRecognizerDirection.Up
        gameBoardView.addGestureRecognizer(upSwipe)
        
        let downSwipe = UISwipeGestureRecognizer(target: self, action: Selector("down:"))
        downSwipe.numberOfTouchesRequired = 1
        downSwipe.direction = UISwipeGestureRecognizerDirection.Down
        gameBoardView.addGestureRecognizer(downSwipe)
        
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: Selector("left:"))
        leftSwipe.numberOfTouchesRequired = 1
        leftSwipe.direction = UISwipeGestureRecognizerDirection.Left
        gameBoardView.addGestureRecognizer(leftSwipe)
        
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: Selector("right:"))
        rightSwipe.numberOfTouchesRequired = 1
        rightSwipe.direction = UISwipeGestureRecognizerDirection.Right
        gameBoardView.addGestureRecognizer(rightSwipe)
    }
    
    func setupAI() {
        ai = AI.CreateInstance()
        aiRandom = AIRandom(gameModel: gameModel)
        aiGreedy = AIGreedy(gameModel: gameModel)
    }
    
    func otherSetups() {
        sharedAnimationDuration = 0.1
        // Make sure operation queue is serial
        commandCalculationQueue.maxConcurrentOperationCount = 1
    }
}

// MARK: Swipe Gestures
extension ViewController {
    @objc(up:)
    func upCommand(r: UIGestureRecognizer!) {
        precondition(gameModel != nil, "")
        queueCommand(MoveCommand(direction: MoveDirection.Up))
    }
    
    @objc(down:)
    func downCommand(r: UIGestureRecognizer!) {
        precondition(gameModel != nil, "")
        queueCommand(MoveCommand(direction: MoveDirection.Down))
    }
    
    @objc(left:)
    func leftCommand(r: UIGestureRecognizer!) {
        precondition(gameModel != nil, "")
        queueCommand(MoveCommand(direction: MoveDirection.Left))
    }
    
    @objc(right:)
    func rightCommand(r: UIGestureRecognizer!) {
        precondition(gameModel != nil, "")
        queueCommand(MoveCommand(direction: MoveDirection.Right))
    }
}

extension ViewController {
    func runAI() {
        // If dispatched commands + commandToBeDispatched count is greater than size, don't dispacth, otherwise, queue will be overflow
        if (
            (commandCalculationQueue.operationCount + commandQueue.count) >= kAiCommandQueueSize)
            ||
            ((commandCalculationQueue.operationCount + actionQueue.count) >= kAiCommandQueueSize)
        {
            logDebug("Full, Stop AI")
            return
        }

        logDebug("Add new command calculation")
        commandCalculationQueue.addOperationWithBlock { () -> Void in
            if let nextCommand = self.ai.nextMoveUsingAlphaBetaPruning(self.gameModel.currentGameBoard()) {
//            if let nextCommand = self.aiRandom.nextCommand() {
//            if let nextCommand = self.ai.nextMoveUsingMonoHeuristic(self.gameModel.currentGameBoard()) {
                NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                    self.queueCommand(nextCommand)
                })
            }
        }
    }
}

// MARK: Command Queue
extension ViewController {
    func queueCommand(command: MoveCommand) {
//        logDebug("CommandQueue size: \(commandQueue.count), ActionQueue size: \(actionQueue.count)")
        if queuesAreFull() {
            logError("Queue are Full")
            assertionFailure("Queue are Full: should never happen")
        }
        logDebug("Enqueue")
        commandQueue.append(command)
        executeCommandQueue()
    }
    
    func executeCommandQueue() {
        if commandQueue.count > 0 {
            logDebug("Dequeue and Execute")
            let command = commandQueue[0]
            GameModelHelper.printOutCommand(command, level: .Info)
            commandQueue.removeAtIndex(0)
            gameModel.playWithCommand(command)
        } else {
            logDebug("Queue is empty")
        }
    }
    
    func queueAction(action: ActionTuple) {
        if actionQueueIsFull() {
            logError("Queue is Full")
            assertionFailure("Queue is Full: should never happen")
        }
        logDebug("Enqueue")
        actionQueue.append(action)
        executeActionQueue()
    }
    
    func executeActionQueue() {
        if isAnimating {
            logDebug("is Animating")
            return
        }
        if actionQueue.count > 0 {
            logDebug("Dequeue and Execute")
            let actionTuple = actionQueue[0]
            actionQueue.removeAtIndex(0)
            
            // If before dequeuing, actionQueue is full, command queue is empty, reactivate AI
            if isAiRunning && (actionQueue.count == kAiCommandQueueSize - 1) && (commandCalculationQueue.operationCount + commandQueue.count == 0) {
                logDebug("Action Queue is available, resume AI")
                runAI()
            }
            
            // Update UIs
            self.isAnimating = true
            scoreView.number = actionTuple.score
            gameBoardView.updateWithMoveActions(actionTuple.moveActions, initActions: actionTuple.initActions, completion: {
                self.isAnimating = false
                self.executeActionQueue()
            })
        } else {
            logDebug("Queue is empty")
        }
    }
    
    // MARK: Queue Helpers
    func queuesAreFull() -> Bool {
        let size = isAiRunning ? kAiCommandQueueSize : kUserCommandQueueSize
        return (actionQueue.count >= size || commandQueue.count >= size)
    }
    
    func commandQueueIsFull() -> Bool {
        let size = isAiRunning ? kAiCommandQueueSize : kUserCommandQueueSize
        return commandQueue.count >= size
    }
    
    func actionQueueIsFull() -> Bool {
        let size = isAiRunning ? kAiCommandQueueSize : kUserCommandQueueSize
        return actionQueue.count >= size
    }
}

// MARK: Game 2048 Delegate
extension ViewController: Game2048Delegate {
    func game2048DidReset(game2048: Game2048) {
        logDebug("Reseted")
    }
    
    func game2048DidStartNewGame(game2048: Game2048) {
        logDebug("Started")
//        game2048.printOutGameState()
        isGameEnd = false
        isAiRunning = true
    }
    
    func game2048DidUpdate(game2048: Game2048, moveActions: [MoveAction], initActions: [InitAction], score: Int) {
        logDebug("Updated")
//        game2048.printOutGameState()
        
        if moveActions.count > 0 || initActions.count > 0 {
            queueAction((moveActions, initActions, score))
        }
        runAI()
    }
    
    func game2048DidEnd(game2048: Game2048) {
        game2048.printOutGameState()
        logDebug("Ended")
        isGameEnd = true
    }
}

// MARK: Others
extension ViewController {
//    func playSoundEffect() {
//        // Play sound effect
//        let path = NSBundle.mainBundle().pathForResource("move", ofType: "wav")
//        if let existedPath = path {
//            let pathURL = NSURL.fileURLWithPath(existedPath)
//            var audioEffect: SystemSoundID = 0
//            AudioServicesCreateSystemSoundID(pathURL, &audioEffect)
//            // Play
//            AudioServicesPlaySystemSound(audioEffect)
//            
//            // Using GCD, we can use a block to dispose of the audio effect without using a NSTimer or something else to figure out when it'll be finished playing.
//            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
//                Int64(2 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), { () -> Void in
//                    AudioServicesDisposeSystemSoundID(audioEffect)
//            })
//        }
//    }
}
