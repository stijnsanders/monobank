unit GameData;

interface

uses SysUtils;

const
  GameSlots=4;
  GameSlotIndex=12333;
  PlayerBank_SeparateConnection=-1;
  PlayerBank_AllPlayersDoBank=-2;

var
  GameSlot:array[0..GameSlots-1] of record
    GameActive:boolean;
    GameSince:TDateTime;
    Players:array of record
      Name,Clr:string;
      Balance,GameIndex:integer;
      Connected:boolean;
    end;
    PlayerBankConnected,FreeParkingCash:boolean;
    PlayerBank,GameIndex,PlayerBankGameIndex,FreeParkingBalance:integer;
    FreeParkingName:string;
    History:array of string;
    HistorySize:integer;
  end;

function StartGame(const Players:array of string;
  PlayerBank,StartBalance:integer;FreeParkingCash:boolean;
  FreeParkingName:string):integer;

function GameIDByPlayerName(const Name:string):integer;

procedure GameTransaction(game_id,p1,p2:integer;const t:string;a:integer);

implementation

uses Windows, xxm;

var
  GameSlotLock:TRTLCriticalSection;

procedure InitGameSlots;
var
  i:integer;
begin
  for i:=0 to GameSlots-1 do
   begin
    GameSlot[i].GameActive:=false;
    GameSlot[i].HistorySize:=0;
   end;
  InitializeCriticalSection(GameSlotLock);
end;

function StartGame(const Players:array of string;
  PlayerBank,StartBalance:integer;FreeParkingCash:boolean;
  FreeParkingName:string):integer;
var
  n,i,j:integer;
  d:TDateTime;
begin
  n:=Length(Players);
  EnterCriticalSection(GameSlotLock);
  try

    //check stale games
    d:=Now-15.0/1440.0;
    for i:=0 to GameSlots-1 do
      if GameSlot[i].GameActive and (GameSlot[i].GameSince<d) then
       begin
        j:=0;
        while (j<Length(GameSlot[i].Players)) and
          not(GameSlot[i].Players[j].Connected) do inc(j);
        if j=Length(GameSlot[i].Players) then
          GameSlot[i].GameActive:=false;
       end;

    //find free game slot
    Result:=0;
    while (Result<GameSlots) and (GameSlot[Result].GameActive) do inc(Result);
    if Result=GameSlots then
      raise Exception.Create('All game slots currently occupied, please try again later');

    //set player data
    SetLength(GameSlot[Result].Players,n);
    for i:=0 to n-1 do
     begin
      if Players[i]='' then
        raise Exception.Create('Player #'+IntToStr(i+1)+': name required');
      if LowerCase(Players[i])='bank' then
        raise Exception.Create('Player #'+IntToStr(i+1)+': name "bank" not allowed');
      for j:=0 to i-1 do
        if Players[j]=Players[i] then
          raise Exception.Create('Player #'+IntToStr(i+1)+': names must be unique');
      GameSlot[Result].Players[i].Name:=Players[i];
      GameSlot[Result].Players[i].Clr:='';//TODO
      GameSlot[Result].Players[i].Balance:=StartBalance;
      GameSlot[Result].Players[i].GameIndex:=0;
      GameSlot[Result].Players[i].Connected:=false;
     end;

    //start the game
    GameSlot[Result].PlayerBank:=PlayerBank;
    GameSlot[Result].PlayerBankConnected:=false;
    GameSlot[Result].PlayerBankGameIndex:=0;
    //GameSlot[Result].HistorySize:=0;
    GameSlot[Result].FreeParkingCash:=FreeParkingCash;
    GameSlot[Result].FreeParkingName:=FreeParkingName;
    GameSlot[Result].FreeParkingBalance:=0;
    GameSlot[Result].GameIndex:=0;
    GameSlot[Result].GameSince:=Now;
    GameSlot[Result].GameActive:=true;

  finally
    LeaveCriticalSection(GameSlotLock);
  end;
end;

function GameIDByPlayerName(const Name:string):integer;
var
  n:string;
  i,j:integer;
begin
  n:=LowerCase(Name);
  EnterCriticalSection(GameSlotLock);
  try
    Result:=-1;
    i:=0;
    while (Result=-1) and (i<GameSlots) do
     begin
      if GameSlot[i].GameActive then
        if (n='bank') and (GameSlot[i].PlayerBank=PlayerBank_SeparateConnection)
        and not(GameSlot[i].PlayerBankConnected)
        then
          Result:=i
        else
         begin
          j:=1;
          while (Result=-1) and (j<Length(GameSlot[i].Players)) do
            if (LowerCase(GameSlot[i].Players[j].Name)=n)
            and not(GameSlot[i].Players[j].Connected)
            then
              Result:=i
            else
              inc(j);
         end;
      inc(i);
     end;
  finally
    LeaveCriticalSection(GameSlotLock);
  end;
end;

procedure GameTransaction(game_id,p1,p2:integer;const t:string;a:integer);
var
  p,l:integer;
  DoesBank:boolean;
  procedure AddHistory(const h:string);
  begin
    if GameSlot[game_id].GameIndex=GameSlot[game_id].HistorySize then
     begin
      inc(GameSlot[game_id].HistorySize,$100);//grow step
      SetLength(GameSlot[game_id].History,GameSlot[game_id].HistorySize);
     end;
    GameSlot[game_id].History[GameSlot[game_id].GameIndex]:=
      '<p>('+FormatDateTime('hh:nn:ss',Now)+') '+h+' : '+IntToStr(a)+'</p>';
    inc(GameSlot[game_id].GameIndex);
    GameSlot[game_id].GameSince:=Now;
  end;
begin
  EnterCriticalSection(GameSlotLock);
  try
    if a<=0 then
      raise Exception.Create('Invalid transaction amount');
    DoesBank:=((p1=-1) and (GameSlot[game_id].PlayerBank=PlayerBank_SeparateConnection))
      or (GameSlot[game_id].PlayerBank=PlayerBank_AllPlayersDoBank)
      or (p1=GameSlot[game_id].PlayerBank);
    l:=Length(GameSlot[game_id].Players);
    if t='s' then
     begin
      if p1=p2 then
        raise Exception.Create('Can''t transact to self');
      if GameSlot[game_id].Players[p1].Balance<a then
        raise Exception.Create('Unsufficient balance');
      if (p1<0) or (p2<0) or (p1>=l) then
        raise Exception.Create('Invalid player index');
      if GameSlot[game_id].FreeParkingCash and (p2=l) then
       begin
        dec(GameSlot[game_id].Players[p1].Balance,a);
        inc(GameSlot[game_id].FreeParkingBalance,a);
        AddHistory(HTMLEncode(GameSlot[game_id].Players[p1].Name)+' &rarr; <i class="f">'+HTMLEncode(GameSlot[game_id].FreeParkingName)+'</i>');
       end
      else
       begin
        if (p2>=l) then
          raise Exception.Create('Invalid player index');
        dec(GameSlot[game_id].Players[p1].Balance,a);
        inc(GameSlot[game_id].Players[p2].Balance,a);
        AddHistory(HTMLEncode(GameSlot[game_id].Players[p1].Name)+' &rarr; '+HTMLEncode(GameSlot[game_id].Players[p2].Name));
       end;
     end
    else
    if t='c' then
     begin
      if not DoesBank then
        raise Exception.Create('Invalid authorization');
      if GameSlot[game_id].FreeParkingCash and (p2=l) then
       begin
        inc(GameSlot[game_id].FreeParkingBalance,a);
        AddHistory('<i class="b">Bank</i> &rarr; <i class="f">'+HTMLEncode(GameSlot[game_id].FreeParkingName)+'</i>');
       end
      else
       begin
        if p1=-1 then p:=p2 else p:=p1;
        if (p<0) or (p>=l) then
          raise Exception.Create('Invalid player index');
        inc(GameSlot[game_id].Players[p].Balance,a);
        AddHistory('<i class="b">Bank</i> &rarr; '+HTMLEncode(GameSlot[game_id].Players[p].Name));
       end;
     end
    else
    if t='d' then
     begin
      if not DoesBank then
        raise Exception.Create('Invalid authorization');
      if GameSlot[game_id].FreeParkingCash and (p2=l) then
       begin
        dec(GameSlot[game_id].FreeParkingBalance,a);
        AddHistory('<i class="f">'+HTMLEncode(GameSlot[game_id].FreeParkingName)+'</i> &rarr; <i class="b">Bank</i>');
       end
      else
       begin
        if p1=-1 then p:=p2 else p:=p1;
        if (p<0) or (p>=l) then
          raise Exception.Create('Invalid player index');
        if GameSlot[game_id].Players[p].Balance<a then
          raise Exception.Create('Unsufficient balance');
        dec(GameSlot[game_id].Players[p].Balance,a);
        AddHistory(HTMLEncode(GameSlot[game_id].Players[p].Name)+' &rarr; <i class="b">Bank</i>');
       end;
     end
    else
    if t='f' then
     begin
      //Free Parking Cash
      if not(GameSlot[game_id].FreeParkingCash) then
        raise Exception.Create('Free Parking Cash not enabled on this game');
      if p1=-1 then p:=p2 else p:=p1; //if not DoesBank then raise?
      if (p<0) or (p>=l) then
        raise Exception.Create('Invalid player index');
      a:=GameSlot[game_id].FreeParkingBalance;
      inc(GameSlot[game_id].Players[p].Balance,a);
      GameSlot[game_id].FreeParkingBalance:=0;
      AddHistory('<i class="f">'+HTMLEncode(GameSlot[game_id].FreeParkingName)+'</i> &rarr; '+HTMLEncode(GameSlot[game_id].Players[p].Name));
     end
    else
      raise Exception.Create('Unknown transaction type');
  finally
    LeaveCriticalSection(GameSlotLock);
  end;
end;

initialization
  InitGameSlots;
finalization
  DeleteCriticalSection(GameSlotLock);

end.
