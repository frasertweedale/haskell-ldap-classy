{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
module LDAP.Classy.Search
  ( MatchExpr(..)
  , LdapSearch(..)
  , (==.)
  , (~=.)
  , (*~=.)
  , (~*=.)
  , (*~*=.)
  , (<-.)
  , (>=.)
  , (<=.)
  , (&&.)
  , (||.)
  , attrPresent
  , ldapSearchStr
  , isPosixAccount
  , isPosixGroup
  ) where

import BasePrelude        hiding (first, try, (<>))
import Data.List.NonEmpty (NonEmpty (..), (<|))
import Data.Semigroup     ((<>))

data MatchExpr
  = ExactMatch String
  | LeftAnchored String
  | RightAnchored String
  | Unanchored String
  | Present
  deriving (Show)

-- |
-- >>> :set -XOverloadedStrings
-- >>> "" :: MatchExpr
-- ExactMatch ""
-- >>> "a" :: MatchExpr
-- ExactMatch "a"
-- >>> "a*s" :: MatchExpr
-- ExactMatch "a*s"
-- >>> "*s" :: MatchExpr
-- RightAnchored "s"
-- >>> "as*" :: MatchExpr
-- LeftAnchored "as"
-- >>> "*as*" :: MatchExpr
-- Unanchored "as"
-- >>> "*" :: MatchExpr
-- Present
instance IsString MatchExpr where
  fromString s = case ("*" `isPrefixOf` s,"*" `isSuffixOf` s) of
    (True,True) | s == "*" -> Present
    (True,True)           -> Unanchored . dropLast . dropFirst $ s
    (False,True)          -> LeftAnchored . dropLast $ s
    (True,False)          -> RightAnchored . dropFirst $ s
    (False,False)         -> ExactMatch s
    where
      dropFirst = drop 1
      dropLast  = reverse . drop 1 . reverse

data LdapSearch
  = LdapAnd (NonEmpty LdapSearch)
  | LdapOr  (NonEmpty LdapSearch)
  | LdapMatch String MatchExpr
  | LdapGte String String
  | LdapLte String String
  deriving (Show)

-- |
-- >>> :set -XOverloadedStrings
-- >>> "a" ==. "b"
-- LdapMatch "a" (ExactMatch "b")
(==.) :: String -> String -> LdapSearch
k ==. s = LdapMatch k (ExactMatch s)

infixl 4 ==.

-- |
-- >>> "a" ~=. "*b"
-- LdapMatch "a" (RightAnchored "b")
(~=.) :: String -> MatchExpr -> LdapSearch
k ~=. s = LdapMatch k s

infixl 4 ~=.

-- |
-- >>> "a" *~=. "b"
-- LdapMatch "a" (RightAnchored "b")
(*~=.) :: String -> String -> LdapSearch
k *~=. s = LdapMatch k (RightAnchored s)

infixl 4 *~=.

-- |
-- >>> "a" ~*=. "b"
-- LdapMatch "a" (LeftAnchored "b")
(~*=.) :: String -> String -> LdapSearch
k ~*=. s = LdapMatch k (LeftAnchored s)

infixl 4 ~*=.

-- |
-- >>> "a" *~*=. "*b*"
-- LdapMatch "a" (Unanchored "*b*")
(*~*=.) :: String -> String -> LdapSearch
k *~*=. s = LdapMatch k (Unanchored s)

infixl 4 *~*=.

-- |
-- >>> attrPresent "a"
-- LdapMatch "a" Present
attrPresent :: String -> LdapSearch
attrPresent k = LdapMatch k Present

-- |
-- >>> "a" >=. "b"
-- LdapGte "a" "b"
(>=.) :: String -> String -> LdapSearch
k >=. s = LdapGte k s

infixl 4 >=.

-- |
-- >>> "a" <=. "b"
-- LdapLte "a" "b"
(<=.) :: String -> String -> LdapSearch
k <=. s = LdapLte k s

infixl 4 <=.

-- |
-- >>> "a" ==. "a" &&. "b" ==. "b"
-- LdapAnd (LdapMatch "a" (ExactMatch "a") :| [LdapMatch "b" (ExactMatch "b")])
-- >>> "a" ==. "a" &&. "b" ==. "b" &&. "c" ==. "c"
-- LdapAnd (LdapMatch "a" (ExactMatch "a") :| [LdapMatch "b" (ExactMatch "b"),LdapMatch "c" (ExactMatch "c")])
-- >>> ("a" ==. "a" &&. "b" ==. "b") &&. "c" ==. "c"
-- LdapAnd (LdapMatch "a" (ExactMatch "a") :| [LdapMatch "b" (ExactMatch "b"),LdapMatch "c" (ExactMatch "c")])
-- >>> "a" ==. "a" &&. ("b" ==. "b" &&. "c" ==. "c")
-- LdapAnd (LdapMatch "a" (ExactMatch "a") :| [LdapMatch "b" (ExactMatch "b"),LdapMatch "c" (ExactMatch "c")])
-- >>> ("a" ==. "a" &&. "b" ==. "b") &&. ("c" ==. "c" &&. "d" ==. "d")
-- LdapAnd (LdapMatch "a" (ExactMatch "a") :| [LdapMatch "b" (ExactMatch "b"),LdapMatch "c" (ExactMatch "c"),LdapMatch "d" (ExactMatch "d")])
(&&.) :: LdapSearch -> LdapSearch -> LdapSearch
(LdapAnd es1) &&. (LdapAnd es2) = LdapAnd (es1 <> es2)
e1 &&. (LdapAnd es2)            = LdapAnd (e1 <| es2)
(LdapAnd es1) &&. e2            = LdapAnd (es1 <> pure e2)
e1 &&. e2                       = LdapAnd (e1 :| [e2])

infixl 3 &&.

-- |
-- >>> "a" ==. "a" ||. "b" ==. "b"
-- LdapOr (LdapMatch "a" (ExactMatch "a") :| [LdapMatch "b" (ExactMatch "b")])
-- >>> "a" ==. "a" ||. "b" ==. "b" ||. "c" ==. "c"
-- LdapOr (LdapMatch "a" (ExactMatch "a") :| [LdapMatch "b" (ExactMatch "b"),LdapMatch "c" (ExactMatch "c")])
-- >>> ("a" ==. "a" ||. "b" ==. "b") ||. "c" ==. "c"
-- LdapOr (LdapMatch "a" (ExactMatch "a") :| [LdapMatch "b" (ExactMatch "b"),LdapMatch "c" (ExactMatch "c")])
-- >>> "a" ==. "a" ||. ("b" ==. "b" ||. "c" ==. "c")
-- LdapOr (LdapMatch "a" (ExactMatch "a") :| [LdapMatch "b" (ExactMatch "b"),LdapMatch "c" (ExactMatch "c")])
-- >>> ("a" ==. "a" ||. "b" ==. "b") ||. ("c" ==. "c" ||. "d" ==. "d")
-- LdapOr (LdapMatch "a" (ExactMatch "a") :| [LdapMatch "b" (ExactMatch "b"),LdapMatch "c" (ExactMatch "c"),LdapMatch "d" (ExactMatch "d")])
(||.) :: LdapSearch -> LdapSearch -> LdapSearch
(LdapOr es1) ||. (LdapOr es2) = LdapOr (es1 <> es2)
e1 ||. (LdapOr es2)           = LdapOr (e1 <| es2)
(LdapOr es1) ||. e2           = LdapOr (es1 <> pure e2)
e1 ||. e2                     = LdapOr (e1 :| [e2])

infixl 2 ||.

-- |
-- >>> "a" <-. (ExactMatch "a") :| [ExactMatch "b",Unanchored "c"]
-- LdapOr (LdapMatch "a" (ExactMatch "a") :| [LdapMatch "a" (ExactMatch "b"),LdapMatch "a" (Unanchored "c")])
in_,(<-.) :: String -> NonEmpty MatchExpr -> LdapSearch
in_ k ss = LdapOr . fmap (LdapMatch k) $ ss

(<-.) = in_

infixl 4 <-.
infixl 4 `in_`

-- |
-- >>> :set -XOverloadedStrings
-- >>> ldapSearchStr $ "objectClass" ==. "posixAccount"
-- "(objectClass=posixAccount)"
-- >>> ldapSearchStr $ "objectClass" ==. "posixAccount" &&. "uid" ==. "bkolera"
-- "(&(objectClass=posixAccount)(uid=bkolera))"
-- >>> ldapSearchStr $ "objectClass" ==. "posixAccount" &&. "loginShell" ==. "/bin/zsh" ||. "uid" ==. "bkolera"
-- "(|(&(objectClass=posixAccount)(loginShell=/bin/zsh))(uid=bkolera))"
-- >>> ldapSearchStr $ "objectClass" ==. "posixAccount" &&. "givenName" <-. "Ben*" :| ["Bob"]
-- "(&(objectClass=posixAccount)(|(givenName=Ben*)(givenName=Bob)))"
ldapSearchStr :: LdapSearch -> String
ldapSearchStr (LdapMatch k s)  = wrapParens $ escape k <> "=" <> matchExprStr s
ldapSearchStr (LdapGte k s) = operExprStr k ">=" s
ldapSearchStr (LdapLte k s) = operExprStr k "<=" s
ldapSearchStr (LdapAnd as)  = listExprStr "&" as
ldapSearchStr (LdapOr as)   = listExprStr "|" as

operExprStr :: String -> String -> String -> String
operExprStr k o s = wrapParens $ escape k <> o <> escape s

matchExprStr :: MatchExpr -> String
matchExprStr (ExactMatch s)    = escape s
matchExprStr (LeftAnchored s)  = escape s <> "*"
matchExprStr (RightAnchored s) = "*" <> escape s
matchExprStr (Unanchored s)    = "*" <> escape s <> "*"
matchExprStr Present           = "*"

listExprStr :: String -> NonEmpty LdapSearch -> String
listExprStr o es = wrapParens $ o <> foldMap ldapSearchStr es

wrapParens :: String -> String
wrapParens s = "(" <> s <> ")"

-- https://www.owasp.org/index.php/Preventing_LDAP_Injection_in_Java
-- But what about '=',"<",">" (esp for keys)?
escape :: String -> String
escape "\\" = "\\"
escape "*"  = "\\*"
escape "("  = "\\("
escape ")"  = "\\)"
escape "\0" = "\\00"
escape a    = a

isPosixAccount :: LdapSearch
isPosixAccount = "objectClass" ==. "posixAccount"
isPosixGroup :: LdapSearch
isPosixGroup   = "objectClass" ==. "posixGroup"