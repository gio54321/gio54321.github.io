import Data.Void

thm :: ((Either a (a -> Void)) -> Void) -> Void
thm f = f (Right (f . Left))