module Reach.Eval.Expr where

import Reach.Lens
import Data.DList

import Control.Monad

type LId = Int 
type EId = Int
type CId = Int 
type FId = Int

data Expr
  = Let !LId Expr Expr
  | Fun {-# UNPACK #-} !FId
  | EVar !EId
  | LVar !LId
  | App Expr Expr 
  | Lam !LId Expr
  | Case Expr [Alt] 

  -- A constructors arguments should be atoms: either a variable or
  -- further atoms. This is for efficiency, ensuring every expression
  -- is only evaluated once.
  | Con !CId (DList Atom) deriving Show

data Alt = Alt !CId [LId] Expr deriving Show

-- Atoms are nested constructors with variables at their leaves.
type Atom = Expr

data Func =
  Func {_body :: Expr,
        _vars :: Int
       } deriving Show

makeLenses ''Func





-- An atom should either be a Var or (Con [Atom])


