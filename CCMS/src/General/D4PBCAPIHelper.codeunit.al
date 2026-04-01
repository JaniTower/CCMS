namespace D4P.CCMS.General;

using D4P.CCMS.Setup;
using D4P.CCMS.Tenant;
using System.Security.Authentication;

codeunit 62049 "D4P BC API Helper" implements "D4P BC IApi Helper"
{
    Access = Internal;


    procedure SendAdminAPIRequest(var BCTenant: Record "D4P BC Tenant"; Method: Text; Endpoint: Text; RequestBody: Text; var ResponseText: Text): Boolean
    var
        HttpClient: HttpClient;
        RequestContent: HttpContent;
        Headers: HttpHeaders;
        HttpRequestMessage: HttpRequestMessage;
        HttpResponseMessage: HttpResponseMessage;
        FailedToObtainTokenErr: Label 'Failed to obtain access token for tenant %1.', Comment = '%1 - Tenant identifier';
        FailedToSendRequestErr: Label 'Failed to send HTTP request';
        AuthToken: SecretText;
        EndpointUrl: Text;
    begin
        AuthToken := GetOAuthToken(BCTenant);
        if AuthToken.IsEmpty() then
            Error(FailedToObtainTokenErr, BCTenant."Tenant ID".ToText().Replace('{', '').Replace('}', ''));

        EndpointUrl := GetAdminAPIBaseUrl() + Endpoint;

        HttpRequestMessage.SetRequestUri(EndpointUrl);
        HttpRequestMessage.Method := Method;
        HttpRequestMessage.GetHeaders(Headers);
        Headers.Add('Authorization', SecretStrSubstNo('Bearer %1', AuthToken));

        if RequestBody <> '' then begin
            RequestContent.WriteFrom(RequestBody);
            RequestContent.GetHeaders(Headers);
            Headers.Remove('Content-Type');
            Headers.Add('Content-Type', 'application/json');
            HttpRequestMessage.Content := RequestContent;
        end;

        if not HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then
            Error(FailedToSendRequestErr);

        HttpResponseMessage.Content().ReadAs(ResponseText);
        ShowDebugMessage(ResponseText, Method + ' ' + Endpoint);

        exit(HttpResponseMessage.IsSuccessStatusCode());
    end;

    procedure SendAdminAPIBinaryRequest(var BCTenant: Record "D4P BC Tenant"; Method: Text; Endpoint: Text; ContentInStream: InStream; var ResponseText: Text): Boolean
    var
        HttpClient: HttpClient;
        RequestContent: HttpContent;
        ContentHeaders: HttpHeaders;
        Headers: HttpHeaders;
        HttpRequestMessage: HttpRequestMessage;
        HttpResponseMessage: HttpResponseMessage;
        FailedToObtainTokenErr: Label 'Failed to obtain access token for tenant %1.', Comment = '%1 - Tenant identifier';
        FailedToSendRequestErr: Label 'Failed to send HTTP request';
        AuthToken: SecretText;
        EndpointUrl: Text;
    begin
        AuthToken := GetOAuthToken(BCTenant);
        if AuthToken.IsEmpty() then
            Error(FailedToObtainTokenErr, BCTenant."Tenant ID".ToText().Replace('{', '').Replace('}', ''));

        EndpointUrl := GetAdminAPIBaseUrl() + Endpoint;

        HttpRequestMessage.SetRequestUri(EndpointUrl);
        HttpRequestMessage.Method := Method;
        HttpRequestMessage.GetHeaders(Headers);
        Headers.Add('Authorization', SecretStrSubstNo('Bearer %1', AuthToken));

        RequestContent.WriteFrom(ContentInStream);
        RequestContent.GetHeaders(ContentHeaders);
        ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/octet-stream');
        HttpRequestMessage.Content := RequestContent;

        if not HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then
            Error(FailedToSendRequestErr);

        HttpResponseMessage.Content().ReadAs(ResponseText);
        ShowDebugMessage(StrSubstNo('HTTP %1 - %2', HttpResponseMessage.HttpStatusCode(), ResponseText), Method + ' ' + Endpoint);

        exit(HttpResponseMessage.IsSuccessStatusCode());
    end;

    procedure SendAutomationAPIRequest(AADTenantId: Guid; EnvironmentName: Text; Method: Text; Endpoint: Text; RequestBody: Text; AuthToken: SecretText; var ResponseText: Text): Boolean
    var
        HttpClient: HttpClient;
        RequestContent: HttpContent;
        Headers: HttpHeaders;
        HttpRequestMessage: HttpRequestMessage;
        HttpResponseMessage: HttpResponseMessage;
        FailedToConnectErr: Label 'Failed to connect to the API.';
        EndpointUrl: Text;
        TenantIdText: Text;
    begin
        TenantIdText := Format(AADTenantId);
        TenantIdText := DelChr(TenantIdText, '=', '{}');

        EndpointUrl := StrSubstNo('%1/%2/%3%4',
            GetAutomationAPIBaseUrl(),
            TenantIdText,
            EnvironmentName,
            Endpoint);

        HttpRequestMessage.SetRequestUri(EndpointUrl);
        HttpRequestMessage.Method := Method;
        HttpRequestMessage.GetHeaders(Headers);
        Headers.Add('Authorization', SecretStrSubstNo('Bearer %1', AuthToken));
        Headers.Add('Accept', 'application/json');

        if RequestBody <> '' then begin
            RequestContent.WriteFrom(RequestBody);
            RequestContent.GetHeaders(Headers);
            Headers.Remove('Content-Type');
            Headers.Add('Content-Type', 'application/json');
            HttpRequestMessage.Content := RequestContent;
        end;

        if not HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then
            Error(FailedToConnectErr);

        HttpResponseMessage.Content().ReadAs(ResponseText);
        ShowDebugMessage(ResponseText, Method + ' ' + Endpoint);

        exit(HttpResponseMessage.IsSuccessStatusCode());
    end;

    procedure SendAutomationAPIRequestWithETag(AADTenantId: Guid; EnvironmentName: Text; Method: Text; Endpoint: Text; RequestBody: Text; ETag: Text; AuthToken: SecretText; var ResponseText: Text): Boolean
    var
        HttpClient: HttpClient;
        RequestContent: HttpContent;
        Headers: HttpHeaders;
        HttpRequestMessage: HttpRequestMessage;
        HttpResponseMessage: HttpResponseMessage;
        FailedToConnectErr: Label 'Failed to connect to the API.';
        EndpointUrl: Text;
        TenantIdText: Text;
    begin
        TenantIdText := Format(AADTenantId);
        TenantIdText := DelChr(TenantIdText, '=', '{}');

        EndpointUrl := StrSubstNo('%1/%2/%3%4',
            GetAutomationAPIBaseUrl(),
            TenantIdText,
            EnvironmentName,
            Endpoint);

        HttpRequestMessage.SetRequestUri(EndpointUrl);
        HttpRequestMessage.Method := Method;
        HttpRequestMessage.GetHeaders(Headers);
        Headers.Add('Authorization', SecretStrSubstNo('Bearer %1', AuthToken));
        Headers.Add('Accept', 'application/json');
        if ETag <> '' then
            Headers.Add('If-Match', ETag);

        if RequestBody <> '' then begin
            RequestContent.WriteFrom(RequestBody);
            RequestContent.GetHeaders(Headers);
            Headers.Remove('Content-Type');
            Headers.Add('Content-Type', 'application/json');
            HttpRequestMessage.Content := RequestContent;
        end;

        if not HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then
            Error(FailedToConnectErr);

        HttpResponseMessage.Content().ReadAs(ResponseText);
        ShowDebugMessage(ResponseText, Method + ' ' + Endpoint);

        exit(HttpResponseMessage.IsSuccessStatusCode());
    end;

    procedure GetOAuthToken(var BCTenant: Record "D4P BC Tenant") AuthToken: SecretText
    var
        OAuth2: Codeunit OAuth2;
        FailedToGetTokenErr: Label 'Failed to get access token from response\%1', Comment = '%1 = Error response';
        Scopes: List of [Text];
        ClientSecret: SecretText;
        AccessTokenURL: Text;
        tenantID: Text;
    begin
        tenantID := BCTenant."Tenant ID".ToText().Replace('{', '');
        tenantID := tenantID.Replace('}', '');
        AccessTokenURL := 'https://login.microsoftonline.com/' + tenantID + '/oauth2/v2.0/token';
        Scopes.Add('https://api.businesscentral.dynamics.com/.default');

        ClientSecret := BCTenant.GetClientSecret();
        if not OAuth2.AcquireTokenWithClientCredentials(BCTenant."Client ID", ClientSecret, AccessTokenURL, '', Scopes, AuthToken) then
            Error(FailedToGetTokenErr, GetLastErrorText());
    end;

    procedure GetAutomationApiOAuthToken(AADTenantId: Guid; ClientID: Text; ClientSecret: SecretText) AuthToken: SecretText
    var
        OAuth2: Codeunit OAuth2;
        FailedToGetTokenErr: Label 'Failed to get Automation API access token: %1', Comment = '%1 = Error message';
        Scopes: List of [Text];
        AADTenantIdText: Text;
        AccessTokenURL: Text;
    begin
        AADTenantIdText := Format(AADTenantId);
        AADTenantIdText := DelChr(AADTenantIdText, '=', '{}');

        AccessTokenURL := 'https://login.microsoftonline.com/' + AADTenantIdText + '/oauth2/v2.0/token';

        Scopes.Add('https://api.businesscentral.dynamics.com/.default');

        if not OAuth2.AcquireTokenWithClientCredentials(ClientID, ClientSecret, AccessTokenURL, '', Scopes, AuthToken) then
            Error(FailedToGetTokenErr, GetLastErrorText());
    end;

    procedure SendAutomationAPIBinaryRequest(AADTenantId: Guid; EnvironmentName: Text; Method: Text; Endpoint: Text; ContentInStream: InStream; ETag: Text; AuthToken: SecretText; var ResponseText: Text): Boolean
    var
        HttpClient: HttpClient;
        RequestContent: HttpContent;
        ContentHeaders: HttpHeaders;
        Headers: HttpHeaders;
        HttpRequestMessage: HttpRequestMessage;
        HttpResponseMessage: HttpResponseMessage;
        FailedToConnectErr: Label 'Failed to connect to the API.';
        EndpointUrl: Text;
        TenantIdText: Text;
    begin
        TenantIdText := Format(AADTenantId);
        TenantIdText := DelChr(TenantIdText, '=', '{}');

        EndpointUrl := StrSubstNo('%1/%2/%3%4',
            GetAutomationAPIBaseUrl(),
            TenantIdText,
            EnvironmentName,
            Endpoint);

        HttpRequestMessage.SetRequestUri(EndpointUrl);
        HttpRequestMessage.Method := Method;
        HttpRequestMessage.GetHeaders(Headers);
        Headers.Add('Authorization', SecretStrSubstNo('Bearer %1', AuthToken));
        Headers.Add('Accept', 'application/json');
        if ETag <> '' then
            Headers.Add('If-Match', ETag);

        RequestContent.WriteFrom(ContentInStream);
        RequestContent.GetHeaders(ContentHeaders);
        ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/octet-stream');
        HttpRequestMessage.Content := RequestContent;

        if not HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then
            Error(FailedToConnectErr);

        HttpResponseMessage.Content().ReadAs(ResponseText);
        ShowDebugMessage(StrSubstNo('HTTP %1 - %2', HttpResponseMessage.HttpStatusCode(), ResponseText), Method + ' ' + Endpoint);

        exit(HttpResponseMessage.IsSuccessStatusCode());
    end;

    local procedure ShowDebugMessage(ResponseText: Text; ActionName: Text)
    var
        BCSetup: Record "D4P BC Setup";
        DebugMsg: Label 'DEBUG - %1:\%2', Comment = '%1 = Label, %2 = Message body';
    begin
        if BCSetup.Get() then
            if BCSetup."Debug Mode" then
                Message(DebugMsg, ActionName, ResponseText);
    end;

    local procedure GetAdminAPIBaseUrl(): Text[250]
    var
        BCSetup: Record "D4P BC Setup";
    begin
        exit(BCSetup.GetAdminAPIBaseUrl());
    end;

    local procedure GetAutomationAPIBaseUrl(): Text[250]
    var
        BCSetup: Record "D4P BC Setup";
    begin
        exit(BCSetup.GetAutomationAPIBaseUrl());
    end;
}
