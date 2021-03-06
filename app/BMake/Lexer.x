{

{-# LANGUAGE OverloadedStrings			#-}
{-# LANGUAGE CPP				#-}
{-# OPTIONS_GHC -fno-warn-unused-binds		#-}
{-# OPTIONS_GHC -fno-warn-missing-signatures	#-}
{-# OPTIONS_GHC -fno-warn-unused-matches	#-}
{-# OPTIONS_GHC -fno-warn-unused-imports	#-}
{-# OPTIONS_GHC -fno-warn-name-shadowing	#-}
{-# OPTIONS_GHC -fno-warn-tabs			#-}

module BMake.Lexer
  ( Alex(..)
  , AlexPosn(..)
  , AlexState(..)
  , Token(..)
  , TokenClass(..)
  , AlexUserState(..)
  , alexMonadScan
  , tokenToPosN
  , tokenToLineN
  , runAlex
  , getUserState
  , modifyUserState
  , alexSetStartCode
  , alexStructError
  )
where

import qualified Data.ByteString.Lazy.Char8 as B
import qualified Data.ByteString.Char8 as BS
import Data.ByteString.Lazy (ByteString)
import qualified Control.Monad as Control.Monad

}

%wrapper "monadUserState-bytestring"
$space = [ \n \ \t ]

$letter   = [a-zA-Z]
$digit    = 0-9
@sp       = $space*

state:-

  <0>      include                 { tok         TokenInclude	  }
  <0>      local                   { tok         TokenLocal   	  }
  <0>      ifeq                    { tok         TokenIfEq  	  }
  <0>      ifneq                   { tok         TokenIfNEq  	  }
  <0>      else                    { tok         TokenElse    	  }
  <0>      endif                   { tok         TokenEndif   	  }

  <0>      [^ \% \$ \\ \n \# \* \( \) \{ \} \, \: \= \? \ \t]+
                                   { tokStr      TokenOther             }
  <0>      [ \ ]+                  { tokStr      TokenWhitespace       }
  <0>      \? \=                   { tok         TokenEqualMaybe       }
  <0>      \=                      { tok         TokenEqual            }
  <0>      \:                      { tok         TokenColon            }
  <0>      \(                      { tok         TokenParenOpen        }
  <0>      \)                      { tok         TokenParenClose       }
  <0>      \{                      { tok         TokenCurlyOpen        }
  <0>      \}                      { tok         TokenCurlyClose       }
  <0>      \,                      { tok         TokenComma            }
  <0>      \%                      { tok         TokenPercent          }
  <0>      \*                      { tok         TokenAsterik          }
  <0>      \$ [\. \@ \^ \< \| \*]
                                   { tokDC       1 Nothing             }
  <0>      \$ \( [\@ \^ \< \| \*] (D|F) \)
                                   { tokDC       2 (Just 3)            }
  <0>      \$                      { tok         TokenDollar           }
  <0>      [ \n ]+ [ \t ]          { tok         TokenNewLineAndTab    }
  <0>      \\ \n                   ;
  <0>      \\ \#                   { tokStr      TokenOther            }
  <0>      \\ .                    { tokStr      TokenOther            }
  <0>      \n                      { tok         TokenNewLine          }
  <0>      \# .*                   ;

{

getUserState :: Alex AlexUserState
getUserState = Alex $ \s -> Right (s, alex_ust s)

modifyUserState :: (AlexUserState -> AlexUserState) -> Alex ()
modifyUserState f = Alex $ \s -> Right (s{alex_ust=f (alex_ust s)}, ())

-- Some action helpers:
tok' r f (p, _, input, _) len = do
   case r of
      Just i -> alexSetStartCode i
      Nothing -> return ()
   return $ Token p (f (B.take (fromIntegral len) input))

tok x = tok' Nothing (\s -> x)
mkStr = BS.pack . B.unpack
tokStr x = tok' Nothing (\s -> x s)

tokDC varP modP =
    tok' Nothing (\s -> TokenDollarChar ((B.index s varP), (fmap (\x -> B.index s x) modP)))

alexStructError (line, column, e) = alexError $ "show-error: " ++ (show (line, column, e))
token_fail e ((AlexPn _ line column), _, input) len = alexStructError (line, column, e :: String)


-- The token type:
data Token = Token AlexPosn TokenClass
  deriving (Show)

tokenToPosN :: Token -> AlexPosn
tokenToPosN (Token p _) = p

tokenToLineN :: Token -> Int
tokenToLineN token = let (AlexPn _ line col) = tokenToPosN token in line

data TokenOther
 = Cont

data TokenClass
 = TokenInclude
 | TokenLocal
 | TokenWhitespace ByteString
 | TokenOther ByteString
 | TokenLineCont
 | TokenNewLine
 | TokenComment
 | TokenEOF
 | TokenNewLineAndTab
 | TokenEqual
 | TokenEqualMaybe
 | TokenColon
 | TokenParenOpen
 | TokenParenClose
 | TokenCurlyOpen
 | TokenCurlyClose
 | TokenComma
 | TokenPercent
 | TokenAsterik
 | TokenDollar
 | TokenDollarChar (Char, Maybe Char)
 | TokenIfNEq
 | TokenIfEq
 | TokenElse
 | TokenEndif
 deriving (Eq, Show)

alexEOF :: Alex Token
alexEOF = do
  (p, _, _, _) <- alexGetInput
  return $ Token p TokenEOF

data AlexUserState = AlexUserState
    { prevTokens :: (Maybe Token, Maybe Token)
    }
alexInitUserState = AlexUserState (Nothing, Nothing)
}
