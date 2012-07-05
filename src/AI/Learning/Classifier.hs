{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE UndecidableInstances #-}

module AI.Learning.Classifier (
    -- * Classes
      Classifier (..), TrainingTest (..)
    -- * Types
    , Weight, Score, StrongClassifier (..)
    -- * Functions
    , splitTests, classifierScore, subStrongClassifiers, strongClassifierScores
    ) where

import Data.Function
import Data.List
import qualified Data.Map as M

-- | Weight between 0 and 1 of classifiers and tests.
type Weight = Double
-- | Score of a classifier between 0 (full failure) and 1 (full success).
type Score = Double

-- | Represents an instance of a classifier able to classify a type of tests
-- for a class of items.
--
-- Minimal complete definition: 'cClassScore'.
class Classifier c t cl | c t -> cl where
    -- | Infers the class of the test using the classifier.
    cClass :: c -> t -> cl

    -- | Infers the class of the test using the classifier with a score ([0;1]
    -- with @1@ for sure, @0@ for unlikely).
    cClassScore :: c -> t -> (cl, Score)

    cClass classifier = fst . (classifier `cClassScore`)
    {-# INLINE cClass #-}

-- | Represents an instance of a testable item (entry, image ...) used during
-- learning processes with a method to gets its class identifier (i.e. Bool
-- for binary classes ...).
class TrainingTest t cl | t -> cl where
    -- | Gives the class identifier of the test.
    tClass :: t -> cl

-- | A 'StrongClassifier' is a trained container with a set of weak classifiers.
-- The 'StrongClassifier' can be trained with the 'adaBoost' algorithm.
data StrongClassifier a = StrongClassifier {
      scClassifiers :: [(a, Weight)] -- ^ Weak classifiers with weight
    } deriving (Show, Read)
    
-- | Represents all the classes usable for the 'StrongClassifier'.
-- Each instance must be able to classify an item using 'StrongClassifier' 
-- with an unspecified 'Classifier' type.
-- 
-- Minimal complete definition: 'scClassScore'.
class StrongClassifierClass cl where
    scClassScore :: Classifier weak t cl
                 => StrongClassifier weak -> t -> (cl, Score)

    scClass :: Classifier weak t cl
            => StrongClassifier weak -> t -> cl
    
    scClass classifier = fst . (classifier `scClassScore`)
    {-# INLINE scClass #-}
    
-- | Each 'StrongClassifier' can be used as a 'Classifier' if the contained
-- weak classifier type is itself an instance of 'Classifier' and the class
-- is an instance of 'StrongClassifierClass'.
-- The 'StrongClassifier' will give the class with the strongest score.
instance (Classifier weak t cl, StrongClassifierClass cl) =>
         Classifier (StrongClassifier weak) t cl where
    cClassScore = scClassScore
    {-# INLINE cClassScore #-}
    
    cClass = scClass
    {-# INLINE cClass #-}

-- | Instance for binary classes.
instance StrongClassifierClass Bool where
    StrongClassifier cs `scClassScore` test =
        if trueScore > falseScore then (True, trueScore)
                                  else (False, falseScore)
      where
        (trueScore, falseScore) = foldl' step (0, 0) cs
        step (ts, fs) (c, w) =
            let (valid, score) = c `cClassScore` test
            in if valid then (ts + score * w, fs)
                        else (ts, fs + score * w)
    {-# INLINE scClassScore #-}

-- | Instance for classes with more than two states.
instance StrongClassifierClass Int where
    StrongClassifier cs `scClassScore` test =
        maximumBy (compare `on` snd) classesScores
      where
        -- Uses a 'Map' to sum weights by classes.
        -- Gives the list of classes with score.
        classesScores = M.toList $ foldl' step M.empty cs
        step acc (c, w) =
            let (cl, score) = c `cClassScore` test
            in M.insertWith' (+) cl (w * score) acc
    {-# INLINE scClassScore #-}

-- | Splits the list of tests in two list of tests, for training and testing
-- following the ratio.
splitTests :: Rational -> [a] -> ([a], [a]) 
splitTests ratio ts =
    splitAt (round $ fromIntegral (length ts) * ratio) ts

-- | Gives the score that the classifier gets on the set of tests. 
classifierScore :: (Classifier c t cl, TrainingTest t cl, Eq cl)
                => c -> [t] -> Score
classifierScore classifier ts =
    let valid = filter (\t -> tClass t == classifier `cClass` t) ts
    in fromIntegral (length valid) / fromIntegral (length ts)

-- | Lists all sub-'StrongClassifier's possibles with the sub-sequences of 
-- weak classifiers from the 'StrongClassifier'.
subStrongClassifiers :: StrongClassifier a -> [StrongClassifier a]
subStrongClassifiers (StrongClassifier cs) =
    map (StrongClassifier . flip take cs) [1..length cs]

-- | Lists all sub-'StrongClassifier's with their scores.
strongClassifierScores
    :: (Classifier (StrongClassifier a) t cl, TrainingTest t cl, Eq cl)
    => StrongClassifier a -> [t] -> [(StrongClassifier a, Score)]
strongClassifierScores classifier ts =
    let subs = subStrongClassifiers classifier
    in map (\c -> (c, classifierScore c ts)) subs