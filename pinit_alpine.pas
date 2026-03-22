{$POINTERMATH ON}

program pinit;

// PINIT - ALPINE / SLOTH

uses BaseUnix;

const
  MS_RDWR    = 0;
  MS_REMOUNT = 32;
  MS_RDONLY = 1;
  RB_POWER_OFF = $4321fedc;
  RB_AUTOBOOT  = $01234567;
  RB_HALT      = $cdef0123;
  TIOSCTTY     = $540E;
  WNOHANG      = 1;

var
   ENV, GG: PPChar;
   allowedToDie: Boolean;
   depmodPID: cint;
   console: cint;

function mount(source, target, fstype: PChar; flags: LongWord; data: Pointer): cint; cdecl; external 'c';
function reboot(cmd: LongWord): cint; cdecl; external 'c';

procedure dontFearTheReaper(sig: cint); cdecl;
var
  status: cint;
begin
  while fpWaitPid(-1, @status, WNOHANG) > 0 do;
end;

procedure redirectNull;
var
   fd: cint;
begin
  fd := fpOpen('/dev/null', O_RDWR);
  fpDup2(fd, 0);
  fpDup2(fd, 1);
  fpDup2(fd, 2);
  fpClose(fd);
end;

procedure redirectLog(logPATH: PChar);
var
  fd: cint;
begin
  fd := fpOpen(logPATH, O_WRONLY or O_CREAT or O_TRUNC, 438);
  fpDup2(fd, 1);
  fpDup2(fd, 2);
  fpClose(fd);
end;


procedure spawnGetty;
var
  pid, status, r: cint;
begin
  GG[0] := 'agetty';
  GG[1] := 'tty1';
  GG[2] := Nil;

  pid := fpFork;
  if pid = 0 then
    begin
       fpSetSid;
       fpIOCtl(0, $540E, nil);
       fpExecv('/sbin/agetty', GG);
       fpExit(1);
    end
  else
    repeat
      r := fpWaitPid(pid, @status, 0);
    until (r > 0) or (allowedToDie = True);
  if allowedToDie then exit;

  GG[1] := 'tty2';
  pid := fpFork;
  if pid = 0 then
    begin
       fpSetSid;
       fpIOCtl(0, $540E, nil);
       fpExecv('/sbin/agetty', GG);
       fpExit(1);
    end
  else
    repeat
      r := fpWaitPid(pid, @status, 0);
    until (r > 0) or (allowedToDie = True);
  if allowedToDie then exit;
end;

{procedure allocatePPChar(sze: cint);
var
  PP: PPChar;
  i: Integer;
begin
   GetMem(PP, sze*SizeOf(PChar));
   // NEED WAY TO TAKE ARGUMENTS
     for i := 0 to sze - 1 do
         begin
            //  PP[i] := arg[i]
         end;

end; }

procedure dev;
var
  PP1, PP2, PP3, PP4, PP5: PPChar;
  pid, status: cint;
  logfile: PChar;

begin
  fpWrite(console, 'INITIALIZING DEVICES'+#10, 21);
  logfile := '/etc/pinit/log_network';

  GetMem(PP1, 5*SizeOf(PChar));
  GetMem(PP2, 5*SizeOf(PChar));
  GetMem(PP3, 3*SizeOf(PChar));
  GetMem(PP4, 3*SizeOf(PChar));
  GetMem(PP5, 3*SizeOf(PChar));

  PP1[0] := 'udevd';
  PP1[1] := 'trigger';
  PP1[2] := '--action=add';
  PP1[3] := '--type=subsystems';
  PP1[4] := Nil;
  PP2[0] := 'udevadm';
  PP2[1] := 'trigger';
  PP2[2] := '--action=add';
  PP2[3] := '--type=devices';
  PP2[4] := Nil;
  PP3[0] := 'udevadm';
  PP3[1] := 'settle';
  PP3[2] := Nil;
  PP4[0] := 'udevd';
  PP4[1] := '--daemon';
  PP4[2] := Nil;
  PP5[0] := '/bin/sh';
  PP5[1] := '/etc/pinit/init_networking';
  PP5[2] := Nil;

  fpWaitPid(depmodPID, @status, 0);
  fpWrite(console, 'DEPMOD COMPELTE'+#10, 16);

  pid := fpFork;
  if pid = 0 then 
  begin
  fpExecv('/sbin/udevd', PP4);
  fpExit(1);
  end
  else
     fpWaitPid(pid, @status, 0);

  fpSleep(2);

  pid := fpFork;
  if pid = 0 then fpExecv('/sbin/udevadm', PP2) else fpWaitPid(pid, @status, 0);
  pid := fpFork;
  if pid = 0 then fpExecv('/sbin/udevadm', PP1) else fpWaitPid(pid, @status, 0);
  pid := fpFork;
  if pid = 0 then fpExecv('/sbin/udevadm', PP3) else fpWaitPid(pid, @status, 0);

  fpSleep(2);

  fpWrite(console, 'DEVICES LOADED'+#10, 15);
  fpWrite(console, 'INITIALIZING NETWORK'+#10, 21);

  pid := fpFork;
  if pid = 0 then begin
     redirectLog(logfile);
     fpExecve('/bin/sh', PP5, ENV);
     fpExit(1);
  end
     else fpWaitPid(pid, @status, 0);

  fpWrite(console, 'NETWORK INITIALIZED'+#10, 20);

  FreeMem(PP1);
  FreeMem(PP2);
  FreeMem(PP3);
  FreeMem(PP4);
  FreeMem(PP5);


end;

procedure misc;
var
   PP1, PP2, PP3: PPchar;
   pid, status: cint;
begin
     fpWrite(console, 'COMPLETING MISC FUNCTIONS'+#10, 26);

     GetMem(PP1, 3*SizeOf(PChar));
     GetMem(PP2, 3*SizeOf(PChar));
     GetMem(PP3, 3*SizeOf(PChar));

     PP1[0] := 'mount';
     PP1[1] := '-a';
     PP1[2] := Nil;
     PP2[0] := 'swapon';
     PP2[1] := '-a';
     PP2[2] := Nil;
     PP3[0] := '/bin/sh';
     PP3[1] := '/etc/pinit/init_misc';
     PP3[2] := Nil;

         pid := fpFork;
         if pid = 0 then fpExecv('/bin/mount', PP1) else fpWaitPid(pid, @status, 0);
         pid := fpFork;
         if pid = 0 then fpExecv('/sbin/swapon', PP2) else fpWaitPid(pid, @status, 0);

         pid := fpFork;
             if pid = 0 then begin
                redirectNull;
                fpExecve('/bin/sh', PP3, ENV);
		fpExit(1);
                end
             else fpWaitPid(pid, @status, 0);

         FreeMem(PP1);
         FreeMem(PP2);
	     FreeMem(PP3);

end;

procedure services;
var
  PP: PPChar;
  pid, status: cint;
  logfile: PChar;
begin
  fpWrite(console, 'STARTING SERVICES'+#10, 18);
  logfile := '/etc/pinit/log_services';
  GetMem(PP, 3*SizeOf(PChar));
  PP[0] := '/bin/sh';
  PP[1] := '/etc/pinit/init_services';
  PP[2] := Nil;

  pid := fpFork;
             if pid = 0 then begin
                redirectLog(logfile);
                fpExecve('/bin/sh', PP, ENV);
		fpExit(1);
                end
             else fpWaitPid(pid, @status, 0);

    FreeMem(PP);
    dontFearTheReaper(0);

end;

procedure kMod;
var
  PP: PPChar;
  pid: cint;
begin
  fpWrite(console, 'LOADING KERNEL MODULES'+#10, 23);
  GetMem(PP, 3*SizeOf(PChar));
  PP[0] := 'depmod';
  PP[1] := '-a';
  PP[2] := Nil;
  pid := fpFork;

  if pid = 0 then
  begin
    fpExecv('/usr/bin/depmod', PP);
    fpExit(1);
    end
  else
      depmodPID := pid;

    FreeMem(PP);

end;

procedure remount;
var
   pid, status: cint;
   PP: PPChar;
begin
     fpWrite(console, 'REMOUNTING ROOT FILESYSTEM R/W'+#10, 31);
     GetMem(PP, 4*SizeOf(PChar));
     PP[0] := 'fsck';
     PP[1] := '-A';
     PP[2] := '-a';
     PP[3] := Nil;
     pid := fpFork;
         if pid = 0 then
             fpExecv('/sbin/fsck', PP)
         else
             fpWaitPid(pid, @status, 0);

	 FreeMem(PP);
         mount(nil, '/', nil, MS_REMOUNT or MS_RDWR, nil);

end;

procedure initialMount;
begin
     mount('proc', '/proc', 'proc', 0, nil);
     mount('sysfs', '/sys', 'sysfs', 0, nil);
     mount('devtmpfs', '/dev', 'devtmpfs', 0, nil);
     //mount('tmpfs', '/run', 'tmpfs', 0, 'mode=0755');
     
     console := fpOpen('/dev/console', O_WRONLY);     
     fpWrite(console, 'INITIAL FILESYSTEMS MOUNTED'+#10, 28);
end;

procedure poweroff(sig: cint); cdecl;
begin
     allowedToDie := True;
     fpKill(-1, sig);
     //fpfSync;
     mount(nil, '/', nil, MS_REMOUNT or MS_RDONLY, nil);
     reboot(RB_POWER_OFF);
end;

procedure poweroff_reboot(sig: cint); cdecl;
begin
     allowedToDie := True;
     fpKill(-1, sig);
     //fpfSync;
     mount(nil, '/', nil, MS_REMOUNT or MS_RDONLY, nil);
     reboot(RB_AUTOBOOT);
end;

begin

     if fpGetPid <> 1 then
        fpExit(1);

     allowedToDie := False;

     fpSignal(SIGCHLD, SignalHandler(@dontFearTheReaper));
     fpSignal(SIGPWR, SignalHandler(@poweroff));
     fpSignal(SIGINT, SignalHandler(@poweroff_reboot));
     fpSignal(SIGTERM, SignalHandler(@poweroff));

     GetMem(ENV, 3*SizeOf(PChar));
     GetMem(GG, 3*SizeOf(PChar));
     ENV[0] := 'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin';
     ENV[1] := 'TERM=linux';
     ENV[2] := Nil;

     initialMount;
     remount;
     kMod;
     misc;
     dev;
     services;

     FreeMem(ENV);

     fpClose(console);
     while True do
     begin
     if allowedToDie = False then
        spawnGetty
       else
          fpPause();
     end;
     
     //FreeMem(GG);

end.
