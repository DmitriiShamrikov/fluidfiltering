for %%I in (.) do set dirname=%%~nxI
cd ..
7z a -tzip %dirname%\%dirname%.zip %dirname%\code\* %dirname%\prototypes\* %dirname%\*.lua %dirname%\info.json %dirname%\LICENSE %dirname%\README.md %dirname%\thumbnail.png