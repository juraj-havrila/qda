// Type:Batch No:10047     Name:PL-Prisma: ImportPrisma V3  Date:26.11.2014 11:31:33
// PL-Prisma: ImportPrisma V1.3 auf TC
// aboeg, 16.04.2012: Files haben keine msg-Extension
// jhavril, 19.10.2021: ITG Schweißdaten Import und Verarbeitung von PRISMA Daten 
//######################################
{.ASI DataMyte.-----kuhl-----------------------------------------------------------------
  Durch dieses Skript werden Stichprobeninformationen, die aus Prisma-Daten stammen
  versucht der Messung hinzuzufügen, die für das zu Grunde liegende Teileident importiert
  wurde. Wird eine solche Messung nicht gefunden, werden die Daten in einer                                                     
  Zwischentabelle zur weiteren Verarbeitung abgespeichert.
                                                                                                     
  06.09.2011                                                                                                                                                      
  20141125_js: UpdateSample war QDA9 inkompatibel , durch Update getauscht.
  20141126_mk: UpdateSample angepasst.                                                                                                        
  20141127_js:  MAX_ANZ_FILES auf 500 reduziert, da 5Min-Intervall. 
--------------------------------------------------------------------------.ASI DataMyte.}
                                                                                                                                                

const
  { Stichprobenfelder }                                                         
  //MAX_ANZ_FILES = 1000;                // aboeg, 29.12.2011: max. Anzahl auf einmal zu importierende Dateien 
  MAX_ANZ_FILES = 500;                // aboeg, 29.12.2011: max. Anzahl auf einmal zu importierende Dateien
  STPR_IDENT = 1;                         
  STPR_MASCHINE = 2;            
  STPR_SCHRITT = 3;                  //20130418_ab/js analog zum Systemscript 7, wird nicht benötigt
  STPR_VORRICHTUNG = 3;              //20130418_ab/js analog zum Systemscript 7 (von 4 auf 3 gesetzt)
//  IMPORTSCRIPTPATH = '\\SSTRQLSImportUt.edc.corpintra.net\eingang\PAC\Prisma_ITG_Test';  //jhavril -zum Testen
//  IMPORTSCRIPTPATH = '\\SSTRQLSImportUt.edc.corpintra.net\eingang\PAC\Prisma_ITG\reIMPORTED';                                    
  { Filter auf zu Verarbeitende OPs }              // aboeg: es werden von PLA alle Telegramme von Prisma übertragen     
  //OP_LIST = ';OP 70A;OP 70B;OP70A;OP70B;OP_DUMMY'; // aboeg, 29.12.2011: OP war falsch: 060 => 070  jbismar hinzugefügt (OP70A,OP70B)
                                                   // aboeg, 27.01.2017: hinter letzten OP muss ein ";" kommen s.u.   !!!!!!!!!!!!!!!!!!
                                                   //        VORSICHT: der OP in QDA heisst: "OPQPMA_SERIENPRüVUNG_MA" und nicht was mit "OP70". Gibt es zwar auch, ist aber FALSCH !!!
                                                   //        Die Zwischentabelle heisst: ZDC_PRISMA
  //OP_LIST = ';AS1020;AS1021;AS2020;AS2021;AS3020;AS3021;AS4020;AS4021;AS5020;AS5021;OP_DUMMY'; //jhavril, 13.8.2021; OP Liste erstellt
  //OP_LIST = ';30554-AS1020;30555-AS1021;30558-AS2020;30559-AS2021;30563-AS3020;30564-AS3021;30568-AS4020;30569-AS4021;30570-AS5020;30571-AS5021;OP_DUMMY'; //jhavril, 25.8.2021; OP Liste angepasst (beinhaltet Maschine statt Schritt, weil AS1020 macht auch verschrauben)
  OP_LIST = ';30554-AS1020;30555-AS1021;30558-AS2020;30559-AS2021;30563-AS3020;30564-AS3021;30568-AS4020;30569-AS4021;30570-AS5020;30571-AS5021;30961-AM9110;31178-RB4050;31180-RB5050;30573-RB4041;31225-RB4010;31226-RB5010;OP_DUMMY'; //jhavril, 10.11.2021; OP Liste angepasst (beinhaltet Zusammenbaustationen)
  OP_SCHWEISSEN = ';30554-AS1020;30555-AS1021;30558-AS2020;30559-AS2021;30563-AS3020;30564-AS3021;30568-AS4020;30569-AS4021;30570-AS5020;30571-AS5021;OP_DUMMY'; //jhavril, 10.11.2021; OP nur Schweißvorgänge
  OP_ZUSAMMENBAU_FINAL = ';30961-AM9110;OP_DUMMY';
  OP_ZUSAMMENBAU_1 = ';31178-RB4050;31180-RB5050;30573-RB4041;31225-RB4010;31226-RB5010;30574-RB5040;OP_DUMMY';

// //  OP_LIST = ';30961-AM9110;31178-RB4050;31180-RB5050;30573-RB4041;31225-RB4010;31226-RB5010;OP_DUMMY'; //jhavril, 10.11.2021; OP Liste angepasst (beinhaltet Zusammenbaustationen)
// //  OP_SCHWEISSEN = ';OP_DUMMY'; //jhavril, 10.11.2021; OP nur Schweißvorgänge

var
  FileToMove: Boolean;
  RelatedFileContent: Boolean;
{ forward Deklarationen }
function GetValueFromNode(aNodeName, aLine: String): String; forward;
function ImportPrismaFile(aFilename: String): Boolean; forward;
function ExportPrismaFile(aID, aMaschine, aSchritt, aVorrichtung, aDatum, aID_Anbauteil: TStringList): Boolean; forward;
procedure StartImport; forward;            
function UpdateSample(aID, aMaschine, aSchritt, aVorrichtung: String): Boolean; forward;
procedure UpdateZDCTable(aID, aMaschine, aSchritt, aVorrichtung, aDatum, aID_Anbauteil: TStringList); forward;
procedure UpdateOrphanedSample; forward;
//function UpdateZDCTable(aID, aMaschine, aSchritt, aVorrichtung, aDatum, aID_Anbauteil: TStringList): Boolean; forward;

                                                                                                 
{.ASI DataMyte.-----kuhl-----------------------------------------------------------------                                                           
  Durch diese Routine wird der Import gestartet.
  Es werden alle *.msg Dateien, die sich im übergebenen Verzeichnis befinden, versuchst
  zu verarbeiten.

  Bei Erfolg wirden die daten in ein Unterverzeichnis "IMPORTED" und bei einem Fehler
  im Verzeichnis "NOT_IMPORTED" verschoben.

  06.09.2011
--------------------------------------------------------------------------.ASI DataMyte.}
procedure StartImport;                                       
var
  I: Integer;
  Anz_Dateien: Integer;   // aboeg, 29.12.2011: max. Anzahl auf einmal zu importierende Dateien
  FileList: TStringList;
  ImportOK: Boolean;
  
begin
  FileList := TStringList.Create;
  try
    // FileList.Text := GetFiles(IMPORTSCRIPTPATH, '*.msg');
    FileList.Text := GetFiles(IMPORTSCRIPTPATH, '*');  // aboeg, 16.04.2012: Files haben keine msg-Extension
    if FileList.Count > MAX_ANZ_FILES then         // aboeg, 29.12.2011: max. Anzahl auf einmal zu importierende Dateien
      Anz_Dateien := MAX_ANZ_FILES
    else
      Anz_Dateien := FileList.Count;
    for I := 0 to Anz_Dateien - 1 do
    begin
      FileToMove := False;
      ImportOK := ImportPrismaFile(IMPORTSCRIPTPATH + '\' + FileList.Strings[I]); // aboeg, 29.12.2011: der "\" hat gefehlt
      If (FileToMove) then
          begin
          MoveFile(IMPORTSCRIPTPATH + '\', FileList.Strings[I], ImportOK);            // aboeg, 29.12.2011: der "\" hat gefehlt
          end;
    end;
  finally
    FileList.Free;
  end;
end;

{.ASI DataMyte.-----kuhl-----------------------------------------------------------------
  Durch diese Routine wird eine *.msg Datei verarbeitet.
  Es werden die geforderten Stichprobeninformationen zu dem aktuellen Teileident
  ermittelt und dann versucht eine evtl. vorhandene Messung zu dem Teileident mit diesen
  Informationen zu updaten.

  Existiert noch keine Messung zu dem Teileident, werden alle Informationen in die
  Tabelle ZDC_PRISMA zur weiteren Verarbeitung zwischengespeichert.

  @param aFilename Übergabe des Dateinamens
  06.09.2011
--------------------------------------------------------------------------.ASI DataMyte.}
function ImportPrismaFile(aFilename: String): Boolean;
var
  I: Integer;
  ImportFile: TStringList;
  ID: String;
  ID_Anbauteil: TStringList;
  Maschine: String;       
  Schritt: String;
  Vorrichtung: String;
  Datum: String;                     // aboeg, 29.12.2011: DATUM eingefügt
  Zeile: String;
  InFertigung: Boolean;
begin
  Result := False;
  InFertigung := False;                
  ImportFile := TStringList.Create;
//  ID_Anbauteil := TStringList.Create;    //jhavril, 11.10.2021 : prüfen ob dies die richtige Stelle ist zum initiieren
  try
    ImportFile.LoadFromFile(aFilename);
    RelatedFileContent := False;
    if (ImportFile.Count < 3)then RelatedFileContent := False;
    for I := 0 to ImportFile.Count - 1 do
    begin
      Zeile := ImportFile.Strings[I];
      if Pos('<FERTIGUNG>', Zeile) > 0 then
      begin
        InFertigung := True;
        ID_Anbauteil := TStringList.Create;  //////who knows  
        ID := '';  Maschine := ''; Vorrichtung := '';  Schritt := '';  Datum := '';
        Continue;
      end;
      if InFertigung then
      begin
        if Pos('<ID>', Zeile) > 0 then
          ID := GetValueFromNode('ID', Trim(Zeile));
        else if Pos('<MASCHINE>', Zeile) > 0 then
          Maschine := GetValueFromNode('MASCHINE', Trim(Zeile));
        else if Pos('<SCHRITT>', Zeile) > 0 then
          Schritt := GetValueFromNode('SCHRITT', Trim(Zeile));
        else if Pos('<VORRICHTUNG>', Zeile) > 0 then
          Vorrichtung := GetValueFromNode('VORRICHTUNG', Trim(Zeile));
        else if Pos('<ID_ANBAUTEIL>', Zeile) > 0 then
          ID_Anbauteil.Add(GetValueFromNode('ID_ANBAUTEIL', Trim(Zeile)));    //TBD Check if works
        else if Pos('<MASCHINE_DATUM_ENDE>', Zeile) > 0 then         // aboeg, 29.12.2011: DATUM eingefügt
          Datum := GetValueFromNode('MASCHINE_DATUM_ENDE', Trim(Zeile));
      end;
      if Pos('</FERTIGUNG>', Zeile) > 0 then 
      begin
        InFertigung := False;
        if Pos(';' + Maschine + ';', OP_LIST) > 0 then              //jhavril, 25.08.2021: ersetzt Schritt mit Maschine (AS1020 tut auch Verschrauben)
        begin
            UpdateZDCTable(ID, Maschine, Schritt, Vorrichtung, Datum, ID_Anbauteil);
        end;
        ID_Anbauteil.Free;
      end;     
    end;
    Result := True;
  finally
    ImportFile.Free;
    if (not RelatedFileContent) then FileToMove := True;
  end;
end;

{.Daimler.-----jhavril-----------------------------------------------------------------
Abspeichern eines Datensatzes welches durch die ID im Moment nicht zugeordnet werden kann.
Routine wird gebraucht da in einzelnen Dateien auch mehrere Datensätze enthalten sein können
von den nicht alle im Moment verarbeitet werden.
--------------------------------------------------------------------------.Daimler.}

function ExportPrismaFile(aID, aMaschine, aSchritt, aVorrichtung, aDatum, aID_Anbauteil :TStringList): Boolean;
var
  K: Integer;
  ExportFile: TStringList;
  my_anbauteil:       String;
  my_filename: String

begin
  Result := False;     
  ExportFile := TStringList.Create;
  my_filename := IMPORTSCRIPTPATH + '\' + 'swap' + aID + '_' + aMaschine;

  ExportFile.Add('<FERTIGUNG>');
  ExportFile.Add('<ID>' + aID + '</ID>');
  ExportFile.Add('<MASCHINE>' + aMaschine + '</MASCHINE>');
  ExportFile.Add('<SCHRITT>' + aSchritt + '</SCHRITT>');
  ExportFile.Add('<MASCHINE_DATUM_ENDE>' + aDatum + '</MASCHINE_DATUM_ENDE>');
  ExportFile.Add('<VORRICHTUNG>' + aVorrichtung + '</VORRICHTUNG>');
  if (aID_Anbauteil.Count > 0) then
       begin
       for K := 0 to aID_Anbauteil.Count-1 do
         begin
         my_anbauteil := aID_Anbauteil[K];
         ExportFile.Add('<ID_ANBAUTEIL>' + my_anbauteil + '<ID_ANBAUTEIL>');
         end;
       end;
  ExportFile.Add('</FERTIGUNG>');
  if not FileExists(my_filename) then 
    begin      
      ExportFile.SaveToFile(my_filename);
      //CloseFile(my_filename);
      Result := True;
    end
    else Result := False;
  ExportFile.Free;
end;

{.ASI DataMyte.-----kuhl-----------------------------------------------------------------
  Durch diese Routine wird der Wert des Übergenenen Knotennamens wermittelt und
  an den Aufrufer zurückgegeben.

  @param aNodeName Name des Knotens
  @param result Rückgabe des ermittelten Wertes
  06.09.2011
--------------------------------------------------------------------------.ASI DataMyte.}
function GetValueFromNode(aNodeName, aLine: String): String;
var
  StartPos: Integer;
  EndPos: Integer;
begin
  StartPos := Pos('<' + aNodeName + '>', aLine) + Length(aNodeName) + 2;
  EndPos :=   Pos('</' + aNodeName + '>', aLine);
  Result := Copy(aLine, StartPos, EndPos - StartPos);
end;

{.ASI DataMyte.-----kuhl-----------------------------------------------------------------
  Durch diese Routine wird die zu dem übergebenen Teileident passende Messung mit
  den übergebenen Stichprobeninformationen geupdatet

  @param aID Übergabes des Teileidents
  @param aMaschine Übergabe der Stichprobeninformation "Maschine"
  @param aSchritt Übergabe der Stichprobeninformation "Schritt"
  @param aVorrichtung Übergabe der Stichprobeninformation "Vorrichtung"
  @param result Bei duchgeführtem Update wird TRUE zurückgegeben
  06.09.2011                                                      
--------------------------------------------------------------------------.ASI DataMyte.}
function UpdateSample(aID, aMaschine, aSchritt, aVorrichtung: String);
var
  QuData: TQuery;
  columns : TStringList;
  my_string : String;
  my_column : String;
  pom : Integer; 
begin
  my_string := aMaschine;
  my_schritt := aMaschine;
  columns:= TStringList.Create;
  //columns.CommaText := '1=SUCH20, 2=SUCH21, 3=SUCH22, 4=SUCH3, 5=SUCH4';   //jhavril, 18.10.2021, SUCH3 ist falsch (belegt durch Ident) 3,4,20,21,22 --> 4,5,20,21,22
  columns.CommaText := '1=SUCH20, 2=SUCH21, 3=SUCH22, 4=SUCH4, 5=SUCH5';
  Delete(my_string, 1,8);
  pom := StrToInt(my_string) div 1000;
  my_column := columns.Values[pom];
  Delete(my_schritt, 1,6);
  Result := False;
  QuData := TQuery.Create(nil);
  try
    QuData.DatabaseName := 'QDA8';
    QuData.Close;
    QuData.Sql.Clear;
    QuData.Sql.Add('SELECT PRFNR, ' + my_column);
    QuData.Sql.Add('FROM DAT_MESSUNG');
    QuData.Sql.Add('WHERE SUCH' + IntToStr(STPR_IDENT + 2) + ' = :IDENT');
    QuData.ParamByName('IDENT').AsString := aID;
    QuData.Open;
    if not (QuData.Bof and QuData.Eof) then
    begin
      QuData.Close;
      QuData.Sql.Clear;
      //--- 20210901 jhavril
    QuData.Sql.Add('UPDATE DAT_MESSUNG SET ' + my_column + ' = :SCHRITT');
    QuData.Sql.Add('WHERE SUCH' + IntToStr(STPR_IDENT + 2) + ' = :IDENT'); 
    QuData.ParamByName('IDENT').AsString := aID;                  
    QuData.ParamByName('SCHRITT').AsString := my_schritt + '-' + aVorrichtung;
    QuData.ExecSql;
      Result := True;
    end;
  finally
    QuData.Free;
  end;
end;

{.ASI DataMyte.-----kuhl-----------------------------------------------------------------
  Durch diese Routine wird die Tabelle ZDC_PRISMA mit den übergebenen
  Stichprobeninformationen aktualisiert.

  @param aID Übergabes des Teileidents
  @param aMaschine Übergabe der Stichprobeninformation "Maschine"
  @param aSchritt Übergabe der Stichprobeninformation "Schritt"
  @param aVorrichtung Übergabe der Stichprobeninformation "Vorrichtung"
  07.09.2011
--------------------------------------------------------------------------.ASI DataMyte.}
//procedure UpdateZDCTable(aID, aMaschine, aSchritt, aVorrichtung, aDatum, aID_Anbauteil :TStringList);
procedure UpdateZDCTable(aID, aMaschine, aSchritt, aVorrichtung, aDatum, aID_Anbauteil :TStringList);
var
  QuData:              TQuery;   
  sValue_Datum:        String;    // aboeg, 29.12.2011: DATUM eingefügt
  my_Anbauteil:        String;
  my_AnzahlAnbauteile: Integer;
  my_Maschine:         String;  
  my_Schritt:          String;
  my_Vorrichtung:      String; 
  list_Maschine:       TStringList;  
  list_Schritt:        TStringList;
  list_Vorrichtung:    TStringList;
  is_finished:         String;
  L:                   Integer;
  
begin
//   aDatum :=  AnsiReplaceStr(aDatum, '.', '/');    //jhavril, 25.8.2021: Datum Format fixed (StrToDateTime will '/' statt '.')
   ShortDateFormat := 'dd.mm.yyyy';                //jhavril, 25.8.2021: Datum Format fixed (mm.dd -> dd.mm)
   my_AnzahlAnbauteile := 0;
////--------       
        if Pos(';' + aMaschine + ';', OP_SCHWEISSEN) > 0 then     ///nicht sicher ob das notwendig ist
        begin
          RelatedFileContent := True;
          QuData := TQuery.Create(nil);
        try
          QuData.DatabaseName := 'QDA8';
          QuData.Close;
          QuData.Sql.Clear;
          QuData.Sql.Add('SELECT IDENT FROM ZDC_PRISMA');
          QuData.Sql.Add('WHERE IDENT = :IDENT');
          QuData.Sql.Add('AND MASCHINE = :MASCHINE');
          QuData.ParamByName('IDENT').AsString := aID;   
          QuData.ParamByName('MASCHINE').AsString := aMaschine;   
          QuData.Open;
      
          if (QuData.Bof and QuData.Eof) then
          begin     
            QuData.DatabaseName := 'QDA8';
            QuData.Close;
            QuData.Sql.Clear;
            QuData.Sql.Add('INSERT INTO ZDC_PRISMA (IDENT, MASCHINE, SCHRITT, VORRICHTUNG, DATUM, LAST_STEP, IS_FINISHED) VALUES'); // aboeg, 29.12.2011: DATUM eingefügt
            QuData.Sql.Add('(:IDENT, :MASCHINE, :SCHRITT, :VORRICHTUNG, :DATUM, :LAST_STEP, :IS_FINISHED)');
            QuData.ParamByName('IDENT').AsString := aID;
            QuData.ParamByName('MASCHINE').AsString := aMaschine;
            QuData.ParamByName('SCHRITT').AsString := aSchritt;
            QuData.ParamByName('VORRICHTUNG').AsString := aVorrichtung;
            QuData.ParamByName('DATUM').AsDateTime := StrToDateTime(aDatum);    // aboeg, 29.12.2011: DATUM eingefügt
            QuData.ParamByName('LAST_STEP').AsString := aMaschine;
            QuData.ParamByName('IS_FINISHED').AsString := '0';
            QuData.ExecSql;    
            FileToMove := True;
          end;
        finally
        QuData.Free;
        end;  
        end;
////--------    
        else if (Pos(';' + aMaschine + ';', OP_ZUSAMMENBAU_1) > 0) and (not aID_Anbauteil.Count = 0) then
        begin
        RelatedFileContent := True;
        for L := 0 to aID_Anbauteil.Count-1 do
        begin
          my_Anbauteil := aID_Anbauteil[L];
          QuData := TQuery.Create(nil);
        try
           QuData.DatabaseName := 'QDA8';
           QuData.Close;
           QuData.Sql.Clear;
           QuData.Sql.Add('SELECT IDENT FROM ZDC_PRISMA');
           QuData.Sql.Add('WHERE IDENT = :ANBAUTEIL');
           QuData.ParamByName('ANBAUTEIL').AsString := my_Anbauteil;  
           QuData.Open;
           if not (QuData.Bof and QuData.Eof) then
             begin 
               my_AnzahlAnbauteile := my_AnzahlAnbauteile + 1;    
               begin 
                 QuData.DatabaseName := 'QDA8';
                 QuData.Close;
                 QuData.Sql.Clear;        
                 QuData.Sql.Add('UPDATE ZDC_PRISMA SET IDENT = :IDENT, LAST_STEP = :LAST_STEP, IS_FINISHED = :IS_FINISHED');
                 QuData.Sql.Add('WHERE IDENT = :ANBAUTEIL');
                 QuData.ParamByName('IDENT').AsString := aID;
                 QuData.ParamByName('ANBAUTEIL').AsString := my_Anbauteil;   
                 QuData.ParamByName('LAST_STEP').AsString := aMaschine;
                 QuData.ParamByName('IS_FINISHED').AsString := '0';
                 QuData.ExecSql;
               end;
             end;
          else
            begin          
              if (ExportPrismaFile(aID, aMaschine, aSchritt, aVorrichtung, aDatum, aID_Anbauteil)) then FileToMove := True;         
            end;                  
       finally
          QuData.Free;
       end;
       
       if (my_AnzahlAnbauteile >= 4) then 
         FileToMove := True;
         else
            begin  
//              FileToMove := False;
//              if (ExportPrismaFile(aID, aMaschine, aSchritt, aVorrichtung, aDatum, aID_Anbauteil)) then FileToMove := True; 
              if (ExportPrismaFile(aID, aMaschine, aSchritt, aVorrichtung, aDatum, aID_Anbauteil)) then FileToMove := True;
//              FileToMove := True; 
            end;   
       end;
    end;
////--------
        else if (Pos(';' + aMaschine + ';', OP_ZUSAMMENBAU_FINAL) > 0) and (not aID_Anbauteil.Count = 0)
        then
        begin
          RelatedFileContent := True;         
//          if (not aID_Anbauteil[0] = '') then my_Anbauteil := aID_Anbauteil[0];
          my_Anbauteil := aID_Anbauteil[0];
          QuData := TQuery.Create(nil);
          try
            QuData.DatabaseName := 'QDA8';
            QuData.Close;
            QuData.Sql.Clear;
            QuData.Sql.Add('SELECT IDENT, MASCHINE, SCHRITT, VORRICHTUNG FROM ZDC_PRISMA');
            QuData.Sql.Add('WHERE IDENT = :ANBAUTEIL');
            QuData.ParamByName('ANBAUTEIL').AsString := my_Anbauteil; 
            QuData.Open;     
        if not (QuData.Bof and QuData.Eof) then   
            begin 
              list_Maschine := TStringList.Create;
              list_Schritt := TStringList.Create;
              list_Vorrichtung := TStringList.Create;
              QuData.DisableControls;
              QuData.First;
              while not QuData.Eof do begin               
                list_Maschine.Add(QuData.FieldByName('MASCHINE').AsString);  
                list_Schritt.Add(QuData.FieldByName('SCHRITT').AsString);
                list_Vorrichtung.Add(QuData.FieldByName('VORRICHTUNG').AsString);
                QuData.Next;
                end;
                QuData.EnableControls;
              for L := 0 to list_Maschine.Count-1 do begin
                my_Maschine :=  list_Maschine[L];  
                my_Schritt :=   list_Schritt[L];
                my_Vorrichtung := list_Vorrichtung[L]; 
                if UpdateSample(aID, my_Maschine, my_Schritt, my_Vorrichtung)
                  then
                       begin
                       is_finished :=2;
                       FileToMove := True;
                       end;
                  else is_finished :=1;
     
                QuData.DatabaseName := 'QDA8';
                QuData.Close;
                QuData.Sql.Clear;        
                QuData.Sql.Add('UPDATE ZDC_PRISMA SET IDENT = :IDENT, LAST_STEP = :LAST_STEP, IS_FINISHED = :IS_FINISHED');
                QuData.Sql.Add('WHERE IDENT = :ANBAUTEIL AND MASCHINE = :MASCHINE');
                QuData.ParamByName('IDENT').AsString := aID;
                QuData.ParamByName('MASCHINE').AsString := my_Maschine;
                QuData.ParamByName('ANBAUTEIL').AsString :=  my_Anbauteil;   
                QuData.ParamByName('LAST_STEP').AsString := aMaschine;
                QuData.ParamByName('IS_FINISHED').AsString := is_finished; 
                QuData.ExecSql;
              end;
              list_Maschine.Free;
              list_Schritt.Free;
              list_Vorrichtung.Free;
              FileToMove := True;  
            end;     
          else
            begin  
              //FileToMove := False;
              if (ExportPrismaFile(aID, aMaschine, aSchritt, aVorrichtung, aDatum, aID_Anbauteil)) then FileToMove := True;         
            end;           
        finally
        QuData.Free;
       end;
     end;
////--------
end;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

procedure UpdateOrphanedSample;
var
  QuData:              TQuery;   
  my_Ident:            String;
  my_Maschine:         String;  
  my_Schritt:          String;
  my_Vorrichtung:      String; 
  list_Ident:          TStringList;  
  list_Maschine:       TStringList;  
  list_Schritt:        TStringList;
  list_Vorrichtung:    TStringList;
  is_finished:         String;
  L:                   Integer;
begin
  QuData := TQuery.Create(nil);
  try
    QuData.DatabaseName := 'QDA8';
    QuData.Close;
    QuData.Sql.Clear;
    QuData.Sql.Add('SELECT IDENT, MASCHINE, SCHRITT, VORRICHTUNG FROM ZDC_PRISMA');
    QuData.Sql.Add('WHERE IS_FINISHED = 1');
    QuData.Open;     
  if not (QuData.Bof and QuData.Eof) then   
    begin 
      list_Ident := TStringList.Create;
      list_Maschine := TStringList.Create;
      list_Schritt := TStringList.Create;
      list_Vorrichtung := TStringList.Create;
      QuData.DisableControls;
      QuData.First;
      while not QuData.Eof do begin     
        list_Ident.Add(QuData.FieldByName('IDENT').AsString);  
        list_Maschine.Add(QuData.FieldByName('MASCHINE').AsString);  
        list_Schritt.Add(QuData.FieldByName('SCHRITT').AsString);
        list_Vorrichtung.Add(QuData.FieldByName('VORRICHTUNG').AsString);
        QuData.Next;
        end;
        QuData.EnableControls;
      for L := 0 to list_Ident.Count-1 do begin
        my_Ident :=  list_Ident[L];
        my_Maschine :=  list_Maschine[L];  
        my_Schritt :=   list_Schritt[L];
        my_Vorrichtung := list_Vorrichtung[L]; 
        if UpdateSample(my_Ident, my_Maschine, my_Schritt, my_Vorrichtung)
          then is_finished :=2;
          else is_finished :=1;  
          
        QuData.DatabaseName := 'QDA8';
        QuData.Close;
        QuData.Sql.Clear;        
        QuData.Sql.Add('UPDATE ZDC_PRISMA SET IS_FINISHED = :IS_FINISHED');
        QuData.Sql.Add('WHERE IDENT = :IDENT AND MASCHINE = :MASCHINE');
        QuData.ParamByName('IDENT').AsString := my_Ident;
        QuData.ParamByName('MASCHINE').AsString := my_Maschine;
        QuData.ParamByName('IS_FINISHED').AsString := is_finished; 
        QuData.ExecSql;
      end;
      list_Ident.Free;
      list_Maschine.Free;
      list_Schritt.Free;
      list_Vorrichtung.Free;
    end;    
  finally
    QuData.DatabaseName := 'QDA8';
    QuData.Close;
    QuData.Sql.Clear;
    QuData.Sql.Add('DELETE FROM ZDC_PRISMA');
    QuData.Sql.Add('WHERE  DATUM < trunc(sysdate) - 100');
    QuData.ExecSql; 
    QuData.Free;
  end;
end;
