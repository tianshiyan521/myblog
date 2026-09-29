@echo off
echo ============================
echo   Hexo Blog - Deploy
echo ============================
echo.
call node_modules\.bin\hexo.cmd clean >nul 2>&1
call node_modules\.bin\hexo.cmd generate >nul 2>&1
call node_modules\.bin\hexo.cmd deploy
echo.
echo Deploy done! Visit: https://tianshiyan521.github.io
echo.
pause
