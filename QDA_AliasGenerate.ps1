## Script to generate QDA Alias.ini File from provided JSON   [ Option /i ]
## OR to generate JSON File from existing Alias.ini           [ Option /e ]
## Juraj Havrila, 2021-11-10

for ( $i = 0; $i -lt $args.count; $i++ ) {
    if ($args[ $i ] -eq "/i"){ $fileImport=$args[ $i+1 ]}
    if ($args[ $i ] -eq "-i"){ $fileImport=$args[ $i+1 ]}
    if ($args[ $i ] -eq "/e"){ $fileExport=$args[ $i+1 ]}
    if ($args[ $i ] -eq "-e"){ $fileExport=$args[ $i+1 ]}
}
$scriptName = [io.path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
$scriptLog = $PSScriptRoot+"\"+$scriptName+".log"

if ($fileImport){
$my_outfile = 'juraj.ini'
Write-Host "I'm in the IMPORT section"
    $my_infile=$PSScriptRoot+"\"+$fileImport
    if (!(Test-Path $fileImport)) { $fileImport = $my_infile}

  if ($fileImport -match '.json$') {$qda_parameters_should = Get-Content $fileImport | ConvertFrom-Json}

  if ($fileImport -match '.csv$') {
    $my_infile=$PSScriptRoot+"\"+$fileImport
    $qda_parameters_raw = Get-Content $my_infile 
    $qda_parameters_should=@()
    $header=@()    

    foreach ($my_line in $qda_parameters_raw){
   $my_qda_session=@{}
   $my_input=@()
   if ($qda_parameters_raw.IndexOf($my_line) -eq 0){ $header= $my_line.Split(",") }
   else {
       $my_input=$my_line.Split(",")
       for ($i=0; $i -lt $my_input.Count; $i++){ $my_qda_session.Add($header[$i],$my_input[$i]) }
       }
   $qda_parameters_should += [pscustomobject] @{
        SessionName = $my_qda_session.SessionName
        Driver= $my_qda_session.Driver 
        Alias= $my_qda_session.Alias 
        Name= $my_qda_session.Name 
        Password= $my_qda_session.Password 
        Param0= $my_qda_session.Param0 
        Param1= $my_qda_session.Param1 
        Encryption= $my_qda_session.Encryption 
        IsWebApp= $my_qda_session.IsWebApp 
        IsLizenz= $my_qda_session.IsLizenz 
        IsStandard= $my_qda_session.IsStandard 
        IsMasterConfigDB= $my_qda_session.IsMasterConfigDB 
        }
   }
  }

  $my_timestamp = Get-Date -Format g
  Add-Content $scriptlog "$my_timestamp INFO: Importing Alias.ini Configuration from file $my_infile"

#### HERE CODE to Convert json Input to Alias.ini
  $output_to_file = @() 
  foreach ($my_qda_session in $qda_parameters_should) {
    if ($my_qda_session.SessionName){ $output_to_file += '[' + $my_qda_session.SessionName + ']' }
    if ($my_qda_session.Driver){ $output_to_file += 'Driver=' + $my_qda_session.Driver }
    if ($my_qda_session.Alias){ $output_to_file += 'Alias=' + $my_qda_session.Alias }
    if ($my_qda_session.Name){ $output_to_file += 'Name=' + $my_qda_session.Name }
    if ($my_qda_session.Password){ $output_to_file += 'Password=' + $my_qda_session.Password }
    if ($my_qda_session.Param0){ $output_to_file += 'Param0=' + $my_qda_session.Param0 }
    if ($my_qda_session.Param1){ $output_to_file += 'Param1=' + $my_qda_session.Param1 }
    if ($my_qda_session.Encryption){ $output_to_file += 'Encryption=' + $my_qda_session.Encryption }
    if ($my_qda_session.IsWebApp){ $output_to_file += 'IsWebApp=' + $my_qda_session.IsWebApp }
    if ($my_qda_session.IsLizenz){ $output_to_file += 'IsLizenz=' + $my_qda_session.IsLizenz }
    if ($my_qda_session.IsStandard){ $output_to_file += 'IsStandard=' + $my_qda_session.IsStandard }
    if ($my_qda_session.IsMasterConfigDB){ $output_to_file += 'IsMasterConfigDB=' + $my_qda_session.IsMasterConfigDB }
    if ($my_qda_session.SessionName){ $output_to_file += '' } # this obscure if-condition is due to emty line at the beggining of file while importing from .csv ...
  }
  $output_to_file| Out-File $my_outfile
}

if ($fileExport){
  $QDA_ConfigData = @()
  $count_sessions = 0;
  Write-Host "Im in the EXPORT section"
  $fileImport='Alias.ini.txt'
  $my_infile=$PSScriptRoot+"\"+$fileImport
  $qda_parameters_raw = Get-Content $my_infile 
 
  foreach ($my_line in $qda_parameters_raw){
    if ($my_line.Contains('#'))  { $my_line = $my_line.Substring(0, $my_line.IndexOf('#')) }
    if ($my_line -match '\[(.*?)\]' ) {
      if ($count_sessions) {
      $QDA_ConfigData +=  @{SessionName = $my_SessionName; Driver = $my_driver; Alias=$my_alias; Name=$my_name; Password=$my_password; Param0=$my_param0; Param1=$my_param1; Encryption=$my_encryption; IsWebApp= $my_iswebapp; IsLizenz= $my_islizenz; IsStandard=$my_isstandard; IsMasterConfigDB=$my_ismasterconfigdb};
      }
        $my_SessionName = ''
        $my_driver=''
        $my_alias=''
        $my_name=''
        $my_password=''
        $my_param0=''
        $my_param1=''
        $my_encryption=''
        $my_iswebapp=''
        $my_islizenz=''
        $my_isstandard=''
        $my_ismasterconfigdb=''
        $my_SessionName = $my_line.Trim('[]')
        $count_sessions++
    }
   elseif ($my_line -match '^Driver=' ) { $my_driver= $my_line.Trim('^Driver=') }
   elseif ($my_line -match '^Alias=' ) { $my_alias= $my_line.Trim('^Alias=') }
   elseif ($my_line -match '^Name=' ) { $my_name= $my_line.Trim('^Name=') }
   elseif ($my_line -match '^Password=' ) { $my_password= $my_line.Trim('^Password=') }
   elseif ($my_line -match '^Param0=' ) { $my_param0= $my_line.Trim('^Param0=') }
   elseif ($my_line -match '^Param1=' ) { $my_param1= $my_line.Trim('^Param1=') }
   elseif ($my_line -match '^Encryption=' ) { $my_encryption= $my_line.Trim('^Encryption=') }
   elseif ($my_line -match '^IsWebApp=' ) { $my_iswebapp= $my_line.Trim('^IsWebApp=') }
   elseif ($my_line -match '^IsLizenz=' ) { $my_islizenz= $my_line.Trim('^IsLizenz=') }
   elseif ($my_line -match '^IsStandard=' ) { $my_isstandard= $my_line.Trim('^IsStandard=') }
   elseif ($my_line -match '^IsMasterConfigDB=' ) { $my_ismasterconfigdb= $my_line.Trim('^IsMasterConfigDB=') }
   #else {Write-Host $my_line}
   }
    $my_outfile=$PSScriptRoot+"\"+$fileExport
  if ($fileExport -match '.json$') { $QDA_ConfigData | ConvertTo-Json -depth 100 | Out-File $my_outfile }

  elseif ($fileExport -match '.csv$') {
      $output_to_file = @()
      $output_to_file = "SessionName,Driver,Alias,Name,Password,Param0,Param1,Encryption,IsWebApp,IsLizenz,IsStandard,IsMasterConfigDB`n"
      foreach ($my_qda_session in $QDA_ConfigData){         
        $output_to_file +=$my_qda_session.SessionName + ',' + $my_qda_session.Driver + ',' + $my_qda_session.Alias + ',' + $my_qda_session.Name + ',' + $my_qda_session.Password + ',' + $my_qda_session.Param0 + ',' + $my_qda_session.Param1 + ',' + $my_qda_session.Encryption + ',' + $my_qda_session.IsWebApp + ',' + $my_qda_session.IsLizenz + ',' + $my_qda_session.IsStandard + ',' + $my_qda_session.IsMasterConfigDB + "`n"   
        }
      $output_to_file| Out-File $my_outfile
      }
  $my_timestamp = Get-Date -Format g
  Add-Content $scriptlog "$my_timestamp INFO: Exporting QDA Configuration of $count_sessions sessions from $my_infile into file $my_outfile"
  }
