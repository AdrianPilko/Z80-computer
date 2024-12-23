REM build all the assembly code "main" files in this directory
REM clean up before calling assembler 
del *.lst
del *.sym
del *.hex
del *.obj

set "base_filename=20by4Display"

call zxasm %base_filename%
call python convertOBJToBIN.py ./20by4Display.obj
