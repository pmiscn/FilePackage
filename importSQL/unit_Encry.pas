unit unit_Encry;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes,
  mu.aes, System.NetEncoding,
  qjson, qstring, qdigest;

type
  TDEncry = class(TObject)
  private

  protected

  public
    constructor Create;
    destructor Destroy; override;

    class function Encry(aStr: String): String;
    class function Dencry(aStr: String): String; overload; static;

  end;

implementation

{ TDEncry }

constructor TDEncry.Create;
begin

end;

destructor TDEncry.Destroy;
begin

  inherited;
end;

class function TDEncry.Dencry(aStr: String): String;
var
  input: TStringStream;
  output: TMemoryStream;
begin
  if aStr = '' then
    exit('');
  try
    input := TStringStream.Create(aStr);
    output := TMemoryStream.Create;
    try

      TNetEncoding.Base64.Decode(input, output);
      output.Position := 0;
      input.Clear;
      Muaes.Decrypt(output, input);
      result := input.DataString;
    finally
      input.Free;
      output.Free;
    end;
  except
    exit('');
  end;
end;

class function TDEncry.Encry(aStr: String): String;
var
  input: TStringStream;
  output: TMemoryStream;
begin
  if aStr = '' then
    exit('');
  try
    input := TStringStream.Create(aStr);
    output := TMemoryStream.Create;
    try

      Muaes.Encrypt(input, output);
      output.Position := 0;
      input.Clear;
      TNetEncoding.Base64.Encode(output, input);

      result := input.DataString;
    finally
      input.Free;
      output.Free;
    end;
  except
    exit('');
  end;
end;

initialization

finalization

end.
