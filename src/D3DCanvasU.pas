unit D3DCanvasU;

interface

uses

  Windows,
  Winapi.DXTypes,
  SysUtils,
  Math,
//  Direct3D,
//  D3D11,
//  DXGI,
//  D3DCommon,
//  D3DX10,
//  D3D10,
//  DxgiFormat,
//  DxgiType,
  D3DCompiler,
  D3DX11_JSB,
  D3D11_JSB,
  DXTypes_JSB,
  DXGI_JSB,
  D3DCommon_JSB;

type
  TD3DCanvasProperties = record
    Hwnd        : HWND;
    Width       : Integer;
    Height      : Integer;
    MSAA        : Integer;
  end;

  XMFLOAT3 = array [0..2] of Single;
  XMFLOAT4 = array[0..3] of Single;

  TSimpleVertex = record
    pos : XMFLOAT3;
    //color: XMFLOAT3;
  end;

  PSimpleVertex = ^TSimpleVertex;

  TD3DCanvas = class
  private
    m_cpProp : TD3DCanvasProperties;
  
    m_Device: ID3D11Device;
    m_DeviceContext: ID3D11DeviceContext;
    m_CurrentFeatureLevel: TD3D_FeatureLevel;
    m_Swapchain: IDXGISwapChain;
    m_RenderTargetView: ID3D11RenderTargetView;
    m_Viewport: TD3D11_VIEWPORT;

    m_DepthStencilBuffer: ID3D11Texture2D;
    m_DepthStencilState: ID3D11DepthStencilState;
    m_DepthStencilView: ID3D11DepthStencilView;
    m_RasterizerState: ID3D11RasterizerState;
  
    m_bInitialized : Boolean;

    procedure Init;
    procedure Reset;

  public
    constructor Create(a_cpProp : TD3DCanvasProperties);
    destructor Destroy; override;

    function CompileShader(szFilePath : LPCWSTR; szFunc : LPCSTR; szShaderModel : LPCSTR; buffer : ID3DBlob) : Boolean;

    procedure Clear(a_clColor: TColorArray);
    procedure Paint;

    property Device        : ID3D11Device        read m_Device        write m_Device;
    property DeviceContext : ID3D11DeviceContext read m_DeviceContext write m_DeviceContext;

  end;

  function D3DColor4f(a_dRed, a_dGreen, a_dBlue, a_dAlpha: Single): TColorArray; inline;
  function D3DColor4fARGB(a_ARGB: Cardinal): TColorArray; inline;

implementation

//==============================================================================
function D3DColor4f(a_dRed, a_dGreen, a_dBlue, a_dAlpha: Single): TColorArray;
begin
  Result[0] := a_dRed;
  Result[1] := a_dGreen;
  Result[2] := a_dBlue;
  Result[3] := a_dAlpha;
end;

//==============================================================================
function D3DColor4fARGB(a_ARGB: Cardinal): TColorArray;
begin
  Result[0] := Byte(a_ARGB shr 16) / 255;
  Result[1] := Byte(a_ARGB shr 8) / 255;
  Result[2] := Byte(a_ARGB) / 255;
  Result[3] := Byte(a_ARGB shr 24) / 255;
end;

//==============================================================================
constructor TD3DCanvas.Create(a_cpProp : TD3DCanvasProperties);
begin
  m_cpProp.Hwnd   := a_cpProp.Hwnd;
  m_cpProp.Width  := a_cpProp.Width;
  m_cpProp.Height := a_cpProp.Height;
  m_cpProp.MSAA   := a_cpProp.MSAA;

  m_bInitialized  := False;

  Init;
end;

//==============================================================================
destructor TD3DCanvas.Destroy;
begin
  Reset;
  Inherited;
end;

//==============================================================================
procedure TD3DCanvas.Clear(a_clColor: TColorArray);
begin
  m_DeviceContext.ClearRenderTargetView(m_RenderTargetView, a_clColor);
end;

//==============================================================================
procedure TD3DCanvas.Paint;
begin
  m_Swapchain.Present(0, 0);
end;

//==============================================================================
procedure TD3DCanvas.Reset;
begin
  if not m_bInitialized then
    Exit;

  m_DeviceContext    := nil;
  m_Device           := nil;
  m_RenderTargetView := nil;
  m_Swapchain        := nil;
  
  m_bInitialized     := False;
end;

//==============================================================================
procedure TD3DCanvas.Init;
var
  arrFeatureLevel : Array[0..2] of TD3D_FeatureLevel;
  Backbuffer      : ID3D11Texture2D;
  SwapchainDesc   : DXGI_SWAP_CHAIN_DESC;
  DepthDesc       : TD3D11_Texture2DDesc;
  DepthStateDesc  : TD3D11_DepthStencilDesc;
  DepthViewDesc   : TD3D11_DepthStencilViewDesc;
  RastStateDesc   : TD3D11_RasterizerDesc;

  flags : Cardinal;
begin
  if m_bInitialized then
    Reset;

  {$HINTS off}
  FillChar(SwapchainDesc, SizeOf(DXGI_SWAP_CHAIN_DESC), 0);
  {$HINTS on}
  with SwapchainDesc do
  begin
    BufferCount := 1;

    BufferDesc.Width := m_cpProp.Width;
    BufferDesc.Height := m_cpProp.Height;
    BufferDesc.Format := DXGI_FORMAT_R8G8B8A8_UNORM;
    BufferDesc.RefreshRate.Numerator := 60;
    BufferDesc.RefreshRate.Denominator := 1;
    BufferDesc.ScanlineOrdering := DXGI_MODE_SCANLINE_ORDER_UNSPECIFIED;
    BufferDesc.Scaling := DXGI_MODE_SCALING_STRETCHED;

    BufferUsage := DXGI_USAGE_RENDER_TARGET_OUTPUT;
    OutputWindow := m_cpProp.HWND;
    SampleDesc.Count := m_cpProp.MSAA;
    SampleDesc.Quality := Cardinal(D3D11_STANDARD_MULTISAMPLE_PATTERN);
    Windowed := True;

    SwapEffect := DXGI_SWAP_EFFECT_DISCARD;
    Flags := 0;
  end;

  arrFeatureLevel[0] :=  D3D_FEATURE_LEVEL_11_0;
  arrFeatureLevel[1] :=  D3D_FEATURE_LEVEL_10_1;
  arrFeatureLevel[2] :=  D3D_FEATURE_LEVEL_10_0;

  flags := Cardinal(D3D11_CREATE_DEVICE_DEBUG);

  try
    D3D11CreateDeviceAndSwapChain(
      nil,
      D3D_DRIVER_TYPE_HARDWARE,
      0,
      flags,
      @arrFeatureLevel,
      3,
      D3D11_SDK_VERSION,
      @SwapchainDesc,
      m_Swapchain,
      m_Device,
      @m_CurrentFeatureLevel,
      m_DeviceContext);

    m_Swapchain.GetBuffer(0, ID3D11Texture2D, Backbuffer);
    m_Device.CreateRenderTargetView(Backbuffer, nil, m_RenderTargetView);

    Backbuffer := nil;

    {$HINTS off}
    FillChar(DepthDesc, SizeOf(DepthDesc), 0);
    {$HINTS on}
    with DepthDesc do
    begin
      Width := m_cpProp.Width;
      Height := m_cpProp.Height;
      MipLevels := 1;
      ArraySize := 1;
      Format := DXGI_FORMAT_D24_UNORM_S8_UINT;
      SampleDesc.Count := m_cpProp.MSAA;
      SampleDesc.Quality := Cardinal(D3D11_STANDARD_MULTISAMPLE_PATTERN);
      Usage := D3D11_USAGE_DEFAULT;
      BindFlags := Ord(D3D11_BIND_DEPTH_STENCIL);
      CPUAccessFlags := 0;
      MiscFlags := 0;
    end;

    m_Device.CreateTexture2D(DepthDesc, nil, m_DepthStencilBuffer);

    {$HINTS off}
    FillChar(DepthStateDesc, SizeOf(DepthStateDesc), 0);
    {$HINTS on}
    with DepthStateDesc do
    begin
      DepthEnable := False;

      DepthWriteMask := D3D11_DEPTH_WRITE_MASK_ZERO;
      DepthFunc := D3D11_COMPARISON_LESS;

      StencilEnable := True;
      StencilReadMask := $FF;
      StencilWriteMask := $FF;

      FrontFace.StencilFailOp := D3D11_STENCIL_OP_KEEP;
      FrontFace.StencilDepthFailOp := D3D11_STENCIL_OP_INCR;
      FrontFace.StencilPassOp := D3D11_STENCIL_OP_KEEP;
      FrontFace.StencilFunc := D3D11_COMPARISON_ALWAYS;

      BackFace.StencilFailOp := D3D11_STENCIL_OP_KEEP;
      BackFace.StencilDepthFailOp := D3D11_STENCIL_OP_DECR;
      BackFace.StencilPassOp := D3D11_STENCIL_OP_KEEP;
      BackFace.StencilFunc := D3D11_COMPARISON_ALWAYS;
    end;

    m_Device.CreateDepthStencilState(DepthStateDesc, m_DepthStencilState);
    m_DeviceContext.OMSetDepthStencilState(m_DepthStencilState, 1);

    {$HINTS off}
    FillChar(DepthViewDesc, SizeOf(DepthViewDesc), 0);
    {$HINTS on}
    with DepthViewDesc do
    begin
      Format := DXGI_FORMAT_D24_UNORM_S8_UINT;
      if m_cpProp.MSAA = 1
        then ViewDimension := D3D11_DSV_DIMENSION_TEXTURE2D
        else ViewDimension := D3D11_DSV_DIMENSION_TEXTURE2DMS;
      Texture2D.MipSlice := 0;
    end;

    m_Device.CreateDepthStencilView(m_DepthStencilBuffer, @DepthViewDesc, m_DepthStencilView);
    m_DeviceContext.OMSetRenderTargets(1, @m_RenderTargetView, m_DepthStencilView);

    {$HINTS off}
    FillChar(RastStateDesc, SizeOf(RastStateDesc), 0);
    {$HINTS on}
    with RastStateDesc do
    begin
      AntialiasedLineEnable := True;
      CullMode := D3D11_CULL_BACK;
      DepthBias := 0;
      DepthBiasClamp := 0;
      DepthClipEnable := True;
      FillMode := D3D11_FILL_SOLID;
      FrontCounterClockwise := False;
      MultisampleEnable := True;
      ScissorEnable := False;
      SlopeScaledDepthBias := 0;
    end;

    m_Device.CreateRasterizerState(RastStateDesc, m_RasterizerState);
    m_DeviceContext.RSSetState(m_RasterizerState);

    {$HINTS off}
    FillChar(m_Viewport, SizeOf(m_Viewport), 0);
    {$HINTS on}
    with m_Viewport do 
    begin
      Width := m_cpProp.Width;
      Height := m_cpProp.Height;
      MinDepth := 0;
      MaxDepth := 1;
      TopLeftX := 0;
      TopLeftY := 0;
    end;

    m_DeviceContext.RSSetViewports(1, @m_Viewport);

  finally
    m_bInitialized := True;
  end;
end;

//==============================================================================
function TD3DCanvas.CompileShader(szFilePath : LPCWSTR; szFunc : LPCSTR; szShaderModel : LPCSTR; buffer : ID3DBlob) : Boolean;
var
  flags : DWORD;
  errBuffer : ID3DBlob;

  d3dMacro : TD3D_ShaderMacro;
  d3dInclude : ID3DInclude;
  d3dThreadPump : ID3DX11ThreadPump;

  hr : HRESULT;
begin
  flags := D3DCOMPILE_ENABLE_STRICTNESS or D3DCOMPILE_DEBUG;

  hr := D3DX11CompileFromFile(szFilePath, d3dMacro, d3dInclude, szFunc, szShaderModel, flags, 0, d3dThreadPump, buffer, errBuffer, 0);

  if errBuffer <> nil then
    errBuffer._Release;
end;

//==============================================================================
end.
