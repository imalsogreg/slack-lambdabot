{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ViewPatterns #-}

module Main (main) where

import Codec.Binary.UTF8.String (decodeString)
import Control.Lens (use)
import Control.Monad.IO.Class (liftIO)
-- import Data.Char (readLitChar)
import Data.Functor (void)
import Data.Maybe (fromMaybe)
import Data.Monoid ((<>))
import Data.Text (Text, dropWhile, pack, unpack, stripPrefix)
import Data.Text.Lazy (toStrict)
import Data.Text.Lazy.Builder (toLazyText)
import Debug.Trace (trace)
import HTMLEntities.Decoder (htmlEncodedText)
import qualified HTMLEntities.Builder as HTMLEncoded
import Lambdabot.Main
import Modules (modulesInfo)
import Prelude hiding (dropWhile)
import System.Environment (lookupEnv)
import System.IO.Silently (capture)
-- import Text.ParserCombinators.ReadP
import Web.Slack
import Web.Slack.Message

-------------------------------------------------------------------------------
-- Lambdabot
-------------------------------------------------------------------------------

-- | Run one or more commands against Lambdabot and capture the response.
lambdabot :: [String] -> IO String
lambdabot strs = do
  let request = void $ lambdabotMain modulesInfo [onStartupCmds :=> strs]
  (response, _) <- capture request
  return response

-------------------------------------------------------------------------------
-- Slack
-------------------------------------------------------------------------------

-- | Construct a @SlackConfig@, taking the Slack API token from an environment
-- variable.
envMkSlackConfig :: String -> IO SlackConfig
envMkSlackConfig key
  =  mkSlackConfig
 <$> fromMaybe (error $ key <> " not set")
 <$> lookupEnv key

-- | Construct a @SlackConfig@ from a Slack API token.
mkSlackConfig :: String -> SlackConfig
mkSlackConfig apiToken = SlackConfig { _slackApiToken = apiToken }

-- | Get a message if it is for \"me\".
messageForMe :: Text -> Slack a (Maybe Text)
messageForMe message = do
  myId <- use $ session . slackSelf . selfUserId . getId
  let atMyId = "<@" <> myId <> ">"
  return $ dropWhile (== ':') <$> stripPrefix atMyId message

-- | Construct a @SlackBot@ from a name. This bot will pass messages addressed
-- to it to 'lambdabot' and relay 'lambdabot''s response.
slackBot :: SlackBot a
slackBot (Message cid _ message _ _ _) = do
  requestForMe <- messageForMe message
  case requestForMe of
    Nothing -> return ()
    Just request -> do
      response <- liftIO $ lambdabot [unpack $ decodeHtml request]
      sendMessage cid ("```\n" <> (pack $ decodeString response) <> "```")
slackBot _ = return ()

encodeHtml :: Text -> Text
encodeHtml = toStrict . toLazyText . HTMLEncoded.text

decodeHtml :: Text -> Text
decodeHtml = toStrict . toLazyText . htmlEncodedText

-------------------------------------------------------------------------------
-- Main
-------------------------------------------------------------------------------

main :: IO ()
main = do
  slackConfig <- envMkSlackConfig "SLACK_API_TOKEN"
  runBot slackConfig slackBot ()