param (
    [Parameter(Mandatory = $true)]
    [object] $InputObject
)

$MailParams = @{
    From       = $env:FromMailAddr
    To         = $env:ToMailAddr
    SmtpServer = $env:SmtpServer
    Port       = $env:SmtpPort
    UseSsl     = [bool]::Parse($env:SmtpSecure)
    Credential = [System.Management.Automation.PSCredential]::new(
        $env:SmtpUser,
        (ConvertTo-SecureString -String $env:SmtpPassword -AsPlainText -Force)
    )

    Subject    = $env:MailSubj
    Body       = $InputObject.Uri | Out-String

    Encoding   = [System.Text.UTF8Encoding]::new($false)
}

Send-MailMessage @MailParams -ErrorAction Continue