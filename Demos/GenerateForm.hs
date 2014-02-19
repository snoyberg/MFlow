-----------------------------------------------------------------------------
--
-- Module      :  GenerateForm
-- Copyright   :
-- License     :  BSD3
--
-- Maintainer  :  agocorona@gmail.com
-- Stability   :  experimental
-- Portability :
--
-- |
--
-----------------------------------------------------------------------------
{-# LANGUAGE DeriveDataTypeable, OverloadedStrings, ExistentialQuantification #-}
module GenerateForm (

) where
import MFlow.Wai.Blaze.Html.All
import MFlow.Forms.Internals
import Control.Monad.State
import Unsafe.Coerce
import Data.Typeable
import Data.Monoid
import Data.String
import Prelude hiding (div)
import Text.Blaze.Html5.Attributes as At hiding (step)
import Data.List(nub)

import Debug.Trace

(!>)= flip trace

main=do
 userRegister "edituser" "edituser"
 runNavigation "nav" . step $ do

    let title= "form.html"

    initFormTemplate title

    desc <-  ask $ createForm title

    r <- ask $ b "This is the form created asking for input"
           ++> hr
           ++> generateForm title desc
           <++ br
           <** pageFlow "button" (submitButton "submit")

    ask $  h3 "results of the form:" ++> p << show r ++> noWidget
    return()

type Template= String
data WType = Intv | Stringv | TextArea |OptionBox[String]
           | CheckBoxes [String] | Form Template [WType] deriving (Typeable,Read,Show)

initFormTemplate title= do
  liftIO $ writetField title $
      p  "( delete this line. Press the save button to save the edits)"

  setSessionData ([] :: [WType])
  setSessionData $ Seq 0
  setSessionData $ Options []

data Result = forall a.(Typeable a, Show a) => Result a deriving (Typeable)

instance Show Result where
  show (Result x)= show x

genElem  Intv= Result <$> getInt Nothing
genElem  Stringv=  Result <$> getString Nothing
genElem TextArea=  Result <$> getMultilineText (fromString "")
genElem (OptionBox xs) =
    Result <$> getSelect (setSelectedOption ""(p   "select a option") <|>
               firstOf[setOption op  (b <<  op) | op <- xs])

genElem (CheckBoxes xs) =
    Result <$> getCheckBoxes(firstOf[setCheckBox False x <++ (b << x) | x <- xs])

genElem (Form temp desc)= Result <$> generateForm temp desc

generateForm title xs=
           input ! At.type_ "hidden" ! name "p0" ! value "()"
           ++> template title
           (pageFlow "" $ allOf $ map genElem xs )


createForm  title= do
 wraw $ do
   h3 "Create a form"
   h4 "1- login as edituser/edituser, 2- choose form elements, 3- edit the template \
      \4- save the template, 5- Save the form"
 divmenu <<<  (pageFlow "login" wlogin
  **> do br ++> wlink ("save" :: String) << b  "Save the form and continue"
            <++ br <> "(when finished)"
         getSessionData `onNothing` return []
  <** do
       wdesc <- chooseWidget <++ hr
       desc <- getSessionData `onNothing` return []
       setSessionData $ desc ++ [wdesc]
       content <- liftIO $ readtField  mempty title
       fieldview <- generateView  wdesc
       liftIO . writetField title $ content <> br <> fieldview
       )
 <**  divbody <<<  edTemplate "edituser" title (return ())

divbody= div ! At.style "float:right;width:65%"
divmenu= div ! At.style "background-color:#EEEEEE;float:left\
                 \;margin-left:10px;margin-right:10px;overflow:auto;"


newtype Seq= Seq Int deriving (Typeable)

generateView desc= View $ do
    Seq n <- getSessionData `onNothing` return (Seq 0)
    s <- get
    let n'= if n== 0 then 1 else n
    put s{mfSequence= n'}
    FormElm render _ <- runView $ genElem desc
    n'' <- gets mfSequence
    setSessionData $ Seq n''

    return $ FormElm [] $ Just ( mconcat render :: Html)



chooseWidget=
       (p $ a ! At.href "/" $ "reset") ++>

       (p <<< do absLink ("text":: String)  "text field"
                 ul <<<(li <<< wlink Intv "returning Int"
                    <|> li <<< wlink Stringv  "returning string"))

       <|> p <<< do absLink TextArea "text area"

       <|> p <<< do
              absLink ("check" :: String)  "checkBoxes"
              ul <<< (CheckBoxes <$> getOptions "comb" )

       <|> p <<< do
              absLink  ("options" :: String)  "options"
              ul <<< (OptionBox <$> getOptions "opt" )



data Options= Options [String]  deriving Typeable

--stop= noWidget

getOptions pf =  pageFlow pf  $

     do wlink ("enter" ::String) << p  " create"
        ops <- getOptions
        setSessionData $ Options []
        return ops


    <** do
        op <- getString Nothing <! [("size","8"),("placeholder","option")
                                   ,("value","1")]
               <** submitButton "add" <++ br
        mops <- (Just <$> getOptions) <|> return Nothing
        case mops of
          Nothing -> setSessionData $ Options []
          Just ops -> do
            let ops'= nub $ op:ops
            setSessionData . Options $ ops'
            wraw $ mconcat [p << op | op <- ops']

   where
   getOptions= do
     Options ops <- getSessionData `onNothing`  return (Options [])
     return ops


