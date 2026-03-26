namespace D4P.CCMS.Nuget;

using D4P.CCMS.PTEApps;
codeunit 62010 "D4P BC NoDevOps Update" implements "D4P BC DevOps Update"
{
    Access = Internal;

    procedure GetNugetServiceTypeUrl(PTEApp: Record "D4P BC PTE App"; ServiceType: Text[100]): Text
    begin

    end;

    procedure GetNugetServiceURL(PTEApp: Record "D4P BC PTE App"): Text
    begin
    end;

    procedure GetToken(TokenName: Text[150]): SecretText
    begin
    end;

    procedure HasToken(TokenName: Text[150]): Boolean
    begin
        exit(false);
    end;

    procedure IsEnabled(): Boolean
    begin
        exit(false);
    end;

    procedure GetTokenKey(DevOpsOrganization: Record "D4P BC DevOps Organization"): Text
    begin
        exit('');
    end;
}