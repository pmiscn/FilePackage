unit Unit_CMD;

interface

uses
  windows, classes, SysUtils, SyncObjs,
  uConsoleClass, forms, FrmMain, unit2, unit1,unit3,
  Mu.QworkerJobStatus, qworker, qstring,
  Unit_public;

procedure DoCommand(cmdstr: string);

implementation

uses publicstrfun, dateutils, strutils, unit_logs, publicfun2, Mu.Fileinfo;

function getdot(count: Integer): string;
var
  s: string;
begin
  while length(s) < count do
  begin
    s := s + '.';
  end;
  result := s;
end;

procedure ShowCommandList();
var
  st, st2: Tstringlist;
  s: string;
  i: Integer;


begin
  st := Tstringlist.create;
  st2 := Tstringlist.create;
  try
    if not fileexists(ExtractFilePath(paramStr(0)) + '\' + 'comandlist.txt')
    then
      exit;
    st.LoadFromFile(ExtractFilePath(paramStr(0)) + '\' + 'comandlist.txt');
    for i := 0 to st.count - 1 do
    begin
      s := trim(st[i]);
      if s = '' then
        continue;
      if s[1] = ';' then
      begin
        continue;
      end;
      if s[1] = '>' then
      begin
        continue;
      end;
      if s[1] = ':' then
      begin
        s := trim(s);
        continue;
      end;
      split(s, '|', st2);
      if st2.count <> 2 then
        continue;
    end;
  finally
    st.Free;
    st2.Free;
  end;
end;

procedure colorshowaline(s: string);
var
  st: Tstringlist;
  i: Integer;
  c: bool;
begin
  c := false;
  for i := 1 to length(s) do
  begin

  end;
end;

procedure DoShowForms;
begin
  FMain := TFMain.create(application);
  FMain.ShowModal;
  FMain.Free;

end;

procedure DoShowTestForms;
begin
  F_ConfigTest := TF_ConfigTest.create(application);
  F_ConfigTest.ShowModal;
  F_ConfigTest.Free;
end;

procedure DoShowTest2Forms;
begin
  F_TestWeb := TF_TestWeb.create(application);
  F_TestWeb.ShowModal;
  F_TestWeb.Free;
end;

procedure DoShowTest3Forms;
begin
  Form3 := TForm3.create(application);
  Form3.ShowModal;
  Form3.Free;
end;

procedure DoGetCommand(cmdstr: string);
var
  st: Tstringlist;
  i, tag: Integer;
  s: string;
begin
  st := Tstringlist.create;
  try
    split(cmdstr, ' ', st);

  finally
    st.Free;
  end;
  exit;
end;

procedure Showruning();
var
  i: Integer;
  ATime: Int64;
  s: String;
begin

  try
    try
      FWAJobMng.MuTask1.RunningTaskList.lock;

      if FWAJobMng.MuTask1.RunningTaskList.DataList.count = 0 then
      begin
        writeln('运行列表为空.');
      end
      else
        writeln(format('running task count:%d',
          [FWAJobMng.MuTask1.RunningTaskList.DataList.count]));
      for i := 0 to FWAJobMng.MuTask1.RunningTaskList.DataList.count - 1 do
      begin
        ATime := GetTimeStamp;
        with FWAJobMng.MuTask1.RunningTaskList[i] do
        begin
          s := inttostr(id) + #9 + (ttype) + #9 + (Input.asString) + #9 +
            (Status) + #9 + (Percent) + #9 + (Error) + #9 +
            (ThreadHandle.ToString())
        end;
        writeln(s);
      end;
    except

    end;
  finally
    FWAJobMng.MuTask1.RunningTaskList.unlock;
  end;

end;

procedure ShowWaiting();
var
  i: Integer;
  ATime: Int64;
  s: String;
begin

  try
    try
      FWAJobMng.TaskElecs.lock;
      if FWAJobMng.TaskElecs.DataList.count = 0 then
      begin
        writeln('等待列表为空.');
      end
      else
        writeln(format('Waiting task count:%d',
          [FWAJobMng.TaskElecs.DataList.count]));

      for i := 0 to FWAJobMng.TaskElecs.DataList.count - 1 do
      begin
        ATime := GetTimeStamp;
        with FWAJobMng.TaskElecs[i] do
        begin
          s := inttostr(id) + #9 + (ttype) + #9 + (Input.asString);
        end;
        writeln(s);
      end;
    except

    end;
  finally
    FWAJobMng.TaskElecs.unlock;
  end;

end;

procedure Showjobs();
var
  i: Integer;
  ATime: Int64;
  s: String;
begin
  try
    // messagebox(0, pchar('start 1'), '', 0);
    getQworkerJobStatuses(nil);
    writeln(format('jobs count:%d', [QworkerJobStatuses.count]));
    for i := 0 to QworkerJobStatuses.count - 1 do
    begin
      with QworkerJobStatuses[i] do
      begin
        s := inttostr(i) + #9 + (inttostr(Handle)) + ' ' + (JobFuncName) + ' ' +
          (IsRunningStr) + ' ' + (Style) + ' ' + (Categray) + ' ' +
          (inttostr(Runs)) + #9 + (RollupTime(EscapedTime div 10000)) + #9 +
          (formatdatetime('yyyy-mm-dd hh:mm:ss', PushTime)) + ' ' +
          (formatdatetime('yyyy-mm-dd hh:mm:ss', PopTime)) + ' ' +
          (RollupTime(AvgTime div 10000)) + ' ' +
          (RollupTime(TotalTime div 10000)) + ' ' +
          (RollupTime(MaxTime div 10000)) + ' ' +
          (RollupTime(MinTime div 10000));
        if (Handle and $03) = 3 then
        begin
          s := s + ' ' + (formatdatetime('yyyy-mm-dd hh:mm:ss', Plan.NextTime))
            + #9 + (Plan.asString);
        end
        else
        begin
          if (NextTime > 0) and (NextTime < 75495) then
            s := s + #9 + (formatdatetime('yyyy-mm-dd hh:mm:ss', NextTime))
        end;
      end;
      writeln(s);
    end;

  except
    on e: exception do
      writeln(e.Message);
  end;

end;

procedure DoTaskCommand(cmdstr: string);
var
  st: Tstringlist;
var
  i, tag: Integer;
  s: string;
begin
  Showjobs();
  Showruning();
  ShowWaiting();
  // st := Tstringlist.Create;
  // try
  // split(cmdstr, ' ', st);
  // if st.Count = 1 then
  // begin
  // SetWhite(false);
  // publicfun2.FileFind(getexepath + 'config\', '*.js', st);
  // for i := 0 to st.Count - 1 do
  // begin
  // writeln(inttostr(i) + ' '
  // + strutils.AnsiReplaceStr(st[i], getexepath + 'config\', ''));
  // end;
  // exit;
  // end;
  // if st[1] = 'list' then
  // begin
  // SetWhite(false);
  // exit;
  // end else
  // writeln('Errro Task Command');
  // finally
  // st.Free;
  // end;
end;

procedure DoCommand(cmdstr: string);
begin
  try
    if (cmdstr = '?') or (cmdstr = 'command list') then
    begin
      ShowCommandList;
      exit;
    end;

    if (cmdstr = 'clr') or (cmdstr = 'clear') then
    begin
      exit;
    end;

    if (cmdstr = 'tsl') then
    begin
      cmdstr := 'task list';
    end;

    if (cmdstr = 'show') or (cmdstr = 'debug') then
    begin
      DoShowForms();
    end;
    if (cmdstr = 'test') or (cmdstr = '`') then
    begin
      DoShowTestForms();
    end;
    if (cmdstr = 'test2') then
    begin
      DoShowTest2Forms();
    end;
    if (cmdstr = 'test3') then
    begin
      DoShowTest3Forms();
    end;
    if (cmdstr = 'status') or (cmdstr = 'state') then
    begin
      writeln(format('等待:%d,执行:%d,完成:%d,放弃:%d',
        [FWAJobMng.TaskElecs.CountLocked, FWAJobMng.MuTask1.RunningCount,
        FWAJobMng.MuTask1.CompletedCount, FWAJobMng.MuTask1.IgnoreCount]));

    end;
    if copy(cmdstr, 1, 3) = 'get' then
    begin
      DoGetCommand(cmdstr);
      exit;
    end;
    if cmdstr = 'jobs' then
    begin
      Showjobs();
      exit;
    end;
    if (cmdstr = 'runing') or (cmdstr = 'running') then
    begin
      Showruning();
      exit;
    end;
    if (cmdstr = 'wait') or (cmdstr = 'waiting') then
    begin
      ShowWaiting();
      exit;
    end;

    if copy(cmdstr, 1, 4) = 'task' then
    begin
      DoTaskCommand(cmdstr);
      exit;
    end;
    if cmdstr = '\' then
    begin
  //    QLogConsole.ShowInConsole := not QLogConsole.ShowInConsole;
      exit;
    end;
  except
    on e: exception do
    begin
      writeln(e.Message);
    end;
  end;
end;

end.
