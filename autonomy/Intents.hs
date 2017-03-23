
module Intents
( Goal(..)
, Intent(..)
, Task(..)
, goal_name
, prepare_intents
, step_intents
, task_name
) where

import qualified Data.Map as Map
import Data.Map(Map(..))
import Debug.Trace

-- if i have no Intents then i need to generate one
-- if i have at least one intent, then look at the head:
---- does the Goal pass? if so, pop this intent
---- is there Nothing for the task_options? in that case, the Goal needs to generate a bunch of them
---- is there [] for the task_options? if so, CLEAR the whole intent stack (we've reached a failure state and we're at risk of endless looping now)
---- is there (x:[]) for the task_options? perfect; this stack is ready to execute
---- otherwise there are too many task_options; we need to filter some out
data Intent command state = Intent (Goal command state) (Maybe [Task command state]) deriving Show
data Goal command state = Goal String [state -> [Task command state]] [state -> Bool] -- name, task_generators, win conditions (need all for success)
data Task command state = Task String [Goal command state] [command] -- name, prerequisites, actions

instance Show (Task command state) where
    show (Task name _ _) = "Task " ++ name

instance Show (Goal command state) where
    show (Goal name _ _) = "Goal " ++ name

type ActorID = Int

step_intents :: [Intent command state] -> state -> ([Intent command state], [command])
step_intents intents state
    = case prepare_intents intents state of
          (True, new_intents) -> step_intents new_intents state
          (False, (new_intent : new_intents)) -> (new_intents, execute_intent new_intent)
          otherwise -> trace "this line is a hack that will be removed later -- intents was empty" $ ([], [])
          

-- many assumptions are made here. Be prepared before calling this!
execute_intent :: Intent command state -> [command]
execute_intent (Intent _ (Just (task : _))) = actions
    where Task _ _ actions = task

-- if it returns True, then we'll need to run it again (because something changed)
prepare_intents :: [Intent command state] -> state -> (Bool, [Intent command state])
prepare_intents [] _ = trace "time to generate a fresh new intent" $ (False, []) -- FIXME: this should be True but i've set it to False for convenience
prepare_intents (intent : intents) state = let Intent goal tasks = intent in
        if goal_succeeds goal state
            then trace ("prepare_intents 1 -- popping successful intent because goal " ++ show goal ++ " succeeds") $ (True, intents)
            else case tasks of
                   Nothing -> let new_tasks = goal_generate_tasks goal state in trace ("prepare_intents 2 -- generating " ++ show (length new_tasks) ++ " task options") $ (True, (Intent goal (Just new_tasks)) : intents)
                   Just [] -> trace "prepare_intents 3 -- dead end! clearing the whole damn stack" $ (True, [])
                   Just (task : []) -> prepare_task task
                   Just many_tasks -> trace "prepare_intents 5 -- winnowing task options" $ (True, (Intent goal (Just [select_task many_tasks])) : intents)
                   where prepare_task task = let subgoals = filter (\goal -> not (goal_succeeds goal state)) (task_prerequisites task) in
                                                 if null subgoals
                                                 then trace "prepare_intents 4a -- all good, ready to execute" $ (False, intent : intents)
                                                 else trace "prepare_intents 4b -- pushing a subgoal on the stack" $ (True, Intent (head subgoals) Nothing : intent : intents)

goal_succeeds :: Goal command state -> state -> Bool
goal_succeeds (Goal _ _ win_conditions) state = all (\condition -> condition state) win_conditions

goal_generate_tasks :: Goal command state -> state -> [Task command state]
goal_generate_tasks (Goal _ task_generators _) state = concat $ map (\generate_tasks -> generate_tasks state) task_generators

goal_name :: Goal command state -> String
goal_name (Goal name _ _) = name

task_name :: Task command state -> String
task_name (Task name _ _) = name

task_prerequisites :: Task command state -> [Goal command state]
task_prerequisites (Task _ prerequisites _) = prerequisites

select_task :: [Task command state] -> Task command state
select_task [] = error "can't select_task, empty list"
select_task tasks = head tasks
