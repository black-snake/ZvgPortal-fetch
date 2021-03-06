FROM mcr.microsoft.com/powershell:latest

COPY ZvgPortal-fetch /usr/local/share/powershell/Modules/ZvgPortal-fetch

WORKDIR /my-zvgs
COPY assets/CustomNotificationScript.ps1 /my-zvgs
VOLUME [ "/my-zvgs" ]

CMD [ "pwsh", "-c", \
    "Get-Zvgs", \
    "-State", "\"$env:ZvgState\"", \
    "-StateCountyCourt", "\"$env:ZvgStateCountyCourt\"", \
    "-Loop", \
    "-IntervalSeconds", "\"$env:LoopIntervalSeconds\"", \
    "-CustomNotificationScriptPath", "\"/my-zvgs/CustomNotificationScript.ps1\"" ]
