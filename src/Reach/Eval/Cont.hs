module Reach.Eval.Cont where

import Reach.Eval.Expr
import Reach.Eval.Monad
import Reach.Eval.Gen
import Reach.Eval.Env
import Reach.Lens
import Reach.Printer
import Debug.Trace

runReach :: Monad m => ReachT m a -> Env -> m (a , Env)
runReach m s = do
  r <- runExceptT (runStateT m s)
  case r of
    Left err -> fail . show $ err
    Right a -> return a

type Reduce m = Atom -> [Expr] -> ReachT m Expr

--evalLazy :: MonadChoice m => Expr -> [Conts] -> ReachT m Expr
--evalLazy e conts = do
--   c <- fix reduceTrace e conts
--   case c of 
--     Cont e [] -> return e
--     Cont (FVar x) (Branch as : cs) -> do
--       (cid,vs) <- choose x (map (\(Alt c vs e) -> (c,length vs)) as)
--       xs <- newFVars vs
--       free . at x ?= (cid, xs)
--       evalLazy (Con cid (map FVar xs)) (Branch as : cs)

choose :: MonadChoice m => FId -> [(CId, Int)] -> ReachT m (CId, Int)
choose _ = foldr ((<|>) . return) memp 

           
--reduceTrace :: Monad m => Reduce m -> Reduce m
--reduceTrace r e cs = do
--  s <- get
--  trace (printDoc (printState (Expr e cs) s)) $ reduce r e cs

reduceExpr :: Monad m => (Expr -> ReachT m (Atom, [Conts])) -> Expr -> ReachT m (Atom, [Conts])
reduceExpr r (Let x e e') = do
  e'' <- bind x e e'  
  r e''
reduceExpr r (Expr a cs) = reduce r a cs
  
reduce :: Monad m => (Expr -> ReachT m (Atom, [Conts])) -> Atom -> [Conts] -> ReachT m (Atom, [Conts])
reduce r  (Lam x e) [] = return (Lam x e, [])
--reduce r (Lam x e) [] = return $ Cont (Lam x e) []
--reduce r (Con cid es) [] = return $ Cont (Con cid es) []
--                          
--reduce r (Lam x e') (Apply e : conts) = do
--  e'' <- bind x e e'
--  r e'' conts
--
--reduce r (Con cid es) (Branch as : conts) = 
--  let Cont e cs = match cid es as
--  in r e (cs ++ conts)
--
--reduce r (Case e as) conts = 
--  r e (Branch (fmap (fmap toCont) as) : conts)
--
--reduce r (Let x e e') conts 
--reduce r (Fun fid) conts = do
--  e <- use (funcs . at' fid . body) 
--  r e conts
--
--reduce r (EVar x) conts = do
--  Cont e cs <-  use (env . at' x)
--  Cont e' cs' <- r e cs 
--  env . at x ?= Cont e' cs' 
--  r e' (cs' ++ conts)
--
--reduce r (App f e) conts = r f (Apply e : conts)
--
--reduce r (FVar x) conts = do
--  c <- use (free . at x)
--  case c of
--    Just (cid, fids) -> r (Con cid (map FVar fids)) conts
--    Nothing -> return (Cont (FVar x) conts)
--
--reduce r (LVar x) conts = return (Cont (LVar x) conts)
--
--reduce r e cs = error ("Unexpected case in reduce: \n"++show e ++"\n" ++ show cs)


match ::  CId -> [Atom] -> [Alt Expr] -> Expr
match  cid es (Alt cid' xs c : as)
  | cid == cid' = replaceLVars xs es c  
  | otherwise   = match cid es as
match _ _ [] = error "no match for constructor in case"
                         

binds :: Monad m => [LId] -> [Expr] -> Expr -> ReachT m Expr 
binds (x : xs) (e : es) e' = bind x e e' >>= binds xs es
binds [] [] e' = return e'
binds _ _ _ = error "Constructor / Alterenative variable mismatch"

-- Bind x to e in e', A new environment variable, ex, is created for x and the
-- variable x is replaced with ex in e'. Then ex is bound to e in the environment.
bind :: Monad m => LId -> Expr -> Expr -> ReachT m Expr 
bind x e c = do
  ex <- use nextEVar
  nextEVar += 1
  env . at ex ?= e
  return (replaceLVar x (EVar ex) c)

replaceLVars :: [LId] -> [Atom] -> Expr -> Expr
replaceLVars [] [] e = e
replaceLVars (v : vs) (e : es) e' = replaceLVar v e (replaceLVars vs es e')

replaceLVar :: LId -> Atom -> Expr -> Expr
replaceLVar v a (Let x e e')
  | x == v    = Let x e e'
  | otherwise = Let x (replaceLVar v a e) (replaceLVar v a e')
replaceLVar v a (Expr e cs) = Expr (replaceAtom v a e) (map replaceConts cs)
   where
     replaceConts (Apply e) = Apply (replaceLVar v a e)
     replaceConts (Branch as) = Branch $ map replaceAlt as

     replaceAlt (Alt c vs e)
       | v `elem` vs  = Alt c vs e
       | otherwise    = Alt c vs (replaceLVar v a e)

replaceAtom :: LId -> Atom -> Atom -> Atom
replaceAtom v a (Fun f) = Fun f
replaceAtom v a (EVar x) = EVar x
replaceAtom v a (LVar v')
  | v == v'   = a 
  | otherwise = LVar v' 
replaceAtom v a (Lam x e)
  | v == x    = Lam x e
  | otherwise = Lam x (replaceLVar v a e)
replaceAtom v a (FVar x) = FVar x
--                               Cont (replaceLVarExpr v e e')
--                                    (map replaceConts as)
--  where replaceConts (Branch as) = Branch $ (fmap . fmap) (replaceLVar v e) as
--        replaceConts (Apply e') = Apply $ replaceLVarExpr v e e'

--replaceLVarExpr :: LId -> Expr -> Expr -> Expr
--replaceLVarExpr lx ex (Let x e e') = Let x (replaceLVarExpr lx ex e) (replaceLVarExpr lx ex e')
--replaceLVarExpr lx ex (Fun f) = Fun f
--replaceLVarExpr lx ex (EVar x) = EVar x
--replaceLVarExpr lx ex (LVar lx')
--  | lx == lx' = ex
--  | otherwise = LVar lx'
--replaceLVarExpr lx ex (App e e') = App (replaceLVarExpr lx ex e) (replaceLVarExpr lx ex e')
--replaceLVarExpr lx ex (Lam x e)
--  | x == lx = Lam x e
--  | otherwise = Lam x (replaceLVarExpr lx ex e)
--replaceLVarExpr lx ex (Case e as) = Case (replaceLVarExpr lx ex e) (map replaceAlt as)
--    where replaceAlt (Alt cid xs e') = Alt cid xs (replaceLVarExpr lx ex e')
--replaceLVarExpr lx ex (Con cid es) = Con cid (fmap (replaceLVarExpr lx ex) es)
--replaceLVarExpr lx e (FVar x) = FVar x 

newFVars :: Monad m => Int -> StateT Env m [FId]
newFVars n = replicateM n newFVar

newFVar :: Monad m => StateT Env m FId
newFVar = do
  x <- use nextFVar
  nextFVar += 1
  return x




