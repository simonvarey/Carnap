{-# LANGUAGE RankNTypes, FlexibleContexts #-}
module Carnap.GHCJS.Action.TruthTable (truthTableAction) where

import Lib
import Carnap.GHCJS.SharedTypes
import Carnap.Core.Data.AbstractSyntaxDataTypes
import Carnap.Core.Data.AbstractSyntaxClasses (Schematizable, Modelable(..))
import Carnap.Languages.PurePropositional.Util (getIndicies)
import Carnap.Languages.PurePropositional.Syntax (PureForm)
import Carnap.Languages.Util.LanguageClasses
import GHCJS.DOM.Types
import GHCJS.DOM.Element
import GHCJS.DOM.HTMLOptionElement (getValue)
import GHCJS.DOM.Window (alert)
import GHCJS.DOM.Document (createElement, getBody, getDefaultView)
import GHCJS.DOM.Node (appendChild, getParentNode, insertBefore)
import GHCJS.DOM.EventM (newListener, addListener, EventM, target)
import Data.IORef (newIORef, IORef, readIORef,writeIORef, modifyIORef)
import Data.Map as M
import Data.List (subsequences)
import Control.Monad.IO.Class (liftIO)
import Control.Lens.Plated (children)
import Text.Parsec (parse, ParseError)

truthTableAction :: IO ()
truthTableAction = initElements getTruthTables activateTruthTables

getTruthTables :: HTMLElement -> IO [Maybe (Element, Element, [String])]
getTruthTables = getInOutElts "truthtable"

-- XXX: no dispatch on classes here yet. We'll want it for Sequent tables,
-- tables with counterexamples, etc.
activateTruthTables :: Document -> Maybe (Element, Element,[String]) -> IO ()
activateTruthTables w (Just (i,o,_)) = do Just ohtml <- getInnerHTML o
                                          case parse formAndLabel "" (decodeHtml ohtml) of
                                              (Right (l,f)) -> do
                                                  ref <- newIORef False
                                                  bt1 <- makeButton "Submit Solution"
                                                  bt2 <- makeButton "Check Solution"
                                                  gRef <- createTruthTable w f o ref
                                                  setInnerHTML i (Just $ show f)
                                                  (Just w') <- getDefaultView w                    
                                                  submit <- newListener $ trySubmit ref f w' l       
                                                  check <- newListener $ checkTable ref gRef w'
                                                  addListener bt1 click submit False                
                                                  addListener bt2 click check False                
                                              (Left e) -> print $ ohtml ++ show e
    where makeButton message = do mbt@(Just bt) <- createElement w (Just "button")
                                  setInnerHTML bt (Just message)
                                  mpar@(Just par) <- getParentNode o
                                  appendChild par mbt
                                  return bt
          checkTable ref gRef w' = do vals <- liftIO $ readIORef gRef
                                      let val = M.foldr (&&) True vals
                                      if val then do alert w' "Success!"
                                                     liftIO $ writeIORef ref True
                                                     setAttribute i "class" "completeTT"
                                             else do alert w' "Something's not quite right"
                                                     setAttribute i "class" "incompleteTT"

trySubmit :: IORef Bool -> PureForm -> Window -> String -> EventM HTMLInputElement e ()
trySubmit ref f w l = do isDone <- liftIO $ readIORef ref
                         if isDone 
                            then  liftIO $ sendJSON 
                                    (SubmitTruthTable $ l ++ ":" ++ show f) 
                                    (loginCheck $ "Submitted Truth-Table for Exercise " ++ l) 
                                    errorPopup
                            else alert w "not yet finished"

createTruthTable w f o ref = do (Just table) <- createElement w (Just "table")
                                (Just thead) <- createElement w (Just "thead")
                                (Just tbody) <- createElement w (Just "tbody")
                                gRef <- makeGridRef (length orderedChildren) (length valuations)
                                head <- toHead w atomIndicies orderedChildren
                                rows <- mapM (toRow' gRef) (zip valuations [1..])
                                appendChild table (Just thead)
                                appendChild table (Just tbody)
                                appendChild thead (Just head)
                                mapM_ (appendChild tbody . Just) (reverse rows)
                                setInnerHTML o (Just "")
                                appendChild o (Just table)
                                return gRef
    where atomIndicies = sort $ getIndicies f
          valuations = (Prelude.map toValuation) . subsequences $ reverse atomIndicies
            where toValuation l = \x -> x `elem` l
          orderedChildren = traverseBPT . toBPT $ f
          toRow' = toRow w atomIndicies orderedChildren o
          makeGridRef x y = newIORef (M.fromList [((z,w), True) | z <- [1..x], w <-[1.. y]])

--this is a sorting that gets the correct ordering of indicies (reversed on
--negative, negative less than positive, postive as usual)
sort :: [Int] -> [Int]
sort (x:xs) = smaller ++ [x] ++ bigger
    where smaller = sort (Prelude.filter small xs )
          bigger = sort (Prelude.filter (not . small) xs)
          small y | x < 0 && y > 0 = False
                  | x < 0 && y < 0 = x < y
                  | otherwise = y < x
sort [] = []

toRow w atomIndicies orderedChildren o gRef (v,n) = 
        do (Just row) <- createElement w (Just "tr")
           valTds <- mapM toValTd atomIndicies
           childTds <- mapM toChildTd (zip orderedChildren [1..])
           mapM_ (appendChild row . Just) valTds
           mapM_ (appendChild row . Just) childTds
           return row
    where toValTd i = do (Just td) <- createElement w (Just "td")
                         setInnerHTML td (Just $ if v i then "T" else "F")
                         setAttribute td "class" "valtd"
                         return td
          toChildTd (c,m) = do (Just td) <- createElement w (Just "td")
                               case c of
                                   Left c' -> setInnerHTML td (Just "")
                                   Right f -> do sel <- trueFalseOpts
                                                 appendChild td (Just sel)
                                                 modifyIORef gRef (M.insert (n,m) False)
                                                 let (Form tv) = satisfies v f
                                                 onSwitch <- newListener $ switchOnMatch gRef (n,m) tv
                                                 addListener sel change onSwitch False
                                                 return ()
                               return td
          trueFalseOpts = do (Just sel) <- createElement w (Just "select")
                             (Just bl)  <- createElement w (Just "option")
                             (Just tr)  <- createElement w (Just "option")
                             (Just fs)  <- createElement w (Just "option")
                             setInnerHTML bl (Just "-")
                             setInnerHTML tr (Just "T")
                             setInnerHTML fs (Just "F")
                             appendChild sel (Just bl)
                             appendChild sel (Just tr)
                             appendChild sel (Just fs)
                             return sel
          switchOnMatch gRef (n,m) tv = do 
                             (Just t) <- target :: EventM HTMLOptionElement Event (Maybe HTMLOptionElement)
                             s <- getValue t 
                             if s == "T" 
                                 then liftIO $ modifyIORef gRef (M.insert (n,m) tv)
                                 else liftIO $ modifyIORef gRef (M.insert (n,m) (not tv))

toHead w atomIndicies orderedChildren = 
        do (Just row) <- createElement w (Just "tr")
           atomThs <- mapM toAtomTh atomIndicies
           childThs <- mapM toChildTh orderedChildren
           mapM_ (appendChild row . Just) atomThs
           mapM_ (appendChild row . Just) childThs
           return row
    where toAtomTh i = do (Just td) <- createElement w (Just "th")
                          setInnerHTML td (Just $ show (pn i :: PureForm))
                          return td
          toChildTh c = do (Just td) <- createElement w (Just "th")
                           case c of
                               Left c' -> setInnerHTML td (Just [c'])
                               Right f -> setInnerHTML td (Just $ mcOf f)
                           return td
          mcOf :: (Schematizable (f (FixLang f)), CopulaSchema (FixLang f)) => FixLang f a -> String
          mcOf (h :!$: t) = mcOf h
          mcOf h = show h

--Binary propositional parsing tree. This could be written more compactly,
--but this seems conceptually clearer
data BPT = Leaf PureForm | MonNode PureForm BPT | BiNode PureForm BPT BPT

toBPT :: PureForm -> BPT
toBPT f = case children f of
              [a] -> MonNode f (toBPT a)
              [a,b] -> BiNode f (toBPT a) (toBPT b)
              _ -> Leaf f

traverseBPT :: BPT -> [Either Char PureForm]
traverseBPT (Leaf f) = [Right f]
traverseBPT (MonNode f a) = traverseBPT a ++ [Right f]
traverseBPT (BiNode f a b) = [Left '('] ++ traverseBPT a ++ [Right f] ++ traverseBPT b ++ [Left ')']