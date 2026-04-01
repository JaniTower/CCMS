namespace D4P.CCMS.PTEApps;

using D4P.CCMS.Environment;
using D4P.CCMS.Nuget;
using System.IO;
using System.Threading;
using System.Utilities;

codeunit 62007 "D4P BC PTE Update Scheduler"
{
    Access = Internal;
    TableNo = "Job Queue Entry";

    trigger OnRun()
    begin
        RunScheduledUpdate(Rec);
    end;

    procedure RunScheduledUpdate(var JobQueueEntry: Record "Job Queue Entry")
    var
        ScheduledUpdate: Record "D4P BC Scheduled PTE Update";
        EntryNo: Integer;
    begin
        if not Evaluate(EntryNo, JobQueueEntry."Parameter String") then
            exit;
        if not ScheduledUpdate.Get(EntryNo) then
            exit;
        if ScheduledUpdate.Status <> ScheduledUpdate.Status::Pending then
            exit;
        ProcessSingleUpdate(ScheduledUpdate);
    end;

    procedure ScheduleUpdate()
    var
        SchedulePTEDialog: Page "D4P BC Schedule PTE Dialog";
    begin
        SchedulePTEDialog.RunModal();
    end;

    procedure ScheduleUpdate(var BCEnvironment: Record "D4P BC Environment")
    var
        SchedulePTEDialog: Page "D4P BC Schedule PTE Dialog";
    begin
        SchedulePTEDialog.SetEnvironment(BCEnvironment);
        SchedulePTEDialog.RunModal();
    end;

    procedure ScheduleUpdate(var BCEnvironment: Record "D4P BC Environment"; PTEAppName: Text[100])
    var
        PTEApp: Record "D4P BC PTE App";
        SchedulePTEDialog: Page "D4P BC Schedule PTE Dialog";
        AppNotFoundErr: Label 'PTE app %1 not found.', Comment = '%1 = App Name';
    begin
        PTEApp.SetRange("Name", PTEAppName);
        if not PTEApp.FindFirst() then
            Error(AppNotFoundErr, PTEAppName);

        SchedulePTEDialog.SetEnvironment(BCEnvironment);
        SchedulePTEDialog.SetApp(PTEApp);
        SchedulePTEDialog.RunModal();
    end;

    procedure ProcessSingleUpdate(var ScheduledUpdate: Record "D4P BC Scheduled PTE Update")
    var
        BCEnvironment: Record "D4P BC Environment";
        PTEAppVersion: Record "D4P BC PTE App Version";
        NugetProcessing: Codeunit "D4P BC Nuget Processing";
        EnvironmentMgt: Codeunit "D4P BC Environment Mgt";
        DeployVerifier: Codeunit "D4P BC PTE Deploy Verifier";
        TempBlob: Codeunit "Temp Blob";
        NupkgTempBlob: Codeunit "Temp Blob";
        EnvironmentNotFoundErr: Label 'Environment not found.';
        AppVersionNotFoundErr: Label 'PTE App Version not found.';
        DownloadFailedErr: Label 'Failed to download NuGet package.';
        NoAppFileErr: Label 'No .app file found in NuGet package.';
    begin
        ScheduledUpdate.Status := ScheduledUpdate.Status::"In Progress";
        ScheduledUpdate."Started On" := CurrentDateTime();
        ScheduledUpdate.Modify();
        Commit();

        if not BCEnvironment.Get(ScheduledUpdate."Customer No.", ScheduledUpdate."Tenant ID", ScheduledUpdate."Environment Name") then begin
            FailUpdate(ScheduledUpdate, EnvironmentNotFoundErr);
            exit;
        end;

        if not PTEAppVersion.Get(ScheduledUpdate."PTE App ID", ScheduledUpdate."App Version") then begin
            FailUpdate(ScheduledUpdate, AppVersionNotFoundErr);
            exit;
        end;

        if not NugetProcessing.DownloadPackageToStream(PTEAppVersion, NupkgTempBlob) then begin
            FailUpdate(ScheduledUpdate, DownloadFailedErr);
            exit;
        end;

        TempBlob := ExtractAppFromPackage(NupkgTempBlob);
        if not TempBlob.HasValue() then begin
            FailUpdate(ScheduledUpdate, NoAppFileErr);
            exit;
        end;

        if not TryDeployExtension(EnvironmentMgt, BCEnvironment, TempBlob) then begin
            FailUpdate(ScheduledUpdate, GetLastErrorText());
            exit;
        end;

        ScheduledUpdate."Deployed On" := CurrentDateTime();
        ScheduledUpdate."Verification Attempts" := 0;
        ScheduledUpdate."Error Message" := '';
        ScheduledUpdate.Status := ScheduledUpdate.Status::Processed;
        ScheduledUpdate.Modify();

        DeployVerifier.EnsureVerificationJobQueueExists();
    end;

    procedure ExtractAppFromPackage(var NupkgTempBlob: Codeunit "Temp Blob"): Codeunit "Temp Blob"
    var
        TempBlob: Codeunit "Temp Blob";
        DataCompression: Codeunit "Data Compression";
        NupkgInStream: InStream;
        AppOutStream: OutStream;
        EntryList: List of [Text];
        EntryName: Text;
    begin
        NupkgTempBlob.CreateInStream(NupkgInStream);
        DataCompression.OpenZipArchive(NupkgInStream, false);
        DataCompression.GetEntryList(EntryList);

        TempBlob.CreateOutStream(AppOutStream);
        foreach EntryName in EntryList do
            if EntryName.EndsWith('.app') then begin
                DataCompression.ExtractEntry(EntryName, AppOutStream);
                break;
            end;
        DataCompression.CloseZipArchive();
        exit(TempBlob);
    end;

    [TryFunction]
    procedure TryDeployExtension(var EnvironmentMgt: Codeunit "D4P BC Environment Mgt"; var BCEnvironment: Record "D4P BC Environment"; var TempBlob: Codeunit "Temp Blob")
    begin
        EnvironmentMgt.DeployExtensionToEnvironment(BCEnvironment, TempBlob);
    end;

    procedure FailUpdate(var ScheduledUpdate: Record "D4P BC Scheduled PTE Update"; ErrorMsg: Text)
    var
        Notifier: Codeunit "D4P BC PTE Update Notifier";
    begin
        ScheduledUpdate.Status := ScheduledUpdate.Status::Failed;
        ScheduledUpdate."Error Message" := CopyStr(ErrorMsg, 1, MaxStrLen(ScheduledUpdate."Error Message"));
        ScheduledUpdate."Completed On" := CurrentDateTime();
        ScheduledUpdate.Modify();
        Notifier.SendCompletionNotification(ScheduledUpdate);
    end;

    procedure CreateJobQueueEntry(var ScheduledUpdate: Record "D4P BC Scheduled PTE Update")
    var
        JobQueueEntry: Record "Job Queue Entry";
        JobQueueDescLbl: Label 'CCMS - PTE Update #%1: %2 v%3', Comment = '%1 = Entry No., %2 = App Name, %3 = Version';
    begin
        JobQueueEntry.Init();
        JobQueueEntry.ID := CreateGuid();
        JobQueueEntry.Status := JobQueueEntry.Status::"On Hold";
        JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
        JobQueueEntry."Object ID to Run" := Codeunit::"D4P BC PTE Update Scheduler";
        JobQueueEntry.Description := CopyStr(StrSubstNo(JobQueueDescLbl, ScheduledUpdate."Entry No.", ScheduledUpdate."PTE App Name", ScheduledUpdate."App Version"), 1, MaxStrLen(JobQueueEntry.Description));
        JobQueueEntry."Recurring Job" := false;
        JobQueueEntry."Earliest Start Date/Time" := ScheduledUpdate."Scheduled DateTime";
        JobQueueEntry."Parameter String" := Format(ScheduledUpdate."Entry No.");
        JobQueueEntry."Maximum No. of Attempts to Run" := 3;
        JobQueueEntry.Insert(true);
        JobQueueEntry.SetStatus(JobQueueEntry.Status::Ready);

        ScheduledUpdate."Job Queue Entry ID" := JobQueueEntry.ID;
        ScheduledUpdate.Modify();
    end;

    procedure OpenJobQueueEntryForUpdate(var ScheduledUpdate: Record "D4P BC Scheduled PTE Update")
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        if IsNullGuid(ScheduledUpdate."Job Queue Entry ID") then
            exit;
        if JobQueueEntry.Get(ScheduledUpdate."Job Queue Entry ID") then
            Page.Run(Page::"Job Queue Entry Card", JobQueueEntry);
    end;

    procedure CancelScheduledUpdate(var ScheduledUpdate: Record "D4P BC Scheduled PTE Update")
    var
        CancelConfirmQst: Label 'Do you want to cancel the scheduled update for %1 v%2?', Comment = '%1 = App Name, %2 = Version';
        CancelWithDepsConfirmQst: Label 'Do you want to cancel the scheduled update for %1 v%2 and its dependencies?', Comment = '%1 = App Name, %2 = Version';
        CancelledMsg: Label 'Scheduled update has been cancelled.';
        CancelledWithDepsMsg: Label 'Scheduled update and its dependencies have been cancelled.';
        CannotCancelErr: Label 'Only pending updates can be cancelled.';
        HasDependencies: Boolean;
    begin
        if ScheduledUpdate.Status <> ScheduledUpdate.Status::Pending then
            Error(CannotCancelErr);

        HasDependencies := ScheduledUpdate."Dependency Entry Nos." <> '';
        if HasDependencies then begin
            if not Confirm(CancelWithDepsConfirmQst, false, ScheduledUpdate."PTE App Name", ScheduledUpdate."App Version") then
                exit;
        end else
            if not Confirm(CancelConfirmQst, false, ScheduledUpdate."PTE App Name", ScheduledUpdate."App Version") then
                exit;

        if HasDependencies then
            CancelDependencyUpdates(ScheduledUpdate);

        CancelSingleUpdate(ScheduledUpdate);

        if HasDependencies then
            Message(CancelledWithDepsMsg)
        else
            Message(CancelledMsg);
    end;

    procedure CancelSingleUpdate(var ScheduledUpdate: Record "D4P BC Scheduled PTE Update")
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        if not IsNullGuid(ScheduledUpdate."Job Queue Entry ID") then begin
            if JobQueueEntry.Get(ScheduledUpdate."Job Queue Entry ID") then
                JobQueueEntry.Delete(true);
            Clear(ScheduledUpdate."Job Queue Entry ID");
        end;
        ScheduledUpdate.Status := ScheduledUpdate.Status::Cancelled;
        ScheduledUpdate.Modify();
    end;

    procedure CancelDependencyUpdates(ScheduledUpdate: Record "D4P BC Scheduled PTE Update")
    var
        DepUpdate: Record "D4P BC Scheduled PTE Update";
        EntryNoList: List of [Text];
        EntryNoText: Text;
        EntryNo: Integer;
    begin
        EntryNoList := ScheduledUpdate."Dependency Entry Nos.".Split(',');
        foreach EntryNoText in EntryNoList do
            if Evaluate(EntryNo, EntryNoText.Trim()) then
                if DepUpdate.Get(EntryNo) then
                    if DepUpdate.Status = DepUpdate.Status::Pending then
                        CancelSingleUpdate(DepUpdate);
    end;

    procedure GetStatusStyleExpr(ScheduledUpdate: Record "D4P BC Scheduled PTE Update"): Text
    begin
        case ScheduledUpdate.Status of
            ScheduledUpdate.Status::Pending:
                exit(Format(PageStyle::Ambiguous));
            ScheduledUpdate.Status::"In Progress":
                exit(Format(PageStyle::AttentionAccent));
            ScheduledUpdate.Status::Completed:
                exit(Format(PageStyle::Favorable));
            ScheduledUpdate.Status::Processed:
                exit(Format(PageStyle::StrongAccent));
            ScheduledUpdate.Status::Failed:
                exit(Format(PageStyle::Unfavorable));
            ScheduledUpdate.Status::Cancelled:
                exit(Format(PageStyle::Standard));
        end;
    end;

    procedure CreateAndScheduleUpdate(var BCEnvironment: Record "D4P BC Environment"; var PTEApp: Record "D4P BC PTE App"; AppVersion: Text[50]; ScheduleDate: Date; ScheduleTime: Time)
    begin
        CreateAndScheduleUpdate(BCEnvironment, PTEApp, AppVersion, ScheduleDate, ScheduleTime, false, 0, '');
    end;

    procedure CreateAndScheduleUpdate(var BCEnvironment: Record "D4P BC Environment"; var PTEApp: Record "D4P BC PTE App"; AppVersion: Text[50]; ScheduleDate: Date; ScheduleTime: Time; IncludeDependencies: Boolean; DeployIntervalMinutes: Integer; DependencyFilter: Text): Boolean
    var
        ScheduledUpdate: Record "D4P BC Scheduled PTE Update";
        ScheduledMsg: Label 'PTE update for %1 v%2 has been scheduled for %3.', Comment = '%1 = App Name, %2 = Version, %3 = DateTime';
        ScheduledWithDepsMsg: Label 'PTE update for %1 v%2 and its dependencies have been scheduled for %3.', Comment = '%1 = App Name, %2 = Version, %3 = DateTime';
        NoEnvironmentErr: Label 'Please select an environment.';
        NoAppSelectedErr: Label 'Please select a PTE app.';
        NoVersionSelectedErr: Label 'Please select a version.';
        ScheduledDateTime: DateTime;
        DependencyEntryNos: Text[250];
    begin
        if BCEnvironment.Name = '' then
            Error(NoEnvironmentErr);
        if IsNullGuid(PTEApp."ID") then
            Error(NoAppSelectedErr);
        if AppVersion = '' then
            Error(NoVersionSelectedErr);

        ScheduledDateTime := CreateDateTime(ScheduleDate, ScheduleTime);

        if IncludeDependencies then begin
            ValidateDependenciesExist(PTEApp);
            DependencyEntryNos := ScheduleDependencies(BCEnvironment, PTEApp, ScheduledDateTime, DeployIntervalMinutes, DependencyFilter);
        end else
            if not WarnIfHasDependencies(PTEApp) then
                exit(false);

        ScheduledUpdate.Init();
        ScheduledUpdate."Customer No." := BCEnvironment."Customer No.";
        ScheduledUpdate."Tenant ID" := BCEnvironment."Tenant ID";
        ScheduledUpdate."Environment Name" := BCEnvironment.Name;
        ScheduledUpdate."PTE App ID" := PTEApp."ID";
        ScheduledUpdate."PTE App Name" := PTEApp."Name";
        ScheduledUpdate."App Version" := AppVersion;
        ScheduledUpdate."Scheduled DateTime" := ScheduledDateTime;
        ScheduledUpdate.Status := ScheduledUpdate.Status::Pending;
        ScheduledUpdate."Created On" := CurrentDateTime();
        ScheduledUpdate."Scheduled By" := CopyStr(UserId(), 1, MaxStrLen(ScheduledUpdate."Scheduled By"));
        ScheduledUpdate."Dependency Entry Nos." := DependencyEntryNos;
        ScheduledUpdate.Insert(true);

        CreateJobQueueEntry(ScheduledUpdate);
        if IncludeDependencies then
            Message(ScheduledWithDepsMsg, PTEApp."Name", AppVersion, ScheduledDateTime)
        else
            Message(ScheduledMsg, PTEApp."Name", AppVersion, ScheduledDateTime);
        exit(true);
    end;

    procedure WarnIfHasDependencies(var PTEApp: Record "D4P BC PTE App"): Boolean
    var
        PTEAppDependency: Record "D4P BC PTE App Dependency";
        DependencyWarningQst: Label 'This app has dependencies that will not be installed. The update will fail if the target environment does not have the required dependencies and versions installed.\\\Do you want to continue?';
    begin
        PTEAppDependency.SetRange("PTE ID", PTEApp."ID");
        if PTEAppDependency.IsEmpty() then
            exit(true);

        exit(Confirm(DependencyWarningQst, false));
    end;

    procedure ValidateDependenciesExist(var PTEApp: Record "D4P BC PTE App")
    var
        PTEAppDependency: Record "D4P BC PTE App Dependency";
        DepPTEApp: Record "D4P BC PTE App";
        DependencyNotFoundErr: Label 'Dependency ''%1'' is not registered in the PTE Apps list. Please add it before scheduling with dependencies.', Comment = '%1 = Dependency Package ID';
    begin
        PTEAppDependency.SetRange("PTE ID", PTEApp."ID");
        PTEAppDependency.SetLoadFields("Dependency Package ID");
        if not PTEAppDependency.FindSet() then
            exit;

        repeat
            DepPTEApp.SetRange("NuGet Package Name", PTEAppDependency."Dependency Package ID");
            if DepPTEApp.IsEmpty() then
                Error(DependencyNotFoundErr, PTEAppDependency."Dependency Package ID");
        until PTEAppDependency.Next() = 0;
    end;

    procedure ScheduleDependencies(var BCEnvironment: Record "D4P BC Environment"; var PTEApp: Record "D4P BC PTE App"; ScheduledDateTime: DateTime; DeployIntervalMinutes: Integer; DependencyFilter: Text): Text[250]
    var
        PTEAppDependency: Record "D4P BC PTE App Dependency";
        DepPTEApp: Record "D4P BC PTE App";
        ScheduledUpdate: Record "D4P BC Scheduled PTE Update";
        DependencyEntryNos: Text[250];
        DependencyDateTime: DateTime;
    begin
        DependencyDateTime := ScheduledDateTime - DeployIntervalMinutes * 60 * 1000;

        PTEAppDependency.SetRange("PTE ID", PTEApp."ID");
        if DependencyFilter <> '' then
            PTEAppDependency.SetFilter("Dependency Package ID", DependencyFilter);
        PTEAppDependency.SetLoadFields("Dependency Package ID", "Version Range");
        if not PTEAppDependency.FindSet() then
            exit('');

        repeat
            DepPTEApp.SetLoadFields("ID", "Name");
            DepPTEApp.SetRange("NuGet Package Name", PTEAppDependency."Dependency Package ID");
            if not DepPTEApp.FindFirst() then
                continue;

            ScheduledUpdate.Init();
            ScheduledUpdate."Customer No." := BCEnvironment."Customer No.";
            ScheduledUpdate."Tenant ID" := BCEnvironment."Tenant ID";
            ScheduledUpdate."Environment Name" := BCEnvironment.Name;
            ScheduledUpdate."PTE App ID" := DepPTEApp."ID";
            ScheduledUpdate."PTE App Name" := DepPTEApp."Name";
            ScheduledUpdate."App Version" := GetVersionFromRange(PTEAppDependency."Version Range", DepPTEApp);
            ScheduledUpdate."Scheduled DateTime" := DependencyDateTime;
            ScheduledUpdate.Status := ScheduledUpdate.Status::Pending;
            ScheduledUpdate."Created On" := CurrentDateTime();
            ScheduledUpdate."Scheduled By" := CopyStr(UserId(), 1, MaxStrLen(ScheduledUpdate."Scheduled By"));
            ScheduledUpdate.Insert(true);
            CreateJobQueueEntry(ScheduledUpdate);

            if DependencyEntryNos <> '' then
                DependencyEntryNos += ',';
            DependencyEntryNos += Format(ScheduledUpdate."Entry No.");
        until PTEAppDependency.Next() = 0;

        exit(DependencyEntryNos);
    end;

    procedure GetVersionFromRange(MinVersion: Text; var DepPTEApp: Record "D4P BC PTE App"): Text[50]
    var
        PTEAppVersion: Record "D4P BC PTE App Version";
        NoMatchingVersionErr: Label 'Dependency ''%1'' requires minimum version %2, but no matching version was found. Please run "Get Latest Versions" on that app first.', Comment = '%1 = App Name, %2 = Min Version';
    begin
        PTEAppVersion.SetLoadFields("App Version", "Version Sort Key");
        PTEAppVersion.SetRange("PTE ID", DepPTEApp."ID");
        PTEAppVersion.SetCurrentKey("PTE ID", "Version Sort Key");
        PTEAppVersion.SetAscending("Version Sort Key", false);
        if MinVersion <> '' then
            PTEAppVersion.SetFilter("Version Sort Key", '>=%1', PTEAppVersion.ComputeSortKey(MinVersion));
        if PTEAppVersion.FindFirst() then
            exit(PTEAppVersion."App Version");

        Error(NoMatchingVersionErr, DepPTEApp."Name", MinVersion);
    end;
}
