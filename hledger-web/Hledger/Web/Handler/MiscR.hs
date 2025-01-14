{-# OPTIONS_GHC -fno-warn-orphans #-}

{-# LANGUAGE FlexibleInstances   #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TemplateHaskell #-}

module Hledger.Web.Handler.MiscR
  ( getVersionR
  , getAccountnamesR
  , getTransactionsR
  , getPricesR
  , getCommoditiesR
  , getAccountsR
  , getAccounttransactionsR
  , getDownloadR
  , getFaviconR
  , getManageR
  , getRobotsR
  , getRootR
  ) where

import qualified Data.Map as M
import qualified Data.Text as T
import Yesod.Default.Handlers (getFaviconR, getRobotsR)

import Hledger
import Hledger.Web.Import
import Hledger.Web.WebOptions (packageversion)
import Hledger.Web.Widget.Common (journalFile404)

getRootR :: Handler Html
getRootR = do
  checkServerSideUiEnabled
  redirect JournalR

getManageR :: Handler Html
getManageR = do
  checkServerSideUiEnabled
  VD{j} <- getViewData
  require EditPermission
  defaultLayout $ do
    setTitle "Edit journal"
    $(widgetFile "manage")

getDownloadR :: FilePath -> Handler TypedContent
getDownloadR f = do
  checkServerSideUiEnabled
  VD{j} <- getViewData
  require EditPermission
  (f', txt) <- journalFile404 f j
  addHeader "Content-Disposition" ("attachment; filename=\"" <> T.pack f' <> "\"")
  sendResponse ("text/plain" :: ByteString, toContent txt)

-- hledger-web equivalents of the old hledger-api's handlers

getVersionR :: Handler TypedContent
getVersionR = do
  require ViewPermission
  selectRep $ provideJson $ packageversion

getAccountnamesR :: Handler TypedContent
getAccountnamesR = do
  VD{j} <- getViewData
  require ViewPermission
  selectRep $ provideJson $ journalAccountNames j

getTransactionsR :: Handler TypedContent
getTransactionsR = do
  VD{j} <- getViewData
  require ViewPermission
  selectRep $ provideJson $ jtxns j

getPricesR :: Handler TypedContent
getPricesR = do
  VD{j} <- getViewData
  require ViewPermission
  selectRep $
    provideJson $ map priceDirectiveToMarketPrice $ jpricedirectives j

getCommoditiesR :: Handler TypedContent
getCommoditiesR = do
  VD{j} <- getViewData
  require ViewPermission
  selectRep $ do
    provideJson $ (M.keys . jinferredcommodities) j

getAccountsR :: Handler TypedContent
getAccountsR = do
  VD{j} <- getViewData
  require ViewPermission
  selectRep $ do
    provideJson $ flattenAccounts $ mapAccounts (accountSetDeclarationInfo j) $ ledgerRootAccount $ ledgerFromJournal Any j

getAccounttransactionsR :: Text -> Handler TypedContent
getAccounttransactionsR a = do
  VD{j} <- getViewData
  require ViewPermission
  let
    rspec = defreportspec
    thisacctq = Acct $ accountNameToAccountRegex a -- includes subs
  selectRep $ do
    provideJson $ accountTransactionsReport rspec{_rsQuery=Any} j thisacctq

