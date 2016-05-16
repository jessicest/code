
module Solver
( Solver(Solver, openPlans, terminalSteps, guesses)
, Plan(Plan, planAction, planParent)
, Step(Step, InitStep, stepActions, stepPreBoard, stepPostBoard, stepParent, stepId)
, solve
) where

import Signpost
import ListUtil

data Plan = Plan {
    planAction :: Action,
    planParent :: Step
}

instance Show Plan where
    show plan = "{" ++ (stepId (planParent plan)) ++ "::" ++ show (planAction plan) ++ "}"

data Step = InitStep {
    stepId :: String,
    stepPostBoard :: Board
} | Step {
    stepId :: String,
    stepActions :: [Action],
    stepPreBoard :: Board,
    stepPostBoard :: Board,
    stepParent :: Step
}

instance Show Step where
    show step = "{" ++ stepId step ++ "}"

data Solver = Solver {
    openPlans :: [Plan],
    terminalSteps :: [Step],
    guesses :: [Action]
}

solve :: Solver -> Solver
solve solver
  | length (openPlans solver) <= 0 = solver
  | otherwise = solve $ Solver {
      openPlans = newPlans ++ plans,
      terminalSteps = terminals,
      guesses = (guesses solver) ++ newGuesses
      }
    where newGuesses = guess (stepPostBoard newStep)
          newPlans = map (makePlan newStep) newGuesses
          (plan, plans) = selectPlan (openPlans solver)
          newStep = resolvePlan $ trace ("resolving plan " ++ show plan) plan
          terminals
            | null newPlans = newStep : terminalSteps solver
            | otherwise = terminalSteps solver

resolvePlan :: Plan -> Step
resolvePlan plan = Step {
                        stepActions = actions,
                        stepPreBoard = preBoard,
                        stepPostBoard = postBoard,
                        stepParent = parent,
                        stepId = (stepId parent) ++ " -> " ++ (actionName $ planAction plan)
                    }
                    where (actions, postBoard) = resolveAction (planAction plan) preBoard
                          parent = planParent plan
                          preBoard = stepPostBoard parent

selectPlan :: [Plan] -> (Plan, [Plan])
selectPlan (plan:plans) = (plan, plans)

resolveAction :: Action -> Board -> ([Action], Board)
resolveAction action board = (action : finalActions, finalBoard)
    where newBoard = (actionTransformer action) (verifyBoard board)
          (finalActions, finalBoard) = case (react newBoard) of
            Just reaction -> resolveAction reaction newBoard
            Nothing -> ([], newBoard)

guess :: Board -> [Action]
guess _ = []

commentguess board = (\guesses -> trace ("generated guesses: " ++ show guesses) guesses) $ concat (map linkToEveryOutput board)
    where linkToEveryOutput chain = map (makeAction (cid chain)) (chainOutputs chain)
          makeAction :: CellID -> CellID -> Action
          makeAction source target = Action { actionName = source ++ "->" ++ target, actionTransformer = linkChainsInBoard source target, actionBoard = board }

makePlan :: Step -> Action -> Plan
makePlan parent action = Plan {
    planAction = action,
    planParent = parent
    }
    
react :: Board -> Maybe Action
react board
  | length results > 0 = trace ("----------------------------------------------\nreacted: " ++ (show (head results)) ++ "\n----------------------------------------------") $ Just (head results)
  | otherwise = Nothing
  --where results = catMaybes (map (reactSingleOutput board) board)
  where results = convergeMaybes [
         map (reactSingleOutput board) board,
         map (reactSingleInput board) board
         ]

reactSingleOutput :: Board -> Chain -> Maybe Action
reactSingleOutput board chain =
    if ((length (chainOutputs chain)) == 1)
        then Just $ Action { actionName = "single output " ++ cid chain ++ "=>" ++ (head (chainOutputs chain)), actionTransformer = (linkChainsInBoard (cid chain) (head (chainOutputs chain))), actionBoard = board }
        else Nothing

reactSingleInput :: Board -> Chain -> Maybe Action
reactSingleInput board chain =
    if ((length (chainInputs chain)) == 1)
        then Just $ Action { actionName = "single input " ++ (head (chainInputs chain)) ++ "=>" ++ (cid chain), actionTransformer = (linkChainsInBoard (head (chainInputs chain)) (cid chain)), actionBoard = board }
        else Nothing

