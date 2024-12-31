REM build all the assembly code "main" files in this directory
REM clean up before calling assembler 
del *.lst
del *.sym
del *.hex
del *.obj
del *.bin

tasm -version
set "base_filename=20by4BootLoader"

call zxasm %base_filename%
call python convertOBJToBIN.py ./%base_filename%.obj
call notepad.exe ./%base_filename%.txt