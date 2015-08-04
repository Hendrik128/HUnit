HUnitTestBase.lhs  --  test support and basic tests (Haskell 98 compliant)

> module HUnitTestBase where

> import Test.HUnit
> import Test.HUnit.Terminal (terminalAppearance)
> import System.IO (IOMode(..), openFile, hClose)


> data Report = Start State
>             | Error String State
>             | UnspecifiedError State
>             | Failure String State
>   deriving (Show, Read)

> instance Eq Report where
>   Start s1            == Start s2             =  s1 == s2
>   Error m1 s1         == Error m2 s2          =  m1 == m2 && s1 == s2
>   Error _  s1         == UnspecifiedError s2  =  s1 == s2
>   UnspecifiedError s1 == Error _  s2          =  s1 == s2
>   UnspecifiedError s1 == UnspecifiedError s2  =  s1 == s2
>   Failure m1 s1       == Failure m2 s2        =  m1 == m2 && s1 == s2
>   _                   == _                    =  False


> expectReports :: [Report] -> Counts -> Test -> Test
> expectReports reports1 counts1 t = TestCase $ do
>   (counts2, reports2) <- performTest (\  ss us -> return (Start     ss : us))
>                                      (\m ss us -> return (Error   m ss : us))
>                                      (\m ss us -> return (Failure m ss : us))
>                                      [] t
>   assertEqual "for the reports from a test," reports1 (reverse reports2)
>   assertEqual "for the counts from a test," counts1 counts2


> simpleStart :: Report
> simpleStart = Start (State [] (Counts 1 0 0 0))

> expectSuccess :: Test -> Test
> expectSuccess = expectReports [simpleStart] (Counts 1 1 0 0)

> expectProblem :: (String -> State -> Report) -> Int -> String -> Test -> Test
> expectProblem kind err msg =
>   expectReports [simpleStart, kind msg (State [] counts')] counts'
>  where counts' = Counts 1 1 err (1-err)

> expectError, expectFailure :: String -> Test -> Test
> expectError   = expectProblem Error   1
> expectFailure = expectProblem Failure 0

> expectUnspecifiedError :: Test -> Test
> expectUnspecifiedError = expectProblem (\ _msg st -> UnspecifiedError st) 1 undefined


> data Expect = Succ | Err String | UErr | Fail String

> expect :: Expect -> Test -> Test
> expect Succ     t = expectSuccess t
> expect (Err m)  t = expectError m t
> expect UErr     t = expectUnspecifiedError t
> expect (Fail m) t = expectFailure m t



> baseTests :: Test
> baseTests = test [ assertTests,
>                    testCaseCountTests,
>                    testCasePathsTests,
>                    reportTests,
>                    textTests,
>                    showPathTests,
>                    showCountsTests,
>                    assertableTests,
>                    predicableTests,
>                    compareTests,
>                    extendedTestTests ]


> ok :: Test
> ok = test (assert ())
> bad :: String -> Test
> bad m = test (assertFailure m)


> assertTests :: Test
> assertTests = test [

>   "null" ~: expectSuccess ok,

>   "userError" ~:
>     expectError "user error (error)" (TestCase (ioError (userError "error"))),

>   "IO error (file missing)" ~:
>     expectUnspecifiedError
>       (test (do _ <- openFile "3g9djs" ReadMode; return ())),

   "error" ~:
     expectError "error" (TestCase (error "error")),

   "tail []" ~:
     expectUnspecifiedError (TestCase (tail [] `seq` return ())),

    -- GHC doesn't currently catch arithmetic exceptions.
   "div by 0" ~:
     expectUnspecifiedError (TestCase ((3 `div` 0) `seq` return ())),

>   "assertFailure" ~:
>     let msg = "simple assertFailure"
>     in expectFailure msg (test (assertFailure msg)),

>   "assertString null" ~: expectSuccess (TestCase (assertString "")),

>   "assertString nonnull" ~:
>     let msg = "assertString nonnull"
>     in expectFailure msg (TestCase (assertString msg)),

>   let f v non =
>         show v ++ " with " ++ non ++ "null message" ~:
>           expect (if v then Succ else Fail non) $ test $ assertBool non v
>   in "assertBool" ~: [ f v non | v <- [True, False], non <- ["non", ""] ],

>   let msg = "assertBool True"
>   in msg ~: expectSuccess (test (assertBool msg True)),

>   let msg = "assertBool False"
>   in msg ~: expectFailure msg (test (assertBool msg False)),

>   "assertEqual equal" ~:
>     expectSuccess (test (assertEqual "" (3 :: Integer) (3 :: Integer))),

>   "assertEqual unequal no msg" ~:
>     expectFailure "expected: 3\n but got: 4"
>       (test (assertEqual "" (3 :: Integer) (4 :: Integer))),

>   "assertEqual unequal with msg" ~:
>     expectFailure "for x,\nexpected: 3\n but got: 4"
>       (test (assertEqual "for x," (3 :: Integer) (4 :: Integer)))

>  ]


> emptyTest0, emptyTest1, emptyTest2 :: Test
> emptyTest0 = TestList []
> emptyTest1 = TestLabel "empty" emptyTest0
> emptyTest2 = TestList [ emptyTest0, emptyTest1, emptyTest0 ]
> emptyTests :: [Test]
> emptyTests = [emptyTest0, emptyTest1, emptyTest2]

> testCountEmpty :: Test -> Test
> testCountEmpty t = TestCase (assertEqual "" 0 (testCaseCount t))

> suite0, suite1, suite2, suite3 :: (Integer, Test)
> suite0 = (0, ok)
> suite1 = (1, TestList [])
> suite2 = (2, TestLabel "3" ok)
> suite3 = (3, suite)

> suite :: Test
> suite =
>   TestLabel "0"
>     (TestList [ TestLabel "1" (bad "1"),
>                 TestLabel "2" (TestList [ TestLabel "2.1" ok,
>                                           ok,
>                                           TestLabel "2.3" (bad "2") ]),
>                 TestLabel "3" (TestLabel "4" (TestLabel "5" (bad "3"))),
>                 TestList [ TestList [ TestLabel "6" (bad "4") ] ] ])

> suiteCount :: Int
> suiteCount = 6

> suitePaths :: [[Node]]
> suitePaths = [
>   [Label "0", ListItem 0, Label "1"],
>   [Label "0", ListItem 1, Label "2", ListItem 0, Label "2.1"],
>   [Label "0", ListItem 1, Label "2", ListItem 1],
>   [Label "0", ListItem 1, Label "2", ListItem 2, Label "2.3"],
>   [Label "0", ListItem 2, Label "3", Label "4", Label "5"],
>   [Label "0", ListItem 3, ListItem 0, ListItem 0, Label "6"]]

> suiteReports :: [Report]
> suiteReports = [ Start       (State (p 0) (Counts 6 0 0 0)),
>                  Failure "1" (State (p 0) (Counts 6 1 0 1)),
>                  Start       (State (p 1) (Counts 6 1 0 1)),
>                  Start       (State (p 2) (Counts 6 2 0 1)),
>                  Start       (State (p 3) (Counts 6 3 0 1)),
>                  Failure "2" (State (p 3) (Counts 6 4 0 2)),
>                  Start       (State (p 4) (Counts 6 4 0 2)),
>                  Failure "3" (State (p 4) (Counts 6 5 0 3)),
>                  Start       (State (p 5) (Counts 6 5 0 3)),
>                  Failure "4" (State (p 5) (Counts 6 6 0 4))]
>  where p n = reverse (suitePaths !! n)

> suiteCounts :: Counts
> suiteCounts = Counts 6 6 0 4

> suiteOutput :: String
> suiteOutput = concat [
>    "### Failure in: 0:0:1\n",
>    "1\n",
>    "### Failure in: 0:1:2:2:2.3\n",
>    "2\n",
>    "### Failure in: 0:2:3:4:5\n",
>    "3\n",
>    "### Failure in: 0:3:0:0:6\n",
>    "4\n",
>    "Cases: 6  Tried: 6  Errors: 0  Failures: 4\n"]


> suites :: [(Integer, Test)]
> suites = [suite0, suite1, suite2, suite3]


> testCount :: Show n => (n, Test) -> Int -> Test
> testCount (num, t) count =
>   "testCaseCount suite" ++ show num ~:
>     TestCase $ assertEqual "for test count," count (testCaseCount t)

> testCaseCountTests :: Test
> testCaseCountTests = TestList [

>   "testCaseCount empty" ~: test (map testCountEmpty emptyTests),

>   testCount suite0 1,
>   testCount suite1 0,
>   testCount suite2 1,
>   testCount suite3 suiteCount

>  ]


> testPaths :: Show n => (n, Test) -> [[Node]] -> Test
> testPaths (num, t) paths =
>   "testCasePaths suite" ++ show num ~:
>     TestCase $ assertEqual "for test paths,"
>                             (map reverse paths) (testCasePaths t)

> testPathsEmpty :: Test -> Test
> testPathsEmpty t = TestCase $ assertEqual "" [] (testCasePaths t)

> testCasePathsTests :: Test
> testCasePathsTests = TestList [

>   "testCasePaths empty" ~: test (map testPathsEmpty emptyTests),

>   testPaths suite0 [[]],
>   testPaths suite1 [],
>   testPaths suite2 [[Label "3"]],
>   testPaths suite3 suitePaths

>  ]


> reportTests :: Test
> reportTests = "reports" ~: expectReports suiteReports suiteCounts suite


> expectText :: Counts -> String -> Test -> Test
> expectText counts1 text1 t = TestCase $ do
>   (counts2, text2) <- runTestText putTextToShowS t
>   assertEqual "for the final counts," counts1 counts2
>   assertEqual "for the failure text output," text1 (text2 "")


> textTests :: Test
> textTests = test [

>   "lone error" ~:
>     expectText (Counts 1 1 1 0)
>         "### Error:\nuser error (xyz)\nCases: 1  Tried: 1  Errors: 1  Failures: 0\n"
>         (test (do _ <- ioError (userError "xyz"); return ())),

>   "lone failure" ~:
>     expectText (Counts 1 1 0 1)
>         "### Failure:\nxyz\nCases: 1  Tried: 1  Errors: 0  Failures: 1\n"
>         (test (assert "xyz")),

>   "putTextToShowS" ~:
>     expectText suiteCounts suiteOutput suite,

>   "putTextToHandle (file)" ~:
>     let filename = "HUnitTest.tmp"
>         trim = unlines . map (reverse . dropWhile (== ' ') . reverse) . lines
>     in map test
>       [ "show progress = " ++ show flag ~: do
>           handle <- openFile filename WriteMode
>           (counts', _) <- runTestText (putTextToHandle handle flag) suite
>           hClose handle
>           assertEqual "for the final counts," suiteCounts counts'
>           text <- readFile filename
>           let text' = if flag then trim (terminalAppearance text) else text
>           assertEqual "for the failure text output," suiteOutput text'
>       | flag <- [False, True] ]

>  ]


> showPathTests :: Test
> showPathTests = "showPath" ~: [

>   "empty"  ~: showPath [] ~?= "",
>   ":"      ~: showPath [Label ":", Label "::"] ~?= "\"::\":\":\"",
>   "\"\\\n" ~: showPath [Label "\"\\n\n\""] ~?= "\"\\\"\\\\n\\n\\\"\"",
>   "misc"   ~: showPath [Label "b", ListItem 2, ListItem 3, Label "foo"] ~?=
>                        "foo:3:2:b"

>  ]


> showCountsTests :: Test
> showCountsTests = "showCounts" ~: showCounts (Counts 4 3 2 1) ~?=
>                             "Cases: 4  Tried: 3  Errors: 2  Failures: 1"



> lift :: a -> IO a
> lift a = return a


> assertableTests :: Test
> assertableTests =
>   let assertables x = [
>         (       "", assert             x  , test             (lift x))  ,
>         (    "IO ", assert       (lift x) , test       (lift (lift x))) ,
>         ( "IO IO ", assert (lift (lift x)), test (lift (lift (lift x))))]
>       assertabled l e x =
>         test [ test [ "assert" ~: pre ++ l          ~: expect e $ test $ a,
>                       "test"   ~: pre ++ "IO " ++ l ~: expect e $ t ]
>                | (pre, a, t) <- assertables x ]
>   in "assertable" ~: [
>     assertabled "()"    Succ       (),
>     assertabled "True"  Succ       True,
>     assertabled "False" (Fail "")  False,
>     assertabled "\"\""  Succ       "",
>     assertabled "\"x\"" (Fail "x") "x"
>    ]


> predicableTests :: Test
> predicableTests =
>   let predicables x m = [
>         (       "", assertionPredicate      x  ,     x  @? m,     x  ~? m ),
>         (    "IO ", assertionPredicate   (l x) ,   l x  @? m,   l x  ~? m ),
>         ( "IO IO ", assertionPredicate (l(l x)), l(l x) @? m, l(l x) ~? m )]
>       l x = lift x
>       predicabled lab e m x =
>         test [ test [ "pred" ~: pre ++ lab ~: m ~: expect e $ test $ tst p,
>                       "(@?)" ~: pre ++ lab ~: m ~: expect e $ test $ a,
>                       "(~?)" ~: pre ++ lab ~: m ~: expect e $ t ]
>                                    | (pre, p, a, t) <- predicables x m ]
>        where tst p = p >>= assertBool m
>   in "predicable" ~: [
>     predicabled "True"  Succ           "error" True,
>     predicabled "False" (Fail "error") "error" False,
>     predicabled "True"  Succ           ""      True,
>     predicabled "False" (Fail ""     ) ""      False
>    ]


> compareTests :: Test
> compareTests = test [

>   let succ' = const Succ
>       compare1 :: (String -> Expect) -> Integer -> Integer -> Test
>       compare1 = compare'
>       compare2 :: (String -> Expect)
>                -> (Integer, Char, Double)
>                -> (Integer, Char, Double)
>                -> Test
>       compare2 = compare'
>       compare' f expected actual
>           = test [ "(@=?)" ~: expect e $ test (expected @=? actual),
>                    "(@?=)" ~: expect e $ test (actual   @?= expected),
>                    "(~=?)" ~: expect e $       expected ~=? actual,
>                    "(~?=)" ~: expect e $       actual   ~?= expected ]
>        where e = f $ "expected: " ++ show expected ++
>                      "\n but got: " ++ show actual
>   in test [
>     compare1 succ' 1 1,
>     compare1 Fail 1 2,
>     compare2 succ' (1,'b',3.0) (1,'b',3.0),
>     compare2 Fail (1,'b',3.0) (1,'b',3.1)
>    ]

>  ]


> expectList1 :: Int -> Test -> Test
> expectList1 c =
>   expectReports
>     [ Start (State [ListItem n] (Counts c n 0 0)) | n <- [0..c-1] ]
>                                 (Counts c c 0 0)

> expectList2 :: [Int] -> Test -> Test
> expectList2 cs t =
>   expectReports
>     [ Start (State [ListItem j, ListItem i] (Counts c n 0 0))
>         | ((i,j),n) <- zip coords [0..] ]
>                                             (Counts c c 0 0)
>                    t
>  where coords = [ (i,j) | i <- [0 .. length cs - 1], j <- [0 .. cs!!i - 1] ]
>        c = testCaseCount t


> extendedTestTests :: Test
> extendedTestTests = test [

>   "test idempotent" ~: expect Succ $ test $ test $ test $ ok,

>   "test list 1" ~: expectList1 3 $ test [assert (), assert "", assert True],

>   "test list 2" ~: expectList2 [0, 1, 2] $ test [[], [ok], [ok, ok]]

>  ]
