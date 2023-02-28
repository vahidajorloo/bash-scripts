cd %WINDIR%\system32\inetsrv

appcmd.exe start site "Default Web Site"

cd C:\Users\Administrator\Desktop\1

net stop ConnectPro

wacs.exe --source iis --siteid 1 --id cancel --store pemfiles --pemfilespath . --accepttos --emailaddress info@tehranserver.ir >> log.txt

net start ConnectPro

ren *-chain.pem crt.pem

ren *-key.pem key.pem

move /Y crt.pem C:\Users\Administrator\Desktop

move /Y key.pem C:\Users\Administrator\Desktop

taskkill /IM "stunnel.exe" /F

net start stunnel

::cd C:\Program Files (x86)\stunnel\bin

::start /b stunnel.exe
