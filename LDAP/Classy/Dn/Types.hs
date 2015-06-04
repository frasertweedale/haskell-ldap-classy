{-# LANGUAGE TemplateHaskell #-}
module LDAP.Classy.Dn.Types where

import           Control.Lens       (makePrisms)
import           Data.List.NonEmpty (NonEmpty)
import           Data.Monoid        (Monoid (mappend, mempty))
import qualified Data.Monoid        as M
import           Data.Semigroup     (Semigroup ((<>)))
import           Data.Text          (Text)
import qualified Data.Text          as T

data AttrType
  = LocalityName
  | CommonName
  | StateOrProvinceName
  | OrganizationName
  | OrganizationalUnitName
  | CountryName
  | StreetAddress
  | DomainComponent
  | UserId
  | OtherAttrType Text
  | OidAttrType Integer
  deriving (Eq)

instance Show AttrType where
  show LocalityName           = "L"
  show CommonName             = "CN"
  show StateOrProvinceName    = "ST"
  show OrganizationName       = "O"
  show OrganizationalUnitName = "OU"
  show CountryName            = "C"
  show StreetAddress          = "STREET"
  show DomainComponent        = "DC"
  show UserId                 = "UID"
  show (OtherAttrType t)      = T.unpack t
  show (OidAttrType i)        = show i

newtype RelativeDn = RelativeDn
  { unRelativeDn :: NonEmpty (AttrType,Text)
  } deriving (Eq)

-- BUG: Note that our derived equality here doesn't work in all cases
-- because we at least need to treat the relative DNs as sets rather
-- than have the ordering affect equality. There is something in an
-- RFC about this that I'll have to read later.
newtype Dn = Dn { unDn :: [RelativeDn] } deriving (Eq)

instance Semigroup Dn where
  (Dn nel1) <> (Dn nel2) = Dn (nel1 <> nel2)

instance Monoid Dn where
  mappend = (<>)
  mempty  = Dn mempty