@echo off
echo ============================
echo   Hexo Blog - New Post
echo ============================
echo.
set /p TITLE=Enter post title: 
echo Creating: %TITLE%
call node_modules\.bin\hexo.cmd new "%TITLE%"
echo.
echo Done! File: source\_posts\%TITLE%.md
echo.
pause
