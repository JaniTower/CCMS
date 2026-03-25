namespace D4P.CCMS.Nuget;

using D4P.CCMS.PTEApps;
using D4P.CCMS.Setup;
using System.RestClient;
codeunit 62008 "D4P BC Nuget Processing"
{
    procedure GetPTEAppVersions(var PTEApp: Record "D4P BC PTE App")
    var
        BCDevOpsUpdate: Interface "D4P BC DevOps Update";
        ServiceTypeUrl: Text;
        ServiceType: Label 'SearchQueryService', Locked = true;
    begin
        DevOpsUpdateFactory(BCDevOpsUpdate, PTEApp."DevOps Environment");
        if not BCDevOpsUpdate.IsEnabled() then
            exit;
        ServiceTypeUrl := BCDevOpsUpdate.GetNugetServiceTypeUrl(PTEApp, ServiceType);
        if ServiceTypeUrl = '' then
            exit;
        GetAppVersions(PTEApp, BCDevOpsUpdate, ServiceTypeUrl);
    end;

    local procedure DevOpsUpdateFactory(var BCDevOpsUpdateInterface: Interface "D4P BC DevOps Update"; BCDevOpsEnvironments: Enum "D4P BC DevOps Environment")
    begin
        BCDevOpsUpdateInterface := BCDevOpsEnvironments;
    end;

    local procedure GetAppVersions(var PTEApp: Record "D4P BC PTE App"; BCDevOpsUpdate: Interface "D4P BC DevOps Update"; ServiceTypeUrl: Text)
    var
        RestClient: Codeunit "Rest Client";
        JsonToken: JsonToken;
        SearchURLLbl: Label '%1?q=%2', Locked = true, Comment = '%1 is Service Type URL, %2 is Package Name';
        SearchURL: Text;
        TokenKey: Text[150];
        ResponseText: Text;
    begin
        if (ServiceTypeUrl = '') or (PTEApp."NuGet Package Name" = '') then
            exit;
        TokenKey := StrSubstNo('%1-%2', PTEApp."DevOps Environment".AsInteger(), UpperCase(PTEApp."DevOps Organization"));
        if BCDevOpsUpdate.HasToken(TokenKey) then
            RestClient.SetAuthorizationHeader(BCDevOpsUpdate.GetToken(TokenKey));
        SearchURL := StrSubstNo(SearchURLLbl, ServiceTypeUrl, PTEApp."NuGet Package Name");
        ResponseText := RestClient.Get(SearchURL).GetContent().AsText();
        ShowDebugMessage(ResponseText, 'NuGet Package Search');
        JsonToken.ReadFrom(ResponseText);
        ProcessVersions(JsonToken, PTEApp, BCDevOpsUpdate);
    end;

    local procedure ProcessVersions(JsonToken: JsonToken; var PTEApp: Record "D4P BC PTE App"; var BCDevOpsUpdate: Interface "D4P BC DevOps Update")
    var
        JsonArray: JsonArray;
        TotalHits: Integer;
        PTEAppVersion: Record "D4P BC PTE App Version";
        PackageNotFoundLbl: Label 'Package ''%1'' was not found in the feed. Please verify the NuGet Package Name.', Comment = '%1 is the package name';
        PackageAmbiguousLbl: Label 'Package ''%1'' matched %2 results. Please use a more specific NuGet Package Name.', Comment = '%1 is the package name, %2 is the number of results';
    begin
        if not JsonToken.IsObject() then
            exit;
        TotalHits := JsonToken.AsObject().GetInteger('totalHits');
        if TotalHits = 0 then begin
            Message(PackageNotFoundLbl, PTEApp."NuGet Package Name");
            exit;
        end;
        if TotalHits > 1 then begin
            Message(PackageAmbiguousLbl, PTEApp."NuGet Package Name", TotalHits);
            exit;
        end;
        JsonArray := JsonToken.AsObject().GetArray('data');
        JsonArray.Get(0, JsonToken);

        if JsonToken.AsObject().Contains('version') then begin
            PTEApp."Latest App Version" := JsonToken.AsObject().GetText('version');
            PTEApp.Modify(true);
        end;

        JsonArray := JsonToken.AsObject().GetArray('versions');
        foreach JsonToken in JsonArray do begin

            PTEAppVersion.Init();
            PTEAppVersion."PTE ID" := PTEApp."ID";
            PTEAppVersion."App Version" := JsonToken.AsObject().GetText('version');
            PTEAppVersion."Version Sort Key" := PTEAppVersion.ComputeSortKey(PTEAppVersion."App Version");
            PTEAppVersion."Package Content Url" := GetPackageContentUrl(PTEApp, PTEAppVersion, JsonToken.AsObject().GetText('@id'), BCDevOpsUpdate);
            if PTEAppVersion.DoExists() then
                PTEAppVersion.Modify(true)
            else
                PTEAppVersion.Insert(true);
        end;
    end;

    procedure GetPackageContentUrl(PTEApp: Record "D4P BC PTE App"; PTEAppVersion: Record "D4P BC PTE App Version"; PackageVersionUrl: Text; BCDevOpsUpdate: Interface "D4P BC DevOps Update"): Text
    var
        RestClient: Codeunit "Rest Client";
        JsonToken: JsonToken;
        TokenKey: Text[150];
        ResponseText: Text;
    begin
        TokenKey := StrSubstNo('%1-%2', PTEApp."DevOps Environment".AsInteger(), UpperCase(PTEApp."DevOps Organization"));
        if BCDevOpsUpdate.HasToken(TokenKey) then
            RestClient.SetAuthorizationHeader(BCDevOpsUpdate.GetToken(TokenKey));
        ResponseText := RestClient.Get(PackageVersionUrl).GetContent().AsText();
        ShowDebugMessage(ResponseText, 'NuGet Package Version Metadata');
        JsonToken.ReadFrom(ResponseText);
        if not JsonToken.IsObject() then
            exit('');
        if JsonToken.AsObject().Contains('packageContent') then
            exit(JsonToken.AsObject().GetText('packageContent'));
        exit('');
    end;

    procedure DownloadPackageContent(PTEAppVersion: Record "D4P BC PTE App Version"): Boolean
    var
        BCDevOpsUpdate: Interface "D4P BC DevOps Update";
        PTEApp: Record "D4P BC PTE App";
        RestClient: Codeunit "Rest Client";
        Response: Codeunit "HTTP Response Message";
        Instream: InStream;
        FileName: Text;
        TokenKey: Text[150];
        DownloadDialogTitleLbl: Label 'Download App Package';
    begin
        if not PTEApp.Get(PTEAppVersion."PTE ID") then
            exit(false);

        DevOpsUpdateFactory(BCDevOpsUpdate, PTEAppVersion.GetPTEAppDevOps());
        TokenKey := StrSubstNo('%1-%2', PTEApp."DevOps Environment".AsInteger(), UpperCase(PTEApp."DevOps Organization"));
        if BCDevOpsUpdate.HasToken(TokenKey) then
            RestClient.SetAuthorizationHeader(BCDevOpsUpdate.GetToken(TokenKey));
        Response := RestClient.Get(PTEAppVersion."Package Content Url");
        ShowDebugMessage(StrSubstNo('HTTP %1 - %2', Response.GetHttpStatusCode(), PTEAppVersion."Package Content Url"), 'NuGet Package Download');
        if not Response.GetIsSuccessStatusCode() then
            exit(false);
        Instream := Response.GetContent().AsInStream();
        FileName := SanitizeFileName(PTEAppVersion.GetPTEAppName() + '_' + PTEAppVersion."App Version" + '.nupkg');
        exit(DownloadFromStream(Instream, DownloadDialogTitleLbl, '', '', FileName));
    end;


    procedure TestConnection(DevOpsOrganization: Record "D4P BC DevOps Organization"): Boolean
    var
        RestClient: Codeunit "Rest Client";
        BCDevOpsUpdate: Interface "D4P BC DevOps Update";
        PTEApp: Record "D4P BC PTE App";
        Response: Codeunit "HTTP Response Message";
        TokenKey: Text;
    begin
        DevOpsUpdateFactory(BCDevOpsUpdate, DevOpsOrganization."DevOps Environment");
        if not BCDevOpsUpdate.IsEnabled() then
            exit(false);

        PTEApp.Init();
        PTEApp."DevOps Environment" := DevOpsOrganization."DevOps Environment";
        PTEApp."DevOps Organization" := DevOpsOrganization.ID;

        TokenKey := DevOpsOrganization.GetTokenKey();
        if BCDevOpsUpdate.HasToken(TokenKey) then
            RestClient.SetAuthorizationHeader(BCDevOpsUpdate.GetToken(TokenKey));
        Response := RestClient.Get(BCDevOpsUpdate.GetNugetServiceURL(PTEApp));
        exit(Response.GetIsSuccessStatusCode());
    end;

    local procedure ShowDebugMessage(ResponseText: Text; ActionName: Text)
    var
        BCSetup: Record "D4P BC Setup";
        DebugMsg: Label 'DEBUG - %1 Response:\%2', Comment = '%1 = Action name, %2 = Response body';
    begin
        if BCSetup.Get() then
            if BCSetup."Debug Mode" then
                Message(DebugMsg, ActionName, ResponseText);
    end;

    local procedure SanitizeFileName(UnsafeFileName: Text): Text
    var
        SafeFileName: Text;
    begin
        SafeFileName := UnsafeFileName.Trim();
        SafeFileName := DelChr(SafeFileName, '=', '\/:*?"<>|');

        while StrPos(SafeFileName, '..') > 0 do
            SafeFileName := SafeFileName.Replace('..', '.');

        if SafeFileName = '' then
            exit('PTEAppPackage.app');

        exit(SafeFileName);
    end;

}