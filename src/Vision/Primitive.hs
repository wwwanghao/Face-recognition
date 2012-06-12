module Vision.Primitive (
    -- * Types & constructors
      Point (..), Size (..), Rect (..)
    -- * Utilities
    , sizeBounds, sizeRange
    ) where

import Data.Ix

data Point a = Point { 
      pX :: !a, pY :: !a
    } deriving (Show, Read, Eq, Ord)
    
instance Ix a => Ix (Point a) where
    range (Point x1 y1, Point x2 y2) =
        map (uncurry Point) $ range ((x1, y1), (x2, y2))
    {-# INLINE range #-}
    
    index (Point x1 y1, Point x2 y2) (Point x y) = 
        index ((x1, y1), (x2, y2)) (x, y)
    {-# INLINE index #-}
        
    inRange (Point x1 y1, Point x2 y2) (Point x y) =
        inRange ((x1, y1), (x2, y2)) (x, y)
    {-# INLINE inRange #-}

    rangeSize (Point x1 y1, Point x2 y2) =
        rangeSize ((x1, y1), (x2, y2))
    {-# INLINE rangeSize #-}

data Size = Size { 
      sWidth :: {-# UNPACK #-} !Int
    , sHeight :: {-# UNPACK #-} !Int 
    } deriving (Show, Read, Eq)

data Rect = Rect {
      rX :: {-# UNPACK #-} !Int, rY :: {-# UNPACK #-} !Int
    , rWidth :: {-# UNPACK #-} !Int, rHeight :: {-# UNPACK #-}  !Int
    } deriving (Show, Read, Eq)
    
-- | Returns the bounds of coordinates of a rectangle of the given size.
sizeBounds :: Size -> (Point Int, Point Int)
sizeBounds (Size w h) = (Point 0 0, Point (w-1) (h-1))
{-# INLINE sizeBounds #-}
    
-- | Returns a list of coordinates within a rectangle of the given size.
sizeRange :: Size -> [Point Int]
sizeRange = range . sizeBounds
{-# INLINE sizeRange #-}