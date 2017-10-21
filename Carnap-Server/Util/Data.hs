module Util.Data where

import ClassyPrelude.Yesod
import Data.List ((!!), elemIndex)
import Data.Time
import qualified Data.Map as M (fromList)

data Instructor = GrahamLeachKrouse 
                | SalvatoreFlorio
                | CharlesPence
                | DavidSanson
    deriving (Show,Read,Eq,Enum,Bounded)

data InstructorMetadata = InstructorMetadata
    { instructorEmail :: Text }

instructorData :: Instructor -> InstructorMetadata
instructorData GrahamLeachKrouse = InstructorMetadata
        { instructorEmail = "gleachkr@gmail.com" }
instructorData SalvatoreFlorio = InstructorMetadata
        { instructorEmail = "florio.2@buckeyemail.osu.edu" }
instructorData CharlesPence = InstructorMetadata
        { instructorEmail = "charles@charlespence.net" }
instructorData DavidSanson = InstructorMetadata
        { instructorEmail = "dsanson@gmail.com" }

instructorsList :: [Instructor]
instructorsList = [minBound .. maxBound]

instructorsDataList :: [InstructorMetadata]
instructorsDataList = map instructorData instructorsList

instructorByEmail :: Text -> Maybe Instructor
instructorByEmail t = (!!) <$> pure instructorsList <*> elemIndex t (map instructorEmail instructorsDataList)

data CourseEnrollment = Birmingham2017 
                      | KSUSymbolicI2017
                      | KSUIntroToFormal2017
                      | KSUModalLogic2017
                      | SandboxCourse Instructor
      deriving (Show,Read,Eq)
derivePersistField "CourseEnrollment"

data CourseMetadata = CourseMetadata 
                    { pointsOf :: Int
                    , sourceOf :: Maybe ProblemSource
                    , instructorOf :: Instructor
                    , nameOf :: Text
                    , duedates :: Maybe (Map Int UTCTime)
                    }

blankCourse instructor name = CourseMetadata
        { pointsOf = 0
        , sourceOf = Nothing
        , instructorOf = instructor
        , nameOf = name
        , duedates = Nothing
        }

courseData :: CourseEnrollment -> CourseMetadata
courseData Birmingham2017 = blankCourse SalvatoreFlorio "Logic - University of Birmingham"
courseData KSUSymbolicI2017 = (blankCourse GrahamLeachKrouse "Symbolic Logic I - PHILO320 - Kansas State University")
    { sourceOf = Just CarnapTextbook
    , pointsOf = 425
    , duedates = Just $ M.fromList
        [ ( 1, toTime "11:59 pm CDT, Aug 30, 2017")
        , ( 2, toTime "11:59 pm CDT, Sep 1, 2017")
        , ( 3, toTime "11:59 pm CDT, Sep 8, 2017")
        , ( 4, toTime "11:59 pm CDT, Sep 13, 2017")
        , ( 5, toTime "11:59 pm CDT, Sep 15, 2017")
        , ( 6, toTime "11:59 pm CDT, Sep 20, 2017")
        , ( 7, toTime "11:59 pm CDT, Sep 25, 2017")
        , ( 8, toTime "11:59 pm CDT, Oct 6, 2017")
        , ( 9, toTime "11:59 pm CDT, Oct 13, 2017")
        ]
    }
courseData KSUIntroToFormal2017 = (blankCourse GrahamLeachKrouse "Introduction to Formal Logic - PHILO110 - Kansas State University")
    { sourceOf = Just CarnapTextbook
    , pointsOf = 375
    , duedates = Just $ M.fromList
        [ ( 1, toTime "11:59 pm CDT, Aug 30, 2017")
        , ( 2, toTime "11:59 pm CDT, Sep 6, 2017")
        , ( 3, toTime "11:59 pm CDT, Sep 11, 2017")
        , ( 4, toTime "11:59 pm CDT, Sep 15, 2017")
        , ( 5, toTime "11:59 pm CDT, Sep 20, 2017")
        , ( 6, toTime "11:59 pm CDT, Oct 6, 2017")
        , ( 7, toTime "11:59 pm CDT, Oct 13, 2017")
        , ( 8, toTime "11:59 pm CDT, Oct 24, 2017")
        ]
    }
courseData KSUModalLogic2017 = (blankCourse GrahamLeachKrouse "Modal Logic (independent study) - Kansas State University")
    { pointsOf = 150
    }
courseData (SandboxCourse i) = blankCourse i "Sandbox Course"

--TODO use an enum to generate these
regularCourseList :: [CourseEnrollment]
regularCourseList = [Birmingham2017,KSUSymbolicI2017,KSUIntroToFormal2017,KSUModalLogic2017]

courseList :: [CourseEnrollment]
courseList = [Birmingham2017,KSUSymbolicI2017,KSUIntroToFormal2017,KSUModalLogic2017] ++ map SandboxCourse instructorsList

coursesByInstructor :: Instructor -> [CourseEnrollment]
coursesByInstructor i = filter (\c -> instructorOf (courseData c) == i) courseList

toTime :: String -> UTCTime
toTime = parseTimeOrError True defaultTimeLocale "%l:%M %P %Z, %b %e, %Y"

data ProblemSource = CarnapTextbook 
                   | CourseAssignment CourseEnrollment
      deriving (Show,Read,Eq)
derivePersistField "ProblemSource"
