
import Data.List
import Data.Maybe
import Data.Map (Map)
import qualified Data.Map as Map
import Debug.Trace

type CellID = String
type Cell = (CellID, Int, [CellID], [CellID]) -- cell ID, value, outputs, inputs

data Chain = Chain {
    cid :: CellID,
    chainCells :: [CellID],
    chainValue :: Int,
    chainLength :: Int,
    chainOutputs :: [CellID],
    chainInputs :: [CellID]
}

type Board = [Chain]

--type Action = (CellID, (Chain -> Chain))
type Action = Board -> Board

type ManeuverID = String
data Maneuver = Maneuver {
        mid :: ManeuverID,
        maneuverParent :: ManeuverID,
        maneuverAction :: Action,
        maneuverReactions :: [Action],
        maneuverBoardBefore :: Board,
        maneuverBoardAfter :: Board
    }

instance Show Maneuver where
    show maneuver = "m#" ++ mid maneuver ++ "{reactions:" ++ (show (length (maneuverReactions maneuver))) ++ "}"

data SolveState = SolveState {
    stateManeuvers :: Map ManeuverID Maneuver,
    statePossibleActions :: [Maneuver]
    }

instance Show SolveState where
    show state = "state {maneuvers:" ++ show (stateManeuvers state) ++ ", actions:" ++ show (statePossibleActions state) ++ "}"

-- solving:
-- generate a tree
--   Maneuver { id: 1, action: init board, board: (the board), reactions: [everything that happens auto] }
--   Maneuver { id: 1-1, parent: 1, action: (first thing you could do after 1), board: (the board after reactions), reactions: [everything that happens auto] }
--   Maneuver { id: 1-2, parent: 1, action: (second thing you could do after 1), board: (board), reactions: [re] }

solve :: SolveState -> SolveState
solve state = maybe state solve (solveStep state)

solvePrintingly :: SolveState -> SolveState
solvePrintingly state =
    trace ("solvePrintingly " ++ (show state)) (maybe state id (solveStep state))
    --maybe (return state) solvePrintingly (solveStep state)
    --return state
    
--solvePrintingly state = maybe (return state) (\state -> putStrLn ("printingly" ++ (show state))

-- given a Maneuver:
--   - select & remove one of the nextActions. (could be breadth-first, depth-first, or maybe a-star)
--   - for the nextAction:
--     - generate every reaction exhaustively
--     - save the updated board
--     - put this complete Maneuver in the "maneuvers" map
--     - generate all possible follow-up actions. Save these as incomplete maneuvers in "nextActions". (incomplete = id + action + parent, nothing more)
-- so:
--   - maneuvers :: Map (maneuverID, maneuver)
--   - nextActions :: [maneuver]
-- and after each run of this function, the following changes happen:
--   - one thing removed from nextActions
--   - it is completed and put in maneuvers
--   - all its followup actions go in nextActions
solveStep :: SolveState -> Maybe SolveState
solveStep state
  | length (statePossibleActions state) <= 0 = trace ("skipped a step") Nothing
  | otherwise =
    let (maneuver:newPossibles) = statePossibleActions state in
        -- assume maneuver is incomplete, and looks like this:
        -- data Maneuver = Maneuver {
        --      mid :: ManeuverID, -- this is finalized
        --      maneuverParent :: ManeuverID, -- this is finalized
        --      maneuverAction :: Action, -- this is finalized
        --      maneuverReactions :: [Action], -- this is EMPTY
        --      maneuverBoardBefore :: Board, -- this is finalized
        --      maneuverBoardAfter :: Board -- this is EMPTY (or whatever)
        --    }
        
        --maneuver2 = maneuver { maneuverBoardAfter = applyAction (maneuverAction maneuver) (maneuverBoardBefore maneuver) }

        let maneuver2 = generateReactions maneuver in
            let followups = act maneuver2 in
                let followupManeuvers = actionsToManeuvers (maneuverBoardAfter maneuver2) (maneuverParent maneuver2) followups in
                    trace ("return actions, followup: " ++ show followupManeuvers ++ ", newP: " ++ show newPossibles) Just SolveState {
                        stateManeuvers = Map.insert (mid maneuver2) maneuver2 (stateManeuvers state),
                        statePossibleActions = followupManeuvers ++ newPossibles
                    }
        
        

-- don't store Cells, store Chains. This is just like a Cell but it has a list of IDs (and also a ChainID which is the CellID of the first cell)

-- actions look like this: [ ["a1", (Cell -> Maneuver)], ["a2", (Maneuver -> Maneuver) ] ]
-- so do reactions

-- when we select nextAction we do:
generateReactions :: Maneuver -> Maneuver
generateReactions maneuver =
    -- x) create boardAfterAction (no)
    -- 2) create reactions and reduce across them (foldr)
    -- 3) save this final board
    -- output: all the reactions and the final board (wrapped in a new maneuver)
    
    -- while(true)
    --   make reaction
    --   make board

    let board = (maneuverBoardAfter maneuver) in
        maybe maneuver (\reaction -> maneuver { maneuverBoardAfter = applyAction board reaction, maneuverReactions = reaction : (maneuverReactions maneuver) } ) (react board)

act :: Maneuver -> [Action]
act maneuver = []

applyAction :: Board -> Action -> Board
applyAction board action = board

actionsToManeuvers :: Board -> ManeuverID -> [Action] -> [Maneuver]
actionsToManeuvers board parentID actions =
    zipWith (\action index -> actionToManeuver board parentID index action) actions (iterate (+ 1) 1)

actionToManeuver :: Board -> ManeuverID -> Int -> Action -> Maneuver
actionToManeuver board parentID index action = Maneuver {
        mid = parentID ++ "-" ++ (show index),
        maneuverParent = parentID,
        maneuverAction = action,
        maneuverReactions = [],
        maneuverBoardBefore = board,
        maneuverBoardAfter = board
    }

react :: Board -> Maybe Action
react board
  | length results > 0 = Just (head results)
  | otherwise = Nothing
  where results = catMaybes (map (reactSingleOutput board) board)

reactSingleOutput :: Board -> Chain -> Maybe Action
reactSingleOutput board chain =
    if ((length (chainOutputs chain)) == 1)
        then Just (linkChains (cid chain) (head (chainOutputs chain)))
        else Nothing

linkChains :: CellID -> CellID -> Board -> Board
linkChains chain1ID chain2ID board =
    newChain : remainder
        where newChain = chain1
              remainder = filter (\c -> (cid c) /= chain1ID && (cid c) /= chain2ID) board
              chain1 = getChain chain1ID board
              chain2 = getChain chain2ID board

getChain :: CellID -> Board -> Chain
getChain chainID board = fromJust $ find (\chain -> (cid chain) == chainID) board

{-
reactSingleOutput :: Board -> Chain -> Maybe Action
reactSingleOutput board (chainID, cellIDs, value, length, outputs, inputs)
  | length outputs == 1
    | length tInputs > 1
      where (getChain board (first outputs))
      -}

{-
puzzle1 = Map.fromList [
    ("a1", ("a1" 0 ["a3"] ["b1"])),
    ("a2", ("a2" 1 ["b1"] [])),
    ("a3", ("a3" 0 ["b2"] ["a1"])),
    ("b1", ("b1" 0 ["a1"] ["a2"])),
    ("b2", ("b2" 0 ["b3"] ["a3"])),
    ("b3", ("b3" 6 [] ["b2"]))
    ]
    -}

puzzle3 = [
    ("a1", 1, ["a2", "a3"]),
    ("a2", 0, ["b3"]),
    ("a3", 0, ["b2", "c1"]),
    ("b1", 0, ["c1"]),
    ("b2", 0, ["c2"]),
    ("b3", 0, ["b2", "b1"]),
    ("c1", 0, ["c2", "c3"]),
    ("c2", 0, ["b2", "a2"]),
    ("c3", 9, [])
    ]

puzzleToBoard :: [(CellID, Int, [CellID])] -> Board
puzzleToBoard protoCells = map reify protoCells
    where reify (cellID, value, outputs) = Chain {
        cid = cellID, chainCells = [cellID],
        chainValue = value, chainLength = 1,
        chainOutputs = outputs, chainInputs = (inputs cellID)
    }
          inputs cellID = map (\(cellID, _, _) -> cellID) (filter (\(_, _, outputs) -> elem cellID outputs) protoCells)

boardToSolveState :: Board -> SolveState
boardToSolveState board = SolveState {
    stateManeuvers = Map.empty,
    statePossibleActions = [
        Maneuver {
                mid = "",
                maneuverParent = "",
                maneuverAction = id,
                maneuverReactions = [],
                maneuverBoardBefore = puzzleToBoard puzzle3,
                maneuverBoardAfter = []
            }
        ]
}
    
main = do
    let solution = solvePrintingly $ solvePrintingly (boardToSolveState (puzzleToBoard puzzle3))
    putStrLn $ "signposts maneuvers: " ++ (show (length (stateManeuvers solution))) ++ ", actions: " ++ (show (length (statePossibleActions solution)))