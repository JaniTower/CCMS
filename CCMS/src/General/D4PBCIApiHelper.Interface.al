namespace D4P.CCMS.General;

interface "D4P BC IApi Helper"
{
    Access = Internal;

    procedure GetAutomationApiOAuthToken(AADTenantId: Guid; ClientID: Text; ClientSecret: SecretText): SecretText;
    procedure SendAutomationAPIRequest(AADTenantId: Guid; EnvironmentName: Text; Method: Text; Endpoint: Text; RequestBody: Text; AuthToken: SecretText; var ResponseText: Text): Boolean;
}
