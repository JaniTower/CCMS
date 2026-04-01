namespace D4P.CCMS.PTEApps;

using D4P.CCMS.Environment;
using D4P.CCMS.General;
using D4P.CCMS.Setup;
using D4P.CCMS.Tenant;
using System.Threading;

codeunit 62019 "D4P BC PTE Deploy Verifier"
{
    Access = Internal;
    TableNo = "Job Queue Entry";

    trigger OnRun()
    begin
        VerifyAllProcessedUpdates();
    end;

    procedure VerifyAllProcessedUpdates()
    var
        ScheduledUpdate: Record "D4P BC Scheduled PTE Update";
        BCEnvironment: Record "D4P BC Environment";
        LastCustomerNo: Code[20];
        LastTenantId: Guid;
        LastEnvironmentName: Text[30];
    begin
        ScheduledUpdate.SetCurrentKey("Customer No.", "Tenant ID", "Environment Name", "Scheduled DateTime");
        ScheduledUpdate.SetRange(Status, ScheduledUpdate.Status::Processed);
        if not ScheduledUpdate.FindSet() then
            exit;

        repeat
            if (ScheduledUpdate."Customer No." <> LastCustomerNo) or
               (ScheduledUpdate."Tenant ID" <> LastTenantId) or
               (ScheduledUpdate."Environment Name" <> LastEnvironmentName)
            then begin
                LastCustomerNo := ScheduledUpdate."Customer No.";
                LastTenantId := ScheduledUpdate."Tenant ID";
                LastEnvironmentName := ScheduledUpdate."Environment Name";
                if BCEnvironment.Get(LastCustomerNo, LastTenantId, LastEnvironmentName) then
                    if not TryVerifyEnvironmentDeployments(BCEnvironment, LastCustomerNo, LastTenantId, LastEnvironmentName) then;
            end;
        until ScheduledUpdate.Next() = 0;
    end;

    [TryFunction]
    local procedure TryVerifyEnvironmentDeployments(var BCEnvironment: Record "D4P BC Environment"; CustomerNo: Code[20]; TenantId: Guid; EnvironmentName: Text[30])
    var
        ScheduledUpdate: Record "D4P BC Scheduled PTE Update";
        BCTenant: Record "D4P BC Tenant";
        DeploymentStatuses: JsonArray;
        EntryNos: List of [Integer];
        EntryNo: Integer;
    begin
        if not BCTenant.Get(BCEnvironment."Customer No.", BCEnvironment."Tenant ID") then
            exit;

        DeploymentStatuses := GetDeploymentStatuses(BCEnvironment, BCTenant);

        ScheduledUpdate.SetRange(Status, ScheduledUpdate.Status::Processed);
        ScheduledUpdate.SetRange("Customer No.", CustomerNo);
        ScheduledUpdate.SetRange("Tenant ID", TenantId);
        ScheduledUpdate.SetRange("Environment Name", EnvironmentName);
        if not ScheduledUpdate.FindSet() then
            exit;
        repeat
            EntryNos.Add(ScheduledUpdate."Entry No.");
        until ScheduledUpdate.Next() = 0;

        foreach EntryNo in EntryNos do
            if ScheduledUpdate.Get(EntryNo) then
                if ScheduledUpdate.Status = ScheduledUpdate.Status::Processed then
                    MatchAndUpdateStatus(ScheduledUpdate, DeploymentStatuses);
    end;

    local procedure MatchAndUpdateStatus(var ScheduledUpdate: Record "D4P BC Scheduled PTE Update"; DeploymentStatuses: JsonArray)
    var
        MatchedStatus: Text;
        MatchedOperationId: Guid;
    begin
        if not IsNullGuid(ScheduledUpdate."Operation ID") then
            MatchedStatus := FindStatusByOperationId(ScheduledUpdate."Operation ID", DeploymentStatuses)
        else begin
            MatchedStatus := FindStatusByNameAndVersion(ScheduledUpdate, DeploymentStatuses, MatchedOperationId);
            if not IsNullGuid(MatchedOperationId) then begin
                ScheduledUpdate."Operation ID" := MatchedOperationId;
                ScheduledUpdate.Modify();
            end;
        end;

        ApplyMatchedStatus(ScheduledUpdate, MatchedStatus);
    end;

    local procedure FindStatusByOperationId(OperationId: Guid; DeploymentStatuses: JsonArray): Text
    var
        JToken: JsonToken;
        JObject: JsonObject;
        EntryOperationIdText: Text;
        EntryOperationId: Guid;
        i: Integer;
    begin
        for i := 0 to DeploymentStatuses.Count() - 1 do begin
            DeploymentStatuses.Get(i, JToken);
            JObject := JToken.AsObject();

            JObject.Get('operationID', JToken);
            EntryOperationIdText := JToken.AsValue().AsText();
            if Evaluate(EntryOperationId, EntryOperationIdText) then
                if EntryOperationId = OperationId then begin
                    JObject.Get('status', JToken);
                    exit(JToken.AsValue().AsText());
                end;
        end;

        exit('');
    end;

    local procedure FindStatusByNameAndVersion(var ScheduledUpdate: Record "D4P BC Scheduled PTE Update"; DeploymentStatuses: JsonArray; var FoundOperationId: Guid): Text
    var
        JToken: JsonToken;
        JObject: JsonObject;
        EntryName: Text;
        EntryVersion: Text;
        EntryOperationIdText: Text;
        EntryStartedOnText: Text;
        EntryStartedOn: DateTime;
        BestMatchStartedOn: DateTime;
        BestMatchStatus: Text;
        i: Integer;
    begin
        BestMatchStartedOn := 0DT;
        BestMatchStatus := '';
        Clear(FoundOperationId);

        for i := 0 to DeploymentStatuses.Count() - 1 do begin
            DeploymentStatuses.Get(i, JToken);
            JObject := JToken.AsObject();

            JObject.Get('name', JToken);
            EntryName := JToken.AsValue().AsText();
            JObject.Get('appVersion', JToken);
            EntryVersion := JToken.AsValue().AsText();

            if (EntryName = ScheduledUpdate."PTE App Name") and
               VersionsMatch(EntryVersion, ScheduledUpdate."App Version")
            then begin
                JObject.Get('startedOn', JToken);
                EntryStartedOnText := JToken.AsValue().AsText();
                if Evaluate(EntryStartedOn, EntryStartedOnText) then
                    if EntryStartedOn > BestMatchStartedOn then begin
                        BestMatchStartedOn := EntryStartedOn;
                        JObject.Get('status', JToken);
                        BestMatchStatus := JToken.AsValue().AsText();
                        JObject.Get('operationID', JToken);
                        EntryOperationIdText := JToken.AsValue().AsText();
                        if not Evaluate(FoundOperationId, EntryOperationIdText) then
                            Clear(FoundOperationId);
                    end;
            end;
        end;

        exit(BestMatchStatus);
    end;

    local procedure VersionsMatch(ApiVersion: Text; StoredVersion: Text): Boolean
    begin
        if ApiVersion = StoredVersion then
            exit(true);
        if ApiVersion.StartsWith(StoredVersion + '.') then
            exit(true);
        if StoredVersion.StartsWith(ApiVersion + '.') then
            exit(true);
        exit(false);
    end;

    local procedure ApplyMatchedStatus(var ScheduledUpdate: Record "D4P BC Scheduled PTE Update"; MatchedStatus: Text)
    var
        MaxVerificationAttempts: Integer;
        TimeoutErrMsg: Label 'Deployment verification timed out after %1 attempts. The deployment result is unknown.', Comment = '%1 = Attempts';
    begin
        MaxVerificationAttempts := 30;

        if MatchedStatus = 'Completed' then begin
            ScheduledUpdate.Status := ScheduledUpdate.Status::Completed;
            ScheduledUpdate."Completed On" := CurrentDateTime();
            ScheduledUpdate.Modify();
            exit;
        end;

        if MatchedStatus = 'Failed' then begin
            ScheduledUpdate.Status := ScheduledUpdate.Status::Failed;
            ScheduledUpdate."Error Message" := 'Extension deployment failed on the remote environment.';
            ScheduledUpdate."Completed On" := CurrentDateTime();
            ScheduledUpdate.Modify();
            exit;
        end;

        ScheduledUpdate."Verification Attempts" += 1;
        if ScheduledUpdate."Verification Attempts" > MaxVerificationAttempts then begin
            ScheduledUpdate.Status := ScheduledUpdate.Status::Failed;
            ScheduledUpdate."Error Message" := CopyStr(StrSubstNo(TimeoutErrMsg, MaxVerificationAttempts), 1, MaxStrLen(ScheduledUpdate."Error Message"));
            ScheduledUpdate."Completed On" := CurrentDateTime();
        end;
        ScheduledUpdate.Modify();
    end;

    procedure VerifySingleUpdate(var ScheduledUpdate: Record "D4P BC Scheduled PTE Update")
    var
        BCEnvironment: Record "D4P BC Environment";
        BCTenant: Record "D4P BC Tenant";
        DeploymentStatuses: JsonArray;
        NotProcessedErr: Label 'This entry has status %1. Only entries with status Processed can be verified.', Comment = '%1 = Status';
        EnvironmentNotFoundErr: Label 'Environment %1 not found.', Comment = '%1 = Environment Name';
        CompletedMsg: Label 'Deployment verified: installation completed successfully.';
        FailedMsg: Label 'Deployment verified: installation failed on the remote environment.';
        InProgressMsg: Label 'Deployment is still in progress on the remote environment. Verification attempt %1 of 30.', Comment = '%1 = Attempt count';
        NotFoundMsg: Label 'No matching deployment found yet on the remote environment. Verification attempt %1 of 30.', Comment = '%1 = Attempt count';
    begin
        if ScheduledUpdate.Status <> ScheduledUpdate.Status::Processed then
            Error(NotProcessedErr, ScheduledUpdate.Status);

        if not BCEnvironment.Get(ScheduledUpdate."Customer No.", ScheduledUpdate."Tenant ID", ScheduledUpdate."Environment Name") then
            Error(EnvironmentNotFoundErr, ScheduledUpdate."Environment Name");

        BCTenant.Get(BCEnvironment."Customer No.", BCEnvironment."Tenant ID");

        DeploymentStatuses := GetDeploymentStatuses(BCEnvironment, BCTenant);

        MatchAndUpdateStatus(ScheduledUpdate, DeploymentStatuses);
        ScheduledUpdate.Get(ScheduledUpdate."Entry No.");

        case ScheduledUpdate.Status of
            ScheduledUpdate.Status::Completed:
                Message(CompletedMsg);
            ScheduledUpdate.Status::Failed:
                Message(FailedMsg);
            ScheduledUpdate.Status::Processed:
                if IsNullGuid(ScheduledUpdate."Operation ID") then
                    Message(NotFoundMsg, ScheduledUpdate."Verification Attempts")
                else
                    Message(InProgressMsg, ScheduledUpdate."Verification Attempts");
        end;
    end;

    local procedure GetDeploymentStatuses(var BCEnvironment: Record "D4P BC Environment"; var BCTenant: Record "D4P BC Tenant"): JsonArray
    var
        APIHelper: Codeunit "D4P BC API Helper";
        JObject: JsonObject;
        JToken: JsonToken;
        JArray: JsonArray;
        AuthToken: SecretText;
        ResponseText: Text;
        CompanyId: Text;
        FailedToObtainTokenErr: Label 'Failed to obtain authentication token.';
        FailedToGetCompaniesErr: Label 'Failed to get companies for environment %1.', Comment = '%1 = Environment Name';
        FailedToGetStatusErr: Label 'Failed to get deployment status for environment %1.', Comment = '%1 = Environment Name';
        NoCompaniesErr: Label 'No companies found in environment %1.', Comment = '%1 = Environment Name';
    begin
        AuthToken := APIHelper.GetAutomationApiOAuthToken(BCEnvironment."AAD Tenant ID", BCTenant."Client ID", BCTenant.GetClientSecret());
        if AuthToken.IsEmpty() then
            Error(FailedToObtainTokenErr);

        if not APIHelper.SendAutomationAPIRequest(
            BCEnvironment."AAD Tenant ID", BCEnvironment.Name,
            'GET', '/api/microsoft/automation/v2.0/companies', '',
            AuthToken, ResponseText)
        then
            Error(FailedToGetCompaniesErr, BCEnvironment.Name);

        JObject.ReadFrom(ResponseText);
        JObject.Get('value', JToken);
        JArray := JToken.AsArray();
        if JArray.Count() = 0 then
            Error(NoCompaniesErr, BCEnvironment.Name);
        JArray.Get(0, JToken);
        JObject := JToken.AsObject();
        JObject.Get('id', JToken);
        CompanyId := JToken.AsValue().AsText();

        Clear(JObject);
        if not APIHelper.SendAutomationAPIRequest(
            BCEnvironment."AAD Tenant ID", BCEnvironment.Name,
            'GET',
            StrSubstNo('/api/microsoft/automation/v2.0/companies(%1)/extensionDeploymentStatus', CompanyId),
            '', AuthToken, ResponseText)
        then
            Error(FailedToGetStatusErr, BCEnvironment.Name);

        ShowDebugMessage(ResponseText, 'GetDeploymentStatuses - Raw API Response');

        JObject.ReadFrom(ResponseText);
        JObject.Get('value', JToken);
        exit(JToken.AsArray());
    end;

    procedure EnsureVerificationJobQueueExists()
    var
        JobQueueEntry: Record "Job Queue Entry";
        JobQueueDescLbl: Label 'CCMS - PTE Deployment Verification';
    begin
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"D4P BC PTE Deploy Verifier");
        JobQueueEntry.SetFilter(Status, '%1|%2', JobQueueEntry.Status::Ready, JobQueueEntry.Status::"In Process");
        if not JobQueueEntry.IsEmpty() then
            exit;

        JobQueueEntry.Init();
        JobQueueEntry.ID := CreateGuid();
        JobQueueEntry.Status := JobQueueEntry.Status::"On Hold";
        JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
        JobQueueEntry."Object ID to Run" := Codeunit::"D4P BC PTE Deploy Verifier";
        JobQueueEntry.Description := JobQueueDescLbl;
        JobQueueEntry."Recurring Job" := true;
        JobQueueEntry."No. of Minutes between Runs" := 2;
        JobQueueEntry.Insert(true);
        JobQueueEntry.SetStatus(JobQueueEntry.Status::Ready);
    end;

    local procedure ShowDebugMessage(ResponseText: Text; ActionName: Text)
    var
        BCSetup: Record "D4P BC Setup";
        DebugMsg: Label 'DEBUG - %1:\%2', Comment = '%1 = Context, %2 = Message body';
    begin
        if BCSetup.Get() then
            if BCSetup."Debug Mode" then
                Message(DebugMsg, ActionName, ResponseText);
    end;
}
