unit xxmp;

interface

uses xxm;

type
  TXxmMonoBank=class(TXxmProject, IXxmProjectEvents1, IXxmProjectEvents2)
  private
    //IXxmProjectEvents1
    function HandleException(Context: IXxmContext; const PageClass,
      ExceptionClass, ExceptionMessage: WideString): boolean;
    procedure ReleasingContexts;
    procedure ReleasingProject;
    //IXxmProjectEvents2
    function CheckEvent(const EventKey: WideString; var CheckIntervalMS: cardinal): boolean;
  public
    function LoadPage(Context: IXxmContext; const Address: WideString): IXxmFragment; override;
    function LoadFragment(Context: IXxmContext; const Address, RelativeTo: WideString): IXxmFragment; override;
    procedure UnloadFragment(Fragment: IXxmFragment); override;
  end;

var
  MonoBankClosing:boolean;

function XxmProjectLoad(const AProjectName:WideString): IXxmProject; stdcall;

// IMPORTANT: set "loadCopy":false in xxm.json !!!!

implementation

uses SysUtils, xxmFReg, GameData;

function XxmProjectLoad(const AProjectName:WideString): IXxmProject;
begin
  MonoBankClosing:=false;
  Result:=TXxmMonoBank.Create(AProjectName);
end;

{ TXxmMonoBank }

function TXxmMonoBank.LoadPage(Context: IXxmContext; const Address: WideString): IXxmFragment;
begin
  inherited;
  //TODO: link session to request
  Result:=XxmFragmentRegistry.GetFragment(Self,Address,'');
  //TODO: if Context.ContextString(csVerb)='OPTION' then...
end;

function TXxmMonoBank.LoadFragment(Context: IXxmContext; const Address, RelativeTo: WideString): IXxmFragment;
begin
  Result:=XxmFragmentRegistry.GetFragment(Self,Address,RelativeTo);
end;

procedure TXxmMonoBank.UnloadFragment(Fragment: IXxmFragment);
begin
  inherited;
  //TODO: set cache TTL, decrease ref count
  //Fragment.Free;
end;

function TXxmMonoBank.HandleException(Context: IXxmContext; const PageClass,
  ExceptionClass, ExceptionMessage: WideString): boolean;
begin
  Result:=false;
end;

procedure TXxmMonoBank.ReleasingContexts;
begin
  MonoBankClosing:=true;
end;

procedure TXxmMonoBank.ReleasingProject;
begin
  MonoBankClosing:=true;
end;

function TXxmMonoBank.CheckEvent(const EventKey: WideString; var CheckIntervalMS: cardinal): boolean;
var
  game_id,player_id:integer;
begin
  if MonoBankClosing then Result:=true else
   begin
    //EventKey by Format('MonoBank%.2d%.2d',[game_id,player_id+1])
    game_id:=StrToInt(Copy(EventKey,9,2));
    player_id:=StrToInt(Copy(EventKey,11,2))-1;
    if player_id=-1 then
      Result:=GameSlot[game_id].PlayerBankGameIndex<>GameSlot[game_id].GameIndex
    else
      Result:=GameSlot[game_id].Players[player_id].GameIndex<>GameSlot[game_id].GameIndex;
   end;
end;

initialization
  IsMultiThread:=true;
end.
