@echo off
:start
echo                     Press Corresponding Number and Press Enter
echo .
echo                           1. Create
echo                           2. Exit
set /P q=
if /I "%q%" EQU "1" goto :op
if /I "%q%" EQU "2" exit

:op
cls
cd %homepath%
cd desktop
chdir
echo                           What is the show's title?
set /P c=
md "%c%"
echo .
cd "%c%"
chdir
goto :displayoptions

:displayoptions
cls
echo                     Press Corresponding Number and Press Enter
echo                           1. Create Regular Season Folders
echo                           2. Create Specials Folder
echo                           3. Create Season 0 Folder
echo                           4. Create Individual season
echo                           5. Create Another Series
echo                           6. Exit
goto :options

:options
set /P e=
if /I "%e%" EQU "1" goto :RegularSeasonNumbers
if /I "%e%" EQU "2" goto :specials
if /I "%e%" EQU "3" goto :pilot
if /I "%e%" EQU "4" goto :individual
if /I "%e%" EQU "5" goto :start
if /I "%e%" EQU "6" exit
if /I "%e%" EQU "y" goto :displayoptions

:specials
md "Specials"
goto :success

:pilot
md "Season 0"
goto :success


:individual
echo                                   What Season?
set /P i=
md "Season %i%"
pause
goto :success

:success
echo                                   Task Complete
echo .
goto :didyouforget

:zero
echo                                   No Folder created
echo .
goto :didyouforget

:didyouforget
echo                   Press [y], then enter to display the Options again
echo .
goto :options

:RegularSeasonNumbers
echo                             How many seasons are there?
set /P d=
FOR /L %%A IN (1,1,%d%) DO md "Season %%A"
pause
goto :success
pause
goto :clearscreen
