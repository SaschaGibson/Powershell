[CmdletBinding(DefaultParameterSetName = 'LiteralKeys')]
param (
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ParameterSetName='LiteralKeys')]
    [string[]] $ProductKey,
    [Parameter(Mandatory=$true, ValueFromPipeline=$true, ParameterSetName='KeyFile')]
    [string] $KeyFile,
    [switch] $SimpleOutput
)

$source = @"
using System;
using System.Text;
using System.Runtime.InteropServices;

public static class PidChecker
{
    // Quelle: https://github.com/chughes-3/UpdateProductKey/blob/master/UpdateProductKeys/PidChecker.cs
    
    [DllImport("pidgenx.dll", EntryPoint = "PidGenX", CharSet = CharSet.Auto)]
    static extern int PidGenX(string ProductKey, string PkeyPath, string MSPID, int UnknownUsage, IntPtr ProductID, IntPtr DigitalProductID, IntPtr DigitalProductID4);

    public static string CheckProductKey(string productKey, out string skuId)
    {
        string result = "";
        skuId = "";
        int RetID;
        byte[] gpid = new byte[0x32];
        byte[] opid = new byte[0xA4];
        byte[] npid = new byte[0x04F8];

        IntPtr PID = Marshal.AllocHGlobal(0x32);
        IntPtr DPID = Marshal.AllocHGlobal(0xA4);
        IntPtr DPID4 = Marshal.AllocHGlobal(0x04F8);

        string PKeyPath = Environment.SystemDirectory + @"\spp\tokens\pkeyconfig\pkeyconfig.xrm-ms";
        string MSPID = "00000";

        gpid[0] = 0x32;
        opid[0] = 0xA4;
        npid[0] = 0xF8;
        npid[1] = 0x04;

        Marshal.Copy(gpid, 0, PID, 0x32);
        Marshal.Copy(opid, 0, DPID, 0xA4);
        Marshal.Copy(npid, 0, DPID4, 0x04F8);

        RetID = PidGenX(productKey, PKeyPath, MSPID, 0, PID, DPID, DPID4);

        if (RetID == 0)
        {
            Marshal.Copy(PID, gpid, 0, gpid.Length);
            Marshal.Copy(DPID, opid, 0, opid.Length);
            Marshal.Copy(DPID4, npid, 0, npid.Length);
            skuId = "{" + GetString(npid, 0x0088, Encoding.Unicode) + "}";
            result = "Valid";
        }
        else if (RetID == -2147024809)
        {
            result = "PidChecker: Invalid Arguments";
        }
        else if (RetID == -1979645695)
        {
            result = "PidChecker: Not a Windows 7 Product Key";
        }
        else if (RetID == -2147024894)
        {
            result = "PidChecker: pkeyconfig.xrm.ms file is not found";
        }
        else
        {
            result = string.Format("PidChecker: Invalid input! ({0} ≙ 0x{0:x})", RetID);
        }
        Marshal.FreeHGlobal(PID);
        Marshal.FreeHGlobal(DPID);
        Marshal.FreeHGlobal(DPID4);
        //FreeLibrary(dllHandle);
        return result;
    }
    static string GetString(byte[] bytes, int index, Encoding enc)
    {
        int n = index;
        while (!(bytes[n] == 0 && bytes[n + 1] == 0)) n++;
        return enc.GetString(bytes, index, n - index + 1);
    }
}
"@
Add-Type -TypeDefinition $source

$result = @{}
$PKeyPath = [Environment]::SystemDirectory + '\spp\tokens\pkeyconfig\pkeyconfig.xrm-ms'
$Namespace = @{tm = "http://www.microsoft.com/DRM/XrML2/TM/v2"}
$XPath = "//tm:infoBin[@name='pkeyConfigData']"
$configDataBase64 = Select-Xml -Path $PKeyPath -Namespace $Namespace -XPath $XPath | Select-Object -ExpandProperty Node
if(-not $configDataBase64) {
    Write-Host "Datei pkeyconfig.xrm-ms nicht gefunden oder unerwarteter Inhalt."
    return
}
$configDataXml = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($configDataBase64.InnerText))

if($KeyFile) {
    Write-Verbose "Lese $KeyFile ..."
    $ProductKey = @()
    Get-Content $KeyFile | ForEach-Object {
        if($_ -match '([A-Z0-9]{5}-){4}[A-Z0-9]{5}') {
            Write-Verbose ("Schlüssel gefunden: {0}" -f $Matches[0])
            $ProductKey += $Matches[0]
        }
    }
}

foreach($Key in $ProductKey) {
    if($result[$Key]) {
        Write-Verbose "Überspringe ${Key}: Schon bekannt."
        continue
    }
    Write-Verbose "Verarbeite $Key ..."
    $Product = [PSCustomObject]@{
        Key = $Key
    }
    $ConfigId = ""
    $IsValid = [PidChecker]::CheckProductKey($Key, [ref]$ConfigId)
    if($IsValid -ne "Valid") {
        $Product | Add-Member -MemberType NoteProperty -Name 'Error' -Value $IsValid
    }
    else {
        $Namespace = @{ns = "http://www.microsoft.com/DRM/PKEY/Configuration/2.0"}
        $XPath = "//ns:Configuration[ns:ActConfigId='{0}']" -f $ConfigId
        $Configuration = Select-Xml -Content $configDataXml -Namespace $Namespace -XPath $XPath
        if(-not $Configuration) {
            $Product | Add-Member -MemberType NoteProperty -Name 'Error' -Value "Unbekannter Produktschlüssel"
        }
        else {
            $Product | Add-Member -MemberType NoteProperty -Name 'Product' -Value $Configuration.Node.ProductDescription
            $Product | Add-Member -MemberType NoteProperty -Name 'Edition' -Value $Configuration.Node.EditionId
            $Product | Add-Member -MemberType NoteProperty -Name 'KeyType' -Value $Configuration.Node.ProductKeyType
        }
    }
    $result[$Key] = $Product
}
if($SimpleOutput) {
  $out = ""
  foreach($r in $result.GetEnumerator())
  {
    if($out -ne "") {
      $out += "`r`n"
    }
    if($result.Count -ne 1) {
      $out += "$($r.Name): "
    }
    if($r.Value.Error) {
      $out += "Produkt unbekannt"
    }
    else {
      $out += $r.Value.Product
    }
  }
  return $out
}
else {
  return $result.Values # | Sort-Object Key
}

# SIG # Begin signature block
# MIImxgYJKoZIhvcNAQcCoIImtzCCJrMCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUWtKxkAX5tFiVubVKwoRKK/JJ
# gLyggh/XMIIFbzCCBFegAwIBAgIQSPyTtGBVlI02p8mKidaUFjANBgkqhkiG9w0B
# AQwFADB7MQswCQYDVQQGEwJHQjEbMBkGA1UECAwSR3JlYXRlciBNYW5jaGVzdGVy
# MRAwDgYDVQQHDAdTYWxmb3JkMRowGAYDVQQKDBFDb21vZG8gQ0EgTGltaXRlZDEh
# MB8GA1UEAwwYQUFBIENlcnRpZmljYXRlIFNlcnZpY2VzMB4XDTIxMDUyNTAwMDAw
# MFoXDTI4MTIzMTIzNTk1OVowVjELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3Rp
# Z28gTGltaXRlZDEtMCsGA1UEAxMkU2VjdGlnbyBQdWJsaWMgQ29kZSBTaWduaW5n
# IFJvb3QgUjQ2MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAjeeUEiIE
# JHQu/xYjApKKtq42haxH1CORKz7cfeIxoFFvrISR41KKteKW3tCHYySJiv/vEpM7
# fbu2ir29BX8nm2tl06UMabG8STma8W1uquSggyfamg0rUOlLW7O4ZDakfko9qXGr
# YbNzszwLDO/bM1flvjQ345cbXf0fEj2CA3bm+z9m0pQxafptszSswXp43JJQ8mTH
# qi0Eq8Nq6uAvp6fcbtfo/9ohq0C/ue4NnsbZnpnvxt4fqQx2sycgoda6/YDnAdLv
# 64IplXCN/7sVz/7RDzaiLk8ykHRGa0c1E3cFM09jLrgt4b9lpwRrGNhx+swI8m2J
# mRCxrds+LOSqGLDGBwF1Z95t6WNjHjZ/aYm+qkU+blpfj6Fby50whjDoA7NAxg0P
# OM1nqFOI+rgwZfpvx+cdsYN0aT6sxGg7seZnM5q2COCABUhA7vaCZEao9XOwBpXy
# bGWfv1VbHJxXGsd4RnxwqpQbghesh+m2yQ6BHEDWFhcp/FycGCvqRfXvvdVnTyhe
# Be6QTHrnxvTQ/PrNPjJGEyA2igTqt6oHRpwNkzoJZplYXCmjuQymMDg80EY2NXyc
# uu7D1fkKdvp+BRtAypI16dV60bV/AK6pkKrFfwGcELEW/MxuGNxvYv6mUKe4e7id
# FT/+IAx1yCJaE5UZkADpGtXChvHjjuxf9OUCAwEAAaOCARIwggEOMB8GA1UdIwQY
# MBaAFKARCiM+lvEH7OKvKe+CpX/QMKS0MB0GA1UdDgQWBBQy65Ka/zWWSC8oQEJw
# IDaRXBeF5jAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zATBgNVHSUE
# DDAKBggrBgEFBQcDAzAbBgNVHSAEFDASMAYGBFUdIAAwCAYGZ4EMAQQBMEMGA1Ud
# HwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwuY29tb2RvY2EuY29tL0FBQUNlcnRpZmlj
# YXRlU2VydmljZXMuY3JsMDQGCCsGAQUFBwEBBCgwJjAkBggrBgEFBQcwAYYYaHR0
# cDovL29jc3AuY29tb2RvY2EuY29tMA0GCSqGSIb3DQEBDAUAA4IBAQASv6Hvi3Sa
# mES4aUa1qyQKDKSKZ7g6gb9Fin1SB6iNH04hhTmja14tIIa/ELiueTtTzbT72ES+
# BtlcY2fUQBaHRIZyKtYyFfUSg8L54V0RQGf2QidyxSPiAjgaTCDi2wH3zUZPJqJ8
# ZsBRNraJAlTH/Fj7bADu/pimLpWhDFMpH2/YGaZPnvesCepdgsaLr4CnvYFIUoQx
# 2jLsFeSmTD1sOXPUC4U5IOCFGmjhp0g4qdE2JXfBjRkWxYhMZn0vY86Y6GnfrDyo
# XZ3JHFuu2PMvdM+4fvbXg50RlmKarkUT2n/cR/vfw1Kf5gZV6Z2M8jpiUbzsJA8p
# 1FiAhORFe1rYMIIGGjCCBAKgAwIBAgIQYh1tDFIBnjuQeRUgiSEcCjANBgkqhkiG
# 9w0BAQwFADBWMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVk
# MS0wKwYDVQQDEyRTZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgUm9vdCBSNDYw
# HhcNMjEwMzIyMDAwMDAwWhcNMzYwMzIxMjM1OTU5WjBUMQswCQYDVQQGEwJHQjEY
# MBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSswKQYDVQQDEyJTZWN0aWdvIFB1Ymxp
# YyBDb2RlIFNpZ25pbmcgQ0EgUjM2MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIB
# igKCAYEAmyudU/o1P45gBkNqwM/1f/bIU1MYyM7TbH78WAeVF3llMwsRHgBGRmxD
# eEDIArCS2VCoVk4Y/8j6stIkmYV5Gej4NgNjVQ4BYoDjGMwdjioXan1hlaGFt4Wk
# 9vT0k2oWJMJjL9G//N523hAm4jF4UjrW2pvv9+hdPX8tbbAfI3v0VdJiJPFy/7Xw
# iunD7mBxNtecM6ytIdUlh08T2z7mJEXZD9OWcJkZk5wDuf2q52PN43jc4T9OkoXZ
# 0arWZVeffvMr/iiIROSCzKoDmWABDRzV/UiQ5vqsaeFaqQdzFf4ed8peNWh1OaZX
# nYvZQgWx/SXiJDRSAolRzZEZquE6cbcH747FHncs/Kzcn0Ccv2jrOW+LPmnOyB+t
# AfiWu01TPhCr9VrkxsHC5qFNxaThTG5j4/Kc+ODD2dX/fmBECELcvzUHf9shoFvr
# n35XGf2RPaNTO2uSZ6n9otv7jElspkfK9qEATHZcodp+R4q2OIypxR//YEb3fkDn
# 3UayWW9bAgMBAAGjggFkMIIBYDAfBgNVHSMEGDAWgBQy65Ka/zWWSC8oQEJwIDaR
# XBeF5jAdBgNVHQ4EFgQUDyrLIIcouOxvSK4rVKYpqhekzQwwDgYDVR0PAQH/BAQD
# AgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAwEwYDVR0lBAwwCgYIKwYBBQUHAwMwGwYD
# VR0gBBQwEjAGBgRVHSAAMAgGBmeBDAEEATBLBgNVHR8ERDBCMECgPqA8hjpodHRw
# Oi8vY3JsLnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2RlU2lnbmluZ1Jvb3RS
# NDYuY3JsMHsGCCsGAQUFBwEBBG8wbTBGBggrBgEFBQcwAoY6aHR0cDovL2NydC5z
# ZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljQ29kZVNpZ25pbmdSb290UjQ2LnA3YzAj
# BggrBgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5jb20wDQYJKoZIhvcNAQEM
# BQADggIBAAb/guF3YzZue6EVIJsT/wT+mHVEYcNWlXHRkT+FoetAQLHI1uBy/YXK
# ZDk8+Y1LoNqHrp22AKMGxQtgCivnDHFyAQ9GXTmlk7MjcgQbDCx6mn7yIawsppWk
# vfPkKaAQsiqaT9DnMWBHVNIabGqgQSGTrQWo43MOfsPynhbz2Hyxf5XWKZpRvr3d
# MapandPfYgoZ8iDL2OR3sYztgJrbG6VZ9DoTXFm1g0Rf97Aaen1l4c+w3DC+IkwF
# kvjFV3jS49ZSc4lShKK6BrPTJYs4NG1DGzmpToTnwoqZ8fAmi2XlZnuchC4NPSZa
# PATHvNIzt+z1PHo35D/f7j2pO1S8BCysQDHCbM5Mnomnq5aYcKCsdbh0czchOm8b
# kinLrYrKpii+Tk7pwL7TjRKLXkomm5D1Umds++pip8wH2cQpf93at3VDcOK4N7Ew
# oIJB0kak6pSzEu4I64U6gZs7tS/dGNSljf2OSSnRr7KWzq03zl8l75jy+hOds9TW
# SenLbjBQUGR96cFr6lEUfAIEHVC1L68Y1GGxx4/eRI82ut83axHMViw1+sVpbPxg
# 51Tbnio1lB93079WPFnYaOvfGAA0e0zcfF/M9gXr+korwQTh2Prqooq2bYNMvUoU
# KD85gnJ+t0smrWrb8dee2CvYZXD5laGtaAxOfy/VKNmwuWuAh9kcMIIGWDCCBMCg
# AwIBAgIQJ9duLUO9FDxmyM5o3NajBDANBgkqhkiG9w0BAQwFADBUMQswCQYDVQQG
# EwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSswKQYDVQQDEyJTZWN0aWdv
# IFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2MB4XDTIyMTIwNjAwMDAwMFoXDTI0
# MDEwODIzNTk1OVowbzELMAkGA1UEBhMCREUxFjAUBgNVBAgMDU5pZWRlcnNhY2hz
# ZW4xIzAhBgNVBAoMGkhlaXNlIE1lZGllbiBHbWJIICYgQ28uIEtHMSMwIQYDVQQD
# DBpIZWlzZSBNZWRpZW4gR21iSCAmIENvLiBLRzCCAiIwDQYJKoZIhvcNAQEBBQAD
# ggIPADCCAgoCggIBAJb++5FeuAjKhFSXbwoAxxmkmBMjLocELgkOP0E4mNmy1tyP
# cqAYE2Jspg3X+KE/X4swbnCU8wBI3MX0RkjTM06kDb9YetDnLHMSzk0BhnrUf7um
# FfmyuowlEhWrrGQGwiL/kYGo0z5vi0+2Xro7Dc9Yd6TPOxCXhOAQF+ltcCk47Zza
# y1GsW63G8cBowQLYuBAn5tiNj4Y9qT0iJ40GSNEFWUg3SCl9Bmy1/ANpVepT4/aV
# Vd0r6WP71jSiQltAHQ51QV1tsolgBBbnfwBfEfMKBvyvXG+46WszJ9fywVj9pkLA
# IwUU+e03ix5+xQ5icMAjvNi9ZNNr0gj2NShXf2k//oOUdqgkFvmXKdlWISbqLBXl
# h8K5LU9BgrK3GiELPj6P4T5y00p6TfnsCica2mP0JeuUR+GD8dtnus1F481vNLdV
# 0kBPIpPdFR5/W7o2E9gEzvLjc3UlR+lMiZ39a5plv1ne55IkvpHpWdJLEoi0O8Hz
# HUn0wvGaOYOU2XaJLyy5Lcl4FXDuW3s4SNBgB482+CyxlXA+TNCNxOplNwok73iq
# Z/Lt/IIwwfWVGWbdOf9HXh07EfRvMMaot66uUKfp3s+ffPI53lUDq0g8+fdQFC+A
# uUtfHyE5jFKL7TW0teZOovUtC5nBJB6kcfMl/SzcLsv+rjhH+tDgC3mADC6fAgMB
# AAGjggGJMIIBhTAfBgNVHSMEGDAWgBQPKssghyi47G9IritUpimqF6TNDDAdBgNV
# HQ4EFgQURR6a6AkwL9LB7PPGFHi0Fds7NkswDgYDVR0PAQH/BAQDAgeAMAwGA1Ud
# EwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUHAwMwSgYDVR0gBEMwQTA1BgwrBgEE
# AbIxAQIBAwIwJTAjBggrBgEFBQcCARYXaHR0cHM6Ly9zZWN0aWdvLmNvbS9DUFMw
# CAYGZ4EMAQQBMEkGA1UdHwRCMEAwPqA8oDqGOGh0dHA6Ly9jcmwuc2VjdGlnby5j
# b20vU2VjdGlnb1B1YmxpY0NvZGVTaWduaW5nQ0FSMzYuY3JsMHkGCCsGAQUFBwEB
# BG0wazBEBggrBgEFBQcwAoY4aHR0cDovL2NydC5zZWN0aWdvLmNvbS9TZWN0aWdv
# UHVibGljQ29kZVNpZ25pbmdDQVIzNi5jcnQwIwYIKwYBBQUHMAGGF2h0dHA6Ly9v
# Y3NwLnNlY3RpZ28uY29tMA0GCSqGSIb3DQEBDAUAA4IBgQAtQeD4SqSJdR4OsP2w
# ybXWKyEV/0pG9ruAOBR60MKpR3u+jCM0P/dzO1tU1dcyozlIGgMHdPqzECJzOQmO
# cCb32Rpm+pV0vDmmcn34x10bzGMoCqcgqdoKBk2sC9wJTsM4nzKwSTFyXGUlmo1T
# sVNXmDogyT2hXDuLZe6MNFoQ3MuevUyrT8srUixtCTh4eQKNwO7AMtQ/RrococTi
# EsxJkrhiU1AiEObKnhrc2GCF4nN/pir9iUR8h7NfS+JuGh4v3+0E7aUzo4kNz0GW
# eLou03eRhUj1c6zkfePZxCN3NVq+WuBF2zZmT36w2PhxDGCxYaYxWVWikzdWdK8P
# kIzU4OGx9976l7Ehw9MfTW7ZLiylBQvCKMgcdcDXt6QzltGzyrk0mCbkcOZ9xUDw
# y+6kWNTev3cvjzCL8rYHM1RNdb10/bjO9pIGsyFXPmMU/XKbu0oUWJgxam4wHzuP
# GXMjAhUAXADXYV38dvavSmWgGrkrv8PvSUStS5rQft16JFkwggbsMIIE1KADAgEC
# AhAwD2+s3WaYdHypRjaneC25MA0GCSqGSIb3DQEBDAUAMIGIMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKTmV3IEplcnNleTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAc
# BgNVBAoTFVRoZSBVU0VSVFJVU1QgTmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0
# IFJTQSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTAeFw0xOTA1MDIwMDAwMDBaFw0z
# ODAxMTgyMzU5NTlaMH0xCzAJBgNVBAYTAkdCMRswGQYDVQQIExJHcmVhdGVyIE1h
# bmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGDAWBgNVBAoTD1NlY3RpZ28gTGlt
# aXRlZDElMCMGA1UEAxMcU2VjdGlnbyBSU0EgVGltZSBTdGFtcGluZyBDQTCCAiIw
# DQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMgbAa/ZLH6ImX0BmD8gkL2cgCFU
# k7nPoD5T77NawHbWGgSlzkeDtevEzEk0y/NFZbn5p2QWJgn71TJSeS7JY8ITm7aG
# PwEFkmZvIavVcRB5h/RGKs3EWsnb111JTXJWD9zJ41OYOioe/M5YSdO/8zm7uaQj
# QqzQFcN/nqJc1zjxFrJw06PE37PFcqwuCnf8DZRSt/wflXMkPQEovA8NT7ORAY5u
# nSd1VdEXOzQhe5cBlK9/gM/REQpXhMl/VuC9RpyCvpSdv7QgsGB+uE31DT/b0OqF
# jIpWcdEtlEzIjDzTFKKcvSb/01Mgx2Bpm1gKVPQF5/0xrPnIhRfHuCkZpCkvRuPd
# 25Ffnz82Pg4wZytGtzWvlr7aTGDMqLufDRTUGMQwmHSCIc9iVrUhcxIe/arKCFiH
# d6QV6xlV/9A5VC0m7kUaOm/N14Tw1/AoxU9kgwLU++Le8bwCKPRt2ieKBtKWh97o
# aw7wW33pdmmTIBxKlyx3GSuTlZicl57rjsF4VsZEJd8GEpoGLZ8DXv2DolNnyrH6
# jaFkyYiSWcuoRsDJ8qb/fVfbEnb6ikEk1Bv8cqUUotStQxykSYtBORQDHin6G6Ui
# rqXDTYLQjdprt9v3GEBXc/Bxo/tKfUU2wfeNgvq5yQ1TgH36tjlYMu9vGFCJ10+d
# M70atZ2h3pVBeqeDAgMBAAGjggFaMIIBVjAfBgNVHSMEGDAWgBRTeb9aqitKz1SA
# 4dibwJ3ysgNmyzAdBgNVHQ4EFgQUGqH4YRkgD8NBd0UojtE1XwYSBFUwDgYDVR0P
# AQH/BAQDAgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAwEwYDVR0lBAwwCgYIKwYBBQUH
# AwgwEQYDVR0gBAowCDAGBgRVHSAAMFAGA1UdHwRJMEcwRaBDoEGGP2h0dHA6Ly9j
# cmwudXNlcnRydXN0LmNvbS9VU0VSVHJ1c3RSU0FDZXJ0aWZpY2F0aW9uQXV0aG9y
# aXR5LmNybDB2BggrBgEFBQcBAQRqMGgwPwYIKwYBBQUHMAKGM2h0dHA6Ly9jcnQu
# dXNlcnRydXN0LmNvbS9VU0VSVHJ1c3RSU0FBZGRUcnVzdENBLmNydDAlBggrBgEF
# BQcwAYYZaHR0cDovL29jc3AudXNlcnRydXN0LmNvbTANBgkqhkiG9w0BAQwFAAOC
# AgEAbVSBpTNdFuG1U4GRdd8DejILLSWEEbKw2yp9KgX1vDsn9FqguUlZkClsYcu1
# UNviffmfAO9Aw63T4uRW+VhBz/FC5RB9/7B0H4/GXAn5M17qoBwmWFzztBEP1dXD
# 4rzVWHi/SHbhRGdtj7BDEA+N5Pk4Yr8TAcWFo0zFzLJTMJWk1vSWVgi4zVx/AZa+
# clJqO0I3fBZ4OZOTlJux3LJtQW1nzclvkD1/RXLBGyPWwlWEZuSzxWYG9vPWS16t
# oytCiiGS/qhvWiVwYoFzY16gu9jc10rTPa+DBjgSHSSHLeT8AtY+dwS8BDa153fL
# nC6NIxi5o8JHHfBd1qFzVwVomqfJN2Udvuq82EKDQwWli6YJ/9GhlKZOqj0J9QVs
# t9JkWtgqIsJLnfE5XkzeSD2bNJaaCV+O/fexUpHOP4n2HKG1qXUfcb9bQ11lPVCB
# bqvw0NP8srMftpmWJvQ8eYtcZMzN7iea5aDADHKHwW5NWtMe6vBE5jJvHOsXTpTD
# eGUgOw9Bqh/poUGd/rG4oGUqNODeqPk85sEwu8CgYyz8XBYAqNDEf+oRnR4GxqZt
# Ml20OAkrSQeq/eww2vGnL8+3/frQo4TZJ577AWZ3uVYQ4SBuxq6x+ba6yDVdM3aO
# 8XwgDCp3rrWiAoa6Ke60WgCxjKvj+QrJVF3UuWp0nr1Irpgwggb2MIIE3qADAgEC
# AhEAkDl/mtJKOhPyvZFfCDipQzANBgkqhkiG9w0BAQwFADB9MQswCQYDVQQGEwJH
# QjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3Jk
# MRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxJTAjBgNVBAMTHFNlY3RpZ28gUlNB
# IFRpbWUgU3RhbXBpbmcgQ0EwHhcNMjIwNTExMDAwMDAwWhcNMzMwODEwMjM1OTU5
# WjBqMQswCQYDVQQGEwJHQjETMBEGA1UECBMKTWFuY2hlc3RlcjEYMBYGA1UEChMP
# U2VjdGlnbyBMaW1pdGVkMSwwKgYDVQQDDCNTZWN0aWdvIFJTQSBUaW1lIFN0YW1w
# aW5nIFNpZ25lciAjMzCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAJCy
# cT954dS5ihfMw5fCkJRy7Vo6bwFDf3NaKJ8kfKA1QAb6lK8KoYO2E+RLFQZeaoog
# NHF7uyWtP1sKpB8vbH0uYVHQjFk3PqZd8R5dgLbYH2DjzRJqiB/G/hjLk0NWesfO
# A9YAZChWIrFLGdLwlslEHzldnLCW7VpJjX5y5ENrf8mgP2xKrdUAT70KuIPFvZgs
# B3YBcEXew/BCaer/JswDRB8WKOFqdLacRfq2Os6U0R+9jGWq/fzDPOgNnDhm1fx9
# HptZjJFaQldVUBYNS3Ry7qAqMfwmAjT5ZBtZ/eM61Oi4QSl0AT8N4BN3KxE8+z3N
# 0Ofhl1tV9yoDbdXNYtrOnB786nB95n1LaM5aKWHToFwls6UnaKNY/fUta8pfZMdr
# KAzarHhB3pLvD8Xsq98tbxpUUWwzs41ZYOff6Bcio3lBYs/8e/OS2q7gPE8PWsxu
# 3x+8Iq+3OBCaNKcL//4dXqTz7hY4Kz+sdpRBnWQd+oD9AOH++DrUw167aU1ymeXx
# Mi1R+mGtTeomjm38qUiYPvJGDWmxt270BdtBBcYYwFDk+K3+rGNhR5G8RrVGU2zF
# 9OGGJ5OEOWx14B0MelmLLsv0ZCxCR/RUWIU35cdpp9Ili5a/xq3gvbE39x/fQnuq
# 6xzp6z1a3fjSkNVJmjodgxpXfxwBws4cfcz7lhXFAgMBAAGjggGCMIIBfjAfBgNV
# HSMEGDAWgBQaofhhGSAPw0F3RSiO0TVfBhIEVTAdBgNVHQ4EFgQUJS5oPGuaKyQU
# qR+i3yY6zxSm8eAwDgYDVR0PAQH/BAQDAgbAMAwGA1UdEwEB/wQCMAAwFgYDVR0l
# AQH/BAwwCgYIKwYBBQUHAwgwSgYDVR0gBEMwQTA1BgwrBgEEAbIxAQIBAwgwJTAj
# BggrBgEFBQcCARYXaHR0cHM6Ly9zZWN0aWdvLmNvbS9DUFMwCAYGZ4EMAQQCMEQG
# A1UdHwQ9MDswOaA3oDWGM2h0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1JT
# QVRpbWVTdGFtcGluZ0NBLmNybDB0BggrBgEFBQcBAQRoMGYwPwYIKwYBBQUHMAKG
# M2h0dHA6Ly9jcnQuc2VjdGlnby5jb20vU2VjdGlnb1JTQVRpbWVTdGFtcGluZ0NB
# LmNydDAjBggrBgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5jb20wDQYJKoZI
# hvcNAQEMBQADggIBAHPa7Whyy8K5QKExu7QDoy0UeyTntFsVfajp/a3Rkg18PTag
# adnzmjDarGnWdFckP34PPNn1w3klbCbojWiTzvF3iTl/qAQF2jTDFOqfCFSr/8R+
# lmwr05TrtGzgRU0ssvc7O1q1wfvXiXVtmHJy9vcHKPPTstDrGb4VLHjvzUWgAOT4
# BHa7V8WQvndUkHSeC09NxKoTj5evATUry5sReOny+YkEPE7jghJi67REDHVBwg80
# uIidyCLxE2rbGC9ueK3EBbTohAiTB/l9g/5omDTkd+WxzoyUbNsDbSgFR36bLvBk
# +9ukAzEQfBr7PBmA0QtwuVVfR745ZM632iNUMuNGsjLY0imGyRVdgJWvAvu00S6d
# OHw14A8c7RtHSJwialWC2fK6CGUD5fEp80iKCQFMpnnyorYamZTrlyjhvn0boXzt
# VoCm9CIzkOSEU/wq+sCnl6jqtY16zuTgS6Ezqwt2oNVpFreOZr9f+h/EqH+noUgU
# kQ2C/L1Nme3J5mw2/ndDmbhpLXxhL+2jsEn+W75pJJH/k/xXaZJL2QU/bYZy06LQ
# wGTSOkLBGgP70O2aIbg/r6ayUVTVTMXKHxKNV8Y57Vz/7J8mdq1kZmfoqjDg0q23
# fbFqQSduA4qjdOCKCYJuv+P2t7yeCykYaIGhnD9uFllLFAkJmuauv2AV3Yb1MYIG
# WTCCBlUCAQEwaDBUMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1p
# dGVkMSswKQYDVQQDEyJTZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2
# AhAn124tQ70UPGbIzmjc1qMEMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQow
# CKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcC
# AQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBRYuHYX0/Psx3DVYlbr
# NEghmE7f1TANBgkqhkiG9w0BAQEFAASCAgBKzSvvyJRd+hesdPhVVnwQ/KdNkmEi
# ecxtqiiPF83A+ld1iq/7M8qqClceal+frAqt+sL06jZhIYhsz1M6uC3fABvPGWhj
# fnoLOEsBX5U8myJ9+dfQYnFN+q0lD6m80R+8iuj8daxc4HI/3TXJzFCgh9v8U76C
# MnKShkhG6DLPW1VWpa82xwI682tgvAYNMSnYzaVsZeHb8OB7QLX2yAokl2Te+KxZ
# uj2CkzX7qvGvDQ8uZt6+IndWCAlXdcqOH7j3b7flA+v39lwqzyvl6qgkKpuP0b/d
# IluvMuUXdwEB+fU81ovpg2x7VSXKRwrZIvTCi+sYYdOHVCmsXXUdqmCdACJ1qHsN
# teu/+LJPCNMl1FdMHGN9wMUUaGdh0/obKTGA1J3yH/Tb8SPMpwZjAFsKaH40MuhW
# 5VuoYGU5cTwrwlAEz4crimClHkumxIrw58W4cfAdSjY2UvdnZGQ5ILv4yEBWoVEJ
# JAIyjrUGAV3LLpo7K6Sk969tyarz0gOpgzBAYguQes2gBuinQPxpneSOrVUWaOF5
# 3xEGmtG8lFNXPoiTwNiKBUuh0vgnXkapxBUa3j5RwrbiaFzjeBSUfHKrmAZfQXAl
# NGKxLbbEqr4vJD0CfuyKKTInvoZs4wS6J8k+kWhckKyMtTGr4RjLbmU1qf2pU6x5
# u1hirHFBF123g6GCA0wwggNIBgkqhkiG9w0BCQYxggM5MIIDNQIBATCBkjB9MQsw
# CQYDVQQGEwJHQjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQH
# EwdTYWxmb3JkMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxJTAjBgNVBAMTHFNl
# Y3RpZ28gUlNBIFRpbWUgU3RhbXBpbmcgQ0ECEQCQOX+a0ko6E/K9kV8IOKlDMA0G
# CWCGSAFlAwQCAgUAoHkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG
# 9w0BCQUxDxcNMjMwMzA2MTUxNTMxWjA/BgkqhkiG9w0BCQQxMgQwOy4V957f9rpC
# Kp3+dqwZ4DkAZvVMrS6U1lcyoR/OJBEAkbENDWuQtXrt7/v/DuD7MA0GCSqGSIb3
# DQEBAQUABIICAIBnGaeWCd7n/dfX4wFKJbzQjXBig9YwKyGP2xlKDcAgEJQsJ3A5
# mBU2JvrPu5G4tsY7G03nU42HL2vwcilJs/NYIHP65SSYwXk2UCgOnuJ308iV+wQK
# /FYj0lM3v7rXmQo5BBRI3oN0u4Hdp6haStQnjtHf0PwuW77r/XwXC9Sb1cPM+dlf
# UG0tkPrc/B3wnbz2aV77TASkceaUzgJgaFDR60KrnvmqUCGf/N0nOu9OzV//U0V1
# I4qAc88QVhYue14YZoUVxxgV46bH/PtSYWumjPmZFMlfUeZJpFrYp/Qe9AcC4bo1
# LpZIcLwoyGSHfTyoR1PpG55qWFVHUL7tXVreUAG9MBk2viKV/hhWwpA2kA9bOOHE
# dnVAaFDLDg9pCLVd42gprTjBu53t2R34gyizG+zeVdreMDbjo0DG2m26Y9mfYj9g
# 68/FeP8s6nOHkMI6CNYZK6/0Vum01lH3YH8aZSv2UZrPN4E5/v8BG04PKFeaeQiU
# GfS+Q60DbbEol1/Y9qSEZFhowhHiXzfJF9JvpCBlE8fjFwWuPgOzqxBz7T0DkzI9
# KU/nyj57VcUzQw7xt3TmM+ANJMKQFhigcCbOM3I2j+cpCFNwRC9CRfbIrwMbzIHH
# Jf+hVTvL4gpn3R/Or2XGqqvyxkvzLWMYAPLkeMoO3SOUFvFXmhX61vnE
# SIG # End signature block
