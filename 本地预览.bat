@echo off
echo ============================
echo   Blog Preview + Admin Panel
echo ============================
echo.
echo   Blog:  http://localhost:4000
echo   Admin: http://localhost:4000/admin
echo.
echo   Press Ctrl+C to stop
echo.
start http://localhost:4000/admin
call node_modules\.bin\hexo.cmd server
pause
