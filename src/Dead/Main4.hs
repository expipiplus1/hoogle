
{- |
    Provides the 'main' function for the Console version.
    Handles command line arguments.
-}

module CmdLine.Main where

import Hoogle.All
import General.Code

import System.Environment
import Data.List
import Data.Maybe
import Data.Char
import System.Directory
import Control.Monad
import System.FilePath


versionNum = "4.0 pre"


-- | The main function
main :: IO ()
main =
    do 
        args <- getArgs
        case args of
            [] -> putStr helpMsg
            (('@':_):_) -> adminMode args
            _ -> hoogle $ safeArrow $ joinArgs args
    where
        joinArgs = concat . intersperse " " . map f
            where
                f x | ' ' `elem` x = "\"" ++ x ++ "\""
                    | otherwise = x
        
        safeArrow xs = f xs
            where
                f ('-':'#':xs) = '-':'>':f xs
                f (x:xs) = x : f xs
                f [] = []


-- | Features only available from the command line version
adminMode :: [String] -> IO ()
adminMode ("@convert":from:to) = do
        convert from dest
        putStrLn $ "Success, " ++ dest ++ " created"
    where dest = if null to then replaceExtension from ".hoo" else head to

adminMode ("@view":file:sect) = do
        db <- loadDataBase file
        if null sect then print db else putStrLn $ showDataBase (head sect) db

adminMode _ = putStr $ unlines
    ["Unrecognised @admin command, expecting one of:"
    ,""
    ,"  @convert file.txt [file.hoo]"
    ,"  @view file.hoo [section]"
    ,""
    ,"For normal help do --help."
    ]



-- do a search of some form
hoogle :: String -> IO ()
hoogle str =
    do
        let query = parseQuery str
        case query of
            Left x -> putStrLn $ "Parse error in query: " ++ show x
            Right x@Query{flags=flags}
                | version flags -> putStr versionMsg
                | help flags -> putStr helpMsg
                | not (usefulQuery x) -> putStrLn "This query does not do anything useful"
                | otherwise -> do
                    let file = fromMaybe "base.hoo" (path flags)
                    database <- loadDataBase file
                    hoogle2 database x


verbose = isJust . getFlag ["verbose"]
version = isJust . getFlag ["v","version","ver"]
help    = isJust . getFlag ["?","h","help"]
color   = isJust . getFlag ["c","col","colour","color"]
path    = getFlag ["p","path"]
count x = getFlag ["count","n"] x >>= safeRead


safeRead x = case reads x of
                  [(a,"")] -> Just a
                  _ -> Nothing



-- cannot error, give preformed results
hoogle2 :: DataBase -> Query -> IO ()
hoogle2 database query@Query{flags=flags} =
    do
        let suggest = suggestQuery database query
        when (isJust suggest) $ putStrLn $ "Suggestion: " ++ showTag (fromJust suggest)
        
        when (col && isJust (typeSig query)) $ putStrLn $ showTag $ renderQuery query
        
        res <- return $ case count flags of
                Nothing -> searchAll   [database] query
                Just n  -> searchRange [database] query 0 (max 1 n)
        
        putStr $ unlines $ map f res
    where
        col = color flags
        
        f x = showTag (renderResult x) ++ showExtra x
        showTag = if col then showTagConsole else show
        showExtra x = if verbose flags && not (null s) then " --" ++ s else ""
            where s = verboseResult x
        
{-



            if a == 
        
        
        let cmdline = safeArrow $ joinArgs args
        
        let newargs = map safeArrow args
            (flags,query) = parseArgs newargs
            
            path = fromPath $ fromMaybe (Path "hoogle.txt") (find isPath flags)
            verbose = Verbose `elem` flags
            help = HelpMsg `elem` flags
            color = Color `elem` flags
            count = fromCount $ fromMaybe (Count 0) (find isCount flags)
            
            query2 = concat $ intersperse " " query
            query3 = if help then "" else query2
        
        if null query3
            then putStr helpMsg
            else do
                path2 <- checkPath path
                if null path2
                    then putStrLn $ "Could not find hoogle database, looked for: " ++ path
                    else hoogle path2 verbose count color query3
    where
        safeArrow "-#" = " ->"
        safeArrow "->" = " ->"
        safeArrow xs   = map (\x -> if x == '#' then '>' else x) xs


test x = hoogle "" True 10 x


-- | Invoke hoogle.
--   The first argument is the file to use as a data file.
--   The second is a verbose flag.
--   The third is the thing to search for
hoogle :: FilePath -> Bool -> Int -> Bool -> String -> IO ()
hoogle _ _ _ _ "" = putStr helpMsg
hoogle p verbose count color x = 
        case hoogleParseError search of
            Just x -> putStrLn $ "Hoogle Error: " ++ x
            Nothing -> 
                do
                    case hoogleSuggest False search of
                        Just a -> putStrLn $ (if color then showTag else showText) a
                        Nothing -> return ()
                    if color
                        then putStrLn $ "Searching for: " ++ showTag (hoogleSearch search)
                        else return ()
                    
                    res <- if count == 0 then hoogleResults p search else hoogleRange p search 0 count
                    case res of
                        [] -> putStrLn "No matches found"
                        xs -> putStr $ unlines $ map f xs
    where
        search = hoogleParse x
    
        f res = showResult color res ++
                if verbose
                then " @ " ++ show (resultScore res) ++ " " ++ show (resultInfo res)
                else ""


showResult :: Bool -> Result -> String
showResult color (Result modu name typ _ _ _ _) =
        (if null fmodu then "" else fmodu ++ ".") ++ f name ++ " :: " ++ f typ
    where
        fmodu = f modu
        f x = if color then showTag x else showText x
        

showTag :: TagStr -> String
showTag x = f [] x
    where
        f a (Str x) = x
        f a (Tags xs) = concatMap (f a) xs
        f a (Tag code x) = case getCode code of
                            Nothing -> f a x
                            Just val -> tag (val:a) ++ f (val:a) x ++ tag a
        
        getCode "b" = Just "1"
        getCode "a" = Just "4"
        getCode "u" = Just "4"
        getCode [x] | x <= '6' && x >= '1' = Just ['3', x]
        getCode _ = Nothing
        
        tag stack = chr 27 : '[' : (concat $ intersperse ";" $ ("0":reverse stack)) ++ "m"

-}

-- | A help message to give the user, roughly what you get from hoogle --help
helpMsg :: String
helpMsg
    = versionMsg ++ unlines [
        "",
        "usage here", -- usageInfo ("Usage: hoogle [OPTION...] search") opts,
        
        "examples:",
        "  hoogle map",
        "  hoogle (a -> b) -> [a] -> [b]",
        "  hoogle [Char] -> [Bool]",
        "",
        "To aid when using certain consoles, -# is a synonym for ->",
        "Suggestions/comments/bugs to hoogle -AT- haskell.org",
        "A web version is available at www.haskell.org/hoogle"
        ]


versionMsg :: String
versionMsg
    = unlines [
        "HOOGLE " ++ versionNum ++ " - Haskell API Search",
        "(C) Neil Mitchell 2004-2007, York University, UK"
        ]


{-

isPath (Path _) = True; isPath _ = False
isCount (Count _) = True; isCount _ = False


-- | Data structure representing the falgs
data Flag = Verbose -- ^ Should verbose info be given, mainly percentage match
          | Path {fromPath :: FilePath} -- ^ Where to find the data file
          | HelpMsg -- ^ Show the help message
          | Count {fromCount :: Int}
          | Color
            deriving Eq

-- | The options available
opts :: [OptDescr Flag]
opts = [ Option ['v'] ["verbose"] (NoArg Verbose) "verbose results"
       , Option ['n'] ["count"]   ((ReqArg (\n -> Count (read n))) "30") "number of results"
       , Option ['l'] []          ((ReqArg (\p -> Path p)) "path/hoogle.txt") "path to hoogle.txt"
       , Option ['h'] ["help"]    (NoArg HelpMsg) "help message"
       , Option ['c'] ["color"]   (NoArg Color) "show with color"
       ]

-- | Parse the arguments, give out appropriate messages
parseArgs :: [String] -> ([Flag], [String])
parseArgs argv = case getOpt Permute opts argv of
        (flags,query,[]) -> (flags,query)
        (_,_,err)        -> error $ concat err ++ helpMsg



-- | If a path is given check that it exists
--   If not then try relative to yourself
checkPath :: FilePath -> IO FilePath
checkPath file = do
    b <- doesFileExist file
    if b then return file else do
        prog <- getProgName
        path <- findExecutable prog
        case path of
            Nothing -> return ""
            Just path -> do
                file <- return $ setFileName path file
                b <- doesFileExist file
                if b then return file else return ""

                    
setFileName :: FilePath -> String -> FilePath
setFileName path file = (reverse $ dropWhile (not . (`elem` "\\/")) $ reverse path) ++ file

-}
