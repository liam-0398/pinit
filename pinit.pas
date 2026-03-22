{$POINTERMATH ON}

program pinit;

uses BaseUnix;

const
  MS_RDWR    = 0;
  MS_REMOUNT = 32;
  MS_RDONLY = 1;
  RB_POWER_OFF = $4321fedc;
  RB_AUTOBOOT  = $01234567;
  RB_HALT      = $cdef0123;

var
   ENV, GG: PPChar;
   allowedToDie: Boolean;
   depmodPID: cint;

function mount(source, target, fstype: PChar; flags: LongWord; data: Pointer): cint; cdecl; external 'c';
function reboot(cmd: LongWord): cint; cdecl; external 'c';

procedure dontFearTheReaper(sig: cint); cdecl;
var
  status: cint;
begin
  while fpWaitPid(-1, @status, WNOHANG) > 0 do;
end;

procedure redirect;
var
   fd: cint;
begin
  fd := fpOpen('/dev/null', O_RDWR);
  fpDup2(fd, 0);
  fpDup2(fd, 1);
  fpDup2(fd, 2);
  fpClose(fd);
end;


procedure spawnGetty;
var
  pid, status, r: cint;
begin
  WriteLn('LOADING TTY');
  GG[0] := 'agetty';
  GG[1] := 'tty1';
  GG[2] := Nil;
  pid := fpFork;
  if pid = 0 then fpExecv('/sbin/agetty', GG)
  else
    repeat
      r := fpWaitPid(pid, @status, 0);
    until (r > 0) or (allowedToDie = True);
  if allowedToDie then exit;

  GG[1] := 'tty2';
  pid := fpFork;
  if pid = 0 then fpExecv('/sbin/agetty', GG)
  else
    repeat
      r := fpWaitPid(pid, @status, 0);
    until (r > 0) or (allowedToDie = True);
  if allowedToDie then exit;
end;

procedure allocatePPChar(sze: cint);
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

end;

procedure dev;
var
  PP, PP2, PP3, PP4, PP5, PP6: PPChar;
  pid, status: cint;

begin
   WriteLn('INITIALIZING DEVICES');

  GetMem(PP5, 3*SizeOf(PChar));
  GetMem(PP2, 5*SizeOf(PChar));
  GetMem(PP3, 5*SizeOf(PChar));
  GetMem(PP4, 3*SizeOf(PChar));
  GetMem(PP6, 3*SizeOf(PChar));

  PP5[0] := 'udevd';
  PP5[1] := '--daemon';
  PP5[2] := Nil;
  PP2[0] := 'udevadm';
  PP2[1] := 'trigger';
  PP2[2] := '--action=add';
  PP2[3] := '--type=subsystems';
  PP2[4] := Nil;
  PP3[0] := 'udevadm';
  PP3[1] := 'trigger';
  PP3[2] := '--action=add';
  PP3[3] := '--type=devices';
  PP3[4] := Nil;
  PP4[0] := 'udevadm';
  PP4[1] := 'settle';
  PP4[2] := Nil;
  PP6[0] := '/bin/sh';
  PP6[1] := '/etc/pinit/init_networking';
  PP6[2] := Nil;

  fpWaitPid(depmodPID, @status, 0);
  WriteLn('DEPMOD COMPELTE');

  pid := fpFork;
  if pid = 0 then fpExecv('/bin/udevd', PP5) else fpWaitPid(pid, @status, 0);
  pid := fpFork;
  if pid = 0 then fpExecv('/bin/udevadm', PP2) else fpWaitPid(pid, @status, 0);
  pid := fpFork;
  if pid = 0 then fpExecv('/bin/udevadm', PP3) else fpWaitPid(pid, @status, 0);
  pid := fpFork;
  if pid = 0 then fpExecv('/bin/udevadm', PP4) else fpWaitPid(pid, @status, 0);

  WriteLn('DEVICES LOADED');
  WriteLn('INITIALIZING NETWORK');

  pid := fpFork;
  if pid = 0 then begin
     redirect;
     fpExecve('/bin/sh', PP6, ENV);
  end
     else fpWaitPid(pid, @status, 0);

  WriteLn('NETWORK INITIALIZED');

  FreeMem(PP2);
  FreeMem(PP3);
  FreeMem(PP4);
  FreeMem(PP5);
  FreeMem(PP6);


end;

procedure misc;
var
   PP, PP2, PP3, PP4, PP5: PPchar;
   pid, status: cint;
begin
     WriteLn('COMPLETING MISC FUNCTIONS ');

     GetMem(PP2, 3*SizeOf(PChar));
     GetMem(PP4, 3*SizeOf(PChar));
     GetMem(PP5, 3*SizeOf(PChar));

     PP2[0] := 'mount';
     PP2[1] := '-a';
     PP2[2] := Nil;
     PP4[0] := 'swapon';
     PP4[1] := '-a';
     PP4[2] := Nil;
     PP5[0] := '/bin/sh';
     PP5[1] := '/etc/pinit/init_misc';
     PP5[2] := Nil;

         pid := fpFork;
         if pid = 0 then fpExecv('/bin/mount', PP2) else fpWaitPid(pid, @status, 0);
         pid := fpFork;
         if pid = 0 then fpExecv('/bin/swapon', PP4) else fpWaitPid(pid, @status, 0);

         pid := fpFork;
             if pid = 0 then begin
                redirect;
                fpExecve('/bin/sh', PP5, ENV);
                end
             else fpWaitPid(pid, @status, 0);

         FreeMem(PP2);
         FreeMem(PP4);
	 FreeMem(PP5);

end;

procedure services;
var
  PP: PPChar;
  pid, status: cint;
  fd: cint;
begin
 WriteLn('STARTING SERVICES');
  GetMem(PP, 3*SizeOf(PChar));
  PP[0] := '/bin/sh';
  PP[1] := '/etc/pinit/init_services';
  PP[2] := Nil;

  pid := fpFork;
             if pid = 0 then begin
                redirect;
                fpExecve('/bin/sh', PP, ENV);
                end
             else fpWaitPid(pid, @status, 0);

    FreeMem(PP);

end;

procedure kMod;
var
  PP: PPChar;
  pid, status: cint;
  fd: cint;
begin
 WriteLn('LOADING KERNEL MODULES');
  GetMem(PP, 3*SizeOf(PChar));
  PP[0] := 'depmod';
  PP[1] := '-a';
  PP[2] := Nil;
  pid := fpFork;

  if pid = 0 then
  begin
    fpExecv('/usr/bin/depmod', PP);
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
     WriteLn('REMOUNTING ROOT FILESYSTEM R/W');
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
     WriteLn('INITIAL FILESYSTEMS MOUNTED');
end;

procedure poweroff(sig: cint); cdecl;
var
  status: cint;
begin
     allowedToDie := True;
     fpKill(-1, sig);
     mount(nil, '/', nil, MS_REMOUNT or MS_RDONLY, nil);
     reboot(RB_POWER_OFF);
end;

begin
      if fpGetpid <> 1 then begin
        fpKill(1, SIGPWR);
        Halt(0);
      end;

     allowedToDie := False;

     fpSignal(SIGCHLD, SignalHandler(@dontFearTheReaper));
     fpSignal(SIGPWR, SignalHandler(@poweroff));
     fpSignal(SIGINT, SignalHandler(@poweroff));
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

     while allowedToDie = False do
        spawnGetty;

     FreeMem(GG);

end.
