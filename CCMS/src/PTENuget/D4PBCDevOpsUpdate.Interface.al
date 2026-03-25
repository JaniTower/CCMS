namespace D4P.CCMS.Nuget;

using D4P.CCMS.PTEApps;
interface "D4P BC DevOps Update"
{
    procedure IsEnabled(): Boolean;
    procedure HasToken(TokenName: Text[150]): Boolean;
    procedure GetToken(TokenName: Text[150]): SecretText;
    procedure GetNugetServiceURL(PTEApp: Record "D4P BC PTE App"): Text;
    procedure GetNugetServiceTypeUrl(PTEApp: Record "D4P BC PTE App"; ServiceType: Text[100]): Text;
    procedure GetTokenKey(DevOpsOrganization: Record "D4P BC DevOps Organization"): Text;
}