unit MainFormU;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.ExtCtrls,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  D3DCanvasU,
  FastD3DMathU,
  D3D11,
  DXGI,
  DxgiType,
  DxgiFormat,
  DXTypes,
  D3DCommon;

type
  TMainForm = class(TForm)
    pnlD3dCanvas: TPanel;

    procedure FormCreate(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure pnlD3dCanvasMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
  private
    m_d3dCanvas : TD3DCanvas;

    m_pVertexShader : ID3D11VertexShader;
    m_pPixelShader  : ID3D11PixelShader;
    m_pInputLayout  : ID3D11InputLayout;
    m_pVertexBuffer : ID3D11Buffer;
    m_pScreenBuffer : ID3D11Buffer;

    m_pBlendDesc : ID3D11BlendState;

    m_matProj : TXMMATRIX;


    procedure LoadContent;

    procedure Start;
    //procedure DrawLine;
    procedure Draw;

    procedure Render;

  public
  end;

var
  MainForm : TMainForm;

implementation

{$R *.dfm}
//==============================================================================
procedure TMainForm.FormCreate(Sender: TObject);
var
  d3dProp : TD3DCanvasProperties;
  RASTERIZER_DESC: TD3D11_Rasterizer_Desc;
  ppRasterizerState: ID3D11RasterizerState;
begin
  with d3dProp do
  begin
    Hwnd   := pnlD3dCanvas.Handle;
    Width  := pnlD3dCanvas.Width;
    Height := pnlD3dCanvas.Height;
    MSAA   := 4;
  end;

  m_d3dCanvas := TD3DCanvas.Create(d3dProp);

  RASTERIZER_DESC := TD3D11_Rasterizer_Desc.Create(True);
  RASTERIZER_DESC.CullMode := D3D11_CULL_NONE;
  m_d3dCanvas.Device.CreateRasterizerState(D3D11_RASTERIZER_DESC(RASTERIZER_DESC), ppRasterizerState);
  m_d3dCanvas.DeviceContext.RSSetState(ppRasterizerState);

  LoadContent;
end;

//==============================================================================
procedure TMainForm.FormPaint(Sender: TObject);
begin
  //
end;


//==============================================================================
procedure TMainForm.LoadContent;
var
  pVSBuffer : ID3DBlob;
  pPSBuffer : ID3DBlob;
  d3dLinkage : ID3D11ClassLinkage;
  shaderInputLayout : array[0..1] of TD3D11_Input_Element_Desc;

  bufferDesc : TD3D11_Buffer_Desc;
  viewport : D3D11_VIEWPORT;
  numViewports : UINT;
  mappedResource : D3D11_MAPPED_SUBRESOURCE;


  blendDesc: TD3D11_Blend_Desc;
  resourceData : TD3D11_SUBRESOURCE_DATA;
const
  c_numLayoutElements = 2;
begin
  m_d3dCanvas.CompileShader('ScreenCoordinates.fx', 'VS_Main', 'vs_4_0', pVSBuffer);
  m_d3dCanvas.CompileShader('ScreenCoordinates.fx', 'PS_Main', 'ps_4_0', pPSBuffer);

  m_d3dCanvas.Device.CreateVertexShader(pVSBuffer.GetBufferPointer, pVSBuffer.GetBufferSize, d3dLinkage, @m_pVertexShader);
  m_d3dCanvas.Device.CreatePixelShader(pPSBuffer.GetBufferPointer, pPSBuffer.GetBufferSize, d3dLinkage, m_pPixelShader);

  shaderInputLayout[0].SemanticName := 'POSITION';
  shaderInputLayout[0].SemanticIndex := 0;
  shaderInputLayout[0].Format := DXGI_FORMAT_R32G32B32_FLOAT;
  shaderInputLayout[0].InputSlot := 0;
  shaderInputLayout[0].AlignedByteOffset := 0;
  shaderInputLayout[0].InputSlotClass := D3D11_INPUT_PER_VERTEX_DATA;
  shaderInputLayout[0].InstanceDataStepRate := 0;

  shaderInputLayout[1].SemanticName := 'COLOR';
  shaderInputLayout[1].SemanticIndex := 0;
  shaderInputLayout[1].Format := DXGI_FORMAT_R32G32B32A32_FLOAT;
  shaderInputLayout[1].InputSlot := 0;
  shaderInputLayout[1].AlignedByteOffset := 16;
  shaderInputLayout[1].InputSlotClass := D3D11_INPUT_PER_VERTEX_DATA;
  shaderInputLayout[1].InstanceDataStepRate := 0;

  m_d3dCanvas.Device.CreateInputLayout(@shaderInputLayout, c_numLayoutElements, pVSBuffer.GetBufferPointer, pVSBuffer.GetBufferSize, m_pInputLayout);

  pVSBuffer := nil;
  pPSBuffer := nil;

  //////////////////////////////////////////////////////////////////////////////
  ///  Blend
  blendDesc := TD3D11_Blend_Desc.Create(True);

  blendDesc.RenderTarget[0].BlendEnable := True;
	blendDesc.RenderTarget[0].SrcBlend := D3D11_BLEND_SRC_ALPHA;
	blendDesc.RenderTarget[0].DestBlend := D3D11_BLEND_INV_SRC_ALPHA;
	blendDesc.RenderTarget[0].SrcBlendAlpha := D3D11_BLEND_ONE;
	blendDesc.RenderTarget[0].DestBlendAlpha := D3D11_BLEND_ZERO;
	blendDesc.RenderTarget[0].BlendOp := D3D11_BLEND_OP_ADD;
	blendDesc.RenderTarget[0].BlendOpAlpha := D3D11_BLEND_OP_ADD;
	blendDesc.RenderTarget[0].RenderTargetWriteMask := UINT8(D3D11_COLOR_WRITE_ENABLE_ALL);

  m_d3dCanvas.Device.CreateBlendState(blendDesc, m_pBlendDesc);

  //////////////////////////////////////////////////////////////////////////////
  ///  Vertex Buffer
  ZeroMemory(@bufferDesc, Sizeof(bufferDesc));

	bufferDesc.Usage := D3D11_USAGE_DYNAMIC;
	bufferDesc.ByteWidth := Sizeof(TSimpleVertex) * 3;
	bufferDesc.BindFlags := D3D11_BIND_VERTEX_BUFFER;
	bufferDesc.CPUAccessFlags := D3D11_CPU_ACCESS_WRITE;
	bufferDesc.MiscFlags := 0;


//  SetLength(vertices, 3);
//
//  vertices[0].pos[0] := 1;
//  vertices[0].pos[1] := 1;
//  vertices[0].pos[2] := 1;
//
//
//  vertices[1].pos[0] := 10;
//  vertices[1].pos[1] := 10;
//  vertices[1].pos[2] := 1;
//
//  vertices[2].pos[0] := 20;
//  vertices[2].pos[1] := 20;
//  vertices[2].pos[2] := 1;
//
//  vertices[0].color[0] := 1;
//  vertices[0].color[1] := 1;
//  vertices[0].color[2] := 1;
//  vertices[0].color[3] := 1;
//
//  vertices[0].color[0] := 1;
//  vertices[0].color[1] := 1;
//  vertices[0].color[2] := 1;
//  vertices[0].color[3] := 1;
//
//  vertices[0].color[0] := 1;
//  vertices[0].color[1] := 1;
//  vertices[0].color[2] := 1;
//  vertices[0].color[3] := 1;

//  ZeroMemory(@resourceData, sizeof(resourceData));
//  resourceData.pSysMem := vertices;

//  m_d3dCanvas.Device.CreateBuffer(bufferDesc, @resourceData, m_pVertexBuffer);
  m_d3dCanvas.Device.CreateBuffer(bufferDesc, nil, m_pVertexBuffer);

  //////////////////////////////////////////////////////////////////////////////
  ///  Screen Buffer
  ZeroMemory(@bufferDesc, Sizeof(bufferDesc));

	bufferDesc.Usage := D3D11_USAGE_DYNAMIC;
	bufferDesc.ByteWidth := Sizeof(TXMMATRIX);
	bufferDesc.BindFlags := D3D11_BIND_CONSTANT_BUFFER;
	bufferDesc.CPUAccessFlags := D3D11_CPU_ACCESS_WRITE;
	bufferDesc.MiscFlags := 0;

  m_d3dCanvas.Device.CreateBuffer(bufferDesc, nil, m_pScreenBuffer);

  //////////////////////////////////////////////////////////////////////////////
  ///  View Port
 	numViewports := 1;

	m_d3dCanvas.DeviceContext.RSGetViewports(numViewports, @viewport);

	m_matProj := XMMatrixOrthographicOffCenterLH(viewport.TopLeftX, viewport.Width, viewport.Height, viewport.TopLeftY,
		viewport.MinDepth, viewport.MaxDepth);

  m_d3dCanvas.DeviceContext.Map(m_pScreenBuffer, 0, D3D11_MAP_WRITE_DISCARD, 0, mappedResource);
  CopyMemory(mappedResource.pData, @m_matProj, SizeOf(TXMMATRIX));
  m_d3dCanvas.DeviceContext.Unmap(m_pScreenBuffer, 0);
end;

//==============================================================================
procedure TMainForm.Start;
var
  stride, offset : UINT;
begin
	m_d3dCanvas.DeviceContext.VSSetShader(m_pVertexShader, nil, 0);
	m_d3dCanvas.DeviceContext.PSSetShader(m_pPixelShader, nil, 0);

	m_d3dCanvas.DeviceContext.OMSetBlendState(m_pBlendDesc, D3DColor4f(1.0, 1.0, 1.0, 1.0), $ffffffff);

	m_d3dCanvas.DeviceContext.VSSetConstantBuffers(0, 1, m_pScreenBuffer);

	m_d3dCanvas.DeviceContext.IASetInputLayout(m_pInputLayout);

	stride := SizeOf(TSimpleVertex);
	offset := 0;
	m_d3dCanvas.DeviceContext.IASetVertexBuffers(0, 1, &m_pVertexBuffer, @stride, @offset);

	//fontWrapper->DrawString(m_d3dCanvas.DeviceContext, L"", 0.0f, 0.0f, 0.0f, 0xff000000, FW1_RESTORESTATE | FW1_NOFLUSH);
end;


//==============================================================================
procedure TMainForm.Draw;
var
  mappedResource : D3D11_MAPPED_SUBRESOURCE;
  pos : SIZE_T;
  vertices : array[0..2] of TSimpleVertex;
begin
  m_d3dCanvas.Clear(D3DColor4f(0.0, 0.0, 0.0, 1.0));

  //SetLength(vertices, 3);

  vertices[0].pos[0] := 1;
  vertices[0].pos[1] := 1;
  vertices[0].pos[2] := 0;


  vertices[1].pos[0] := 10;
  vertices[1].pos[1] := 10;
  vertices[1].pos[2] := 0;

  vertices[2].pos[0] := 20;
  vertices[2].pos[1] := 30;
  vertices[2].pos[2] := 0;

  vertices[0].color[0] := 1;
  vertices[0].color[1] := 1;
  vertices[0].color[2] := 1;
  vertices[0].color[3] := 1;

  vertices[1].color[0] := 1;
  vertices[1].color[1] := 1;
  vertices[1].color[2] := 1;
  vertices[1].color[3] := 1;

  vertices[2].color[0] := 1;
  vertices[2].color[1] := 1;
  vertices[2].color[2] := 1;
  vertices[2].color[3] := 1;


  m_d3dCanvas.DeviceContext.Map(m_pVertexBuffer, 0, D3D11_MAP_WRITE_DISCARD, 0, mappedResource);
  CopyMemory(mappedResource.pData, @vertices[0], SizeOf(vertices));
  m_d3dCanvas.DeviceContext.Unmap(m_pVertexBuffer, 0);

  pos := 0;

  m_d3dCanvas.DeviceContext.IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_LINESTRIP);
  m_d3dCanvas.DeviceContext.Draw(3, 0);
  m_d3dCanvas.Paint;
end;

//==============================================================================
procedure TMainForm.Render;
begin
  m_d3dCanvas.Clear(D3DColor4f(0.0, 0.0, 0.0, 1.0));
  m_d3dCanvas.DeviceContext.IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLESTRIP);


  m_d3dCanvas.DeviceContext.Draw(3, 0);
  m_d3dCanvas.Paint;
end;

//==============================================================================
procedure TMainForm.pnlD3dCanvasMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
begin
  Start;
  Draw;
end;

end.
