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
        ProcessPendingUpdates();
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

    procedure ProcessPendingUpdates()
    var
        ScheduledUpdate: Record "D4P BC Scheduled PTE Update";
    begin
        ScheduledUpdate.SetCurrentKey("Entry No.");
        ScheduledUpdate.SetAscending("Entry No.", true);
        ScheduledUpdate.SetRange(Status, ScheduledUpdate.Status::Pending);
        ScheduledUpdate.SetFilter("Scheduled DateTime", '<=%1', CurrentDateTime());
        if not ScheduledUpdate.FindSet() then
            exit;

        repeat
            ProcessSingleUpdate(ScheduledUpdate);
        until ScheduledUpdate.Next() = 0;
    end;

    procedure ProcessSingleUpdate(var ScheduledUpdate: Record "D4P BC Scheduled PTE Update")
    var
        BCEnvironment: Record "D4P BC Environment";
        PTEAppVersion: Record "D4P BC PTE App Version";
        NugetProcessing: Codeunit "D4P BC Nuget Processing";
        EnvironmentMgt: Codeunit "D4P BC Environment Mgt";
        TempBlob: Codeunit "Temp Blob";
        DataCompression: Codeunit "Data Compression";
        NupkgTempBlob: Codeunit "Temp Blob";
        NupkgInStream: InStream;
        AppOutStream: OutStream;
        EntryList: List of [Text];
        EntryName: Text;
        DependencyResult: Integer;
        DependencyFailedErr: Label 'A dependency update has failed or been cancelled. Check dependency entries: %1', Comment = '%1 = Entry Nos.';
    begin
        if ScheduledUpdate."Dependency Entry Nos." <> '' then begin
            DependencyResult := CheckDependenciesReady(ScheduledUpdate);
            case DependencyResult of
                1:
                    exit;
                2:
                    begin
                        FailUpdate(ScheduledUpdate, StrSubstNo(DependencyFailedErr, ScheduledUpdate."Dependency Entry Nos."));
                        exit;
                    end;
            end;
        end;

        ScheduledUpdate.Status := ScheduledUpdate.Status::"In Progress";
        ScheduledUpdate."Started On" := CurrentDateTime();
        ScheduledUpdate.Modify();
        Commit();

        if not BCEnvironment.Get(ScheduledUpdate."Customer No.", ScheduledUpdate."Tenant ID", ScheduledUpdate."Environment Name") then begin
            FailUpdate(ScheduledUpdate, 'Environment not found.');
            exit;
        end;

        if not PTEAppVersion.Get(ScheduledUpdate."PTE App ID", ScheduledUpdate."App Version") then begin
            FailUpdate(ScheduledUpdate, 'PTE App Version not found.');
            exit;
        end;

        if not NugetProcessing.DownloadPackageToStream(PTEAppVersion, NupkgTempBlob) then begin
            FailUpdate(ScheduledUpdate, 'Failed to download NuGet package.');
            exit;
        end;

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

        if not TempBlob.HasValue() then begin
            FailUpdate(ScheduledUpdate, 'No .app file found in NuGet package.');
            exit;
        end;

        if not TryDeployExtension(EnvironmentMgt, BCEnvironment, TempBlob) then begin
            FailUpdate(ScheduledUpdate, GetLastErrorText());
            exit;
        end;

        ScheduledUpdate.Status := ScheduledUpdate.Status::Completed;
        ScheduledUpdate."Completed On" := CurrentDateTime();
        ScheduledUpdate.Modify();
    end;

    [TryFunction]
    procedure TryDeployExtension(var EnvironmentMgt: Codeunit "D4P BC Environment Mgt"; var BCEnvironment: Record "D4P BC Environment"; var TempBlob: Codeunit "Temp Blob")
    begin
        EnvironmentMgt.DeployExtensionToEnvironment(BCEnvironment, TempBlob);
    end;

    procedure FailUpdate(var ScheduledUpdate: Record "D4P BC Scheduled PTE Update"; ErrorMsg: Text)
    begin
        ScheduledUpdate.Status := ScheduledUpdate.Status::Failed;
        ScheduledUpdate."Error Message" := CopyStr(ErrorMsg, 1, MaxStrLen(ScheduledUpdate."Error Message"));
        ScheduledUpdate."Completed On" := CurrentDateTime();
        ScheduledUpdate.Modify();
    end;

    internal procedure EnsureJobQueueExists()
    var
        JobQueueEntry: Record "Job Queue Entry";
        JobQueueDescLbl: Label 'CCMS - Process Scheduled PTE Updates';
    begin
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"D4P BC PTE Update Scheduler");
        if not JobQueueEntry.IsEmpty() then
            exit;

        JobQueueEntry.Init();
        JobQueueEntry.ID := CreateGuid();
        JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
        JobQueueEntry."Object ID to Run" := Codeunit::"D4P BC PTE Update Scheduler";
        JobQueueEntry.Description := JobQueueDescLbl;
        JobQueueEntry."Recurring Job" := true;
        JobQueueEntry."Run on Mondays" := true;
        JobQueueEntry."Run on Tuesdays" := true;
        JobQueueEntry."Run on Wednesdays" := true;
        JobQueueEntry."Run on Thursdays" := true;
        JobQueueEntry."Run on Fridays" := true;
        JobQueueEntry."Run on Saturdays" := true;
        JobQueueEntry."Run on Sundays" := true;
        JobQueueEntry."No. of Minutes between Runs" := 15;
        JobQueueEntry."Earliest Start Date/Time" := CurrentDateTime();
        JobQueueEntry.Insert(true);

        JobQueueEntry.SetStatus(JobQueueEntry.Status::Ready);
    end;

    procedure CancelScheduledUpdate(var ScheduledUpdate: Record "D4P BC Scheduled PTE Update")
    var
        CancelConfirmQst: Label 'Do you want to cancel the scheduled update for %1 v%2?', Comment = '%1 = App Name, %2 = Version';
        CancelledMsg: Label 'Scheduled update has been cancelled.';
        CannotCancelErr: Label 'Only pending updates can be cancelled.';
    begin
        if ScheduledUpdate.Status <> ScheduledUpdate.Status::Pending then
            Error(CannotCancelErr);
        if Confirm(CancelConfirmQst, false, ScheduledUpdate."PTE App Name", ScheduledUpdate."App Version") then begin
            ScheduledUpdate.Status := ScheduledUpdate.Status::Cancelled;
            ScheduledUpdate.Modify();
            Message(CancelledMsg);
        end;
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
            ScheduledUpdate.Status::Failed:
                exit(Format(PageStyle::Unfavorable));
            ScheduledUpdate.Status::Cancelled:
                exit(Format(PageStyle::Standard));
        end;
    end;

    procedure OpenJobQueueEntry()
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        EnsureJobQueueExists();
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"D4P BC PTE Update Scheduler");
        if JobQueueEntry.FindFirst() then
            Page.Run(Page::"Job Queue Entry Card", JobQueueEntry);
    end;

    procedure CreateAndScheduleUpdate(var BCEnvironment: Record "D4P BC Environment"; var PTEApp: Record "D4P BC PTE App"; AppVersion: Text[50]; ScheduleDate: Date; ScheduleTime: Time)
    begin
        CreateAndScheduleUpdate(BCEnvironment, PTEApp, AppVersion, ScheduleDate, ScheduleTime, false);
    end;

    procedure CreateAndScheduleUpdate(var BCEnvironment: Record "D4P BC Environment"; var PTEApp: Record "D4P BC PTE App"; AppVersion: Text[50]; ScheduleDate: Date; ScheduleTime: Time; IncludeDependencies: Boolean): Boolean
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
            DependencyEntryNos := ScheduleDependencies(BCEnvironment, PTEApp, ScheduledDateTime);
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
        ScheduledUpdate."Dependency Entry Nos." := DependencyEntryNos;
        ScheduledUpdate.Insert(true);

        EnsureJobQueueExists();
        if IncludeDependencies then
            Message(ScheduledWithDepsMsg, PTEApp."Name", AppVersion, ScheduledDateTime)
        else
            Message(ScheduledMsg, PTEApp."Name", AppVersion, ScheduledDateTime);
        exit(true);
    end;

    local procedure WarnIfHasDependencies(var PTEApp: Record "D4P BC PTE App"): Boolean
    var
        PTEAppDependency: Record "D4P BC PTE App Dependency";
        DependencyWarningQst: Label 'This app has dependencies that will not be installed. The update will fail if the target environment does not have the required dependencies and versions installed.\\\Do you want to continue?';
    begin
        PTEAppDependency.SetRange("PTE ID", PTEApp."ID");
        if PTEAppDependency.IsEmpty() then
            exit(true);

        exit(Confirm(DependencyWarningQst, false));
    end;

    local procedure ValidateDependenciesExist(var PTEApp: Record "D4P BC PTE App")
    var
        PTEAppDependency: Record "D4P BC PTE App Dependency";
        DepPTEApp: Record "D4P BC PTE App";
        DependencyNotFoundErr: Label 'Dependency ''%1'' is not registered in the PTE Apps list. Please add it before scheduling with dependencies.', Comment = '%1 = Dependency Package ID';
    begin
        PTEAppDependency.SetRange("PTE ID", PTEApp."ID");
        if not PTEAppDependency.FindSet() then
            exit;

        repeat
            DepPTEApp.SetRange("NuGet Package Name", PTEAppDependency."Dependency Package ID");
            if DepPTEApp.IsEmpty() then
                Error(DependencyNotFoundErr, PTEAppDependency."Dependency Package ID");
        until PTEAppDependency.Next() = 0;
    end;

    local procedure ScheduleDependencies(var BCEnvironment: Record "D4P BC Environment"; var PTEApp: Record "D4P BC PTE App"; ScheduledDateTime: DateTime): Text[250]
    var
        PTEAppDependency: Record "D4P BC PTE App Dependency";
        DepPTEApp: Record "D4P BC PTE App";
        ScheduledUpdate: Record "D4P BC Scheduled PTE Update";
        DependencyEntryNos: Text[250];
    begin
        PTEAppDependency.SetRange("PTE ID", PTEApp."ID");
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
            ScheduledUpdate."Scheduled DateTime" := ScheduledDateTime;
            ScheduledUpdate.Status := ScheduledUpdate.Status::Pending;
            ScheduledUpdate."Created On" := CurrentDateTime();
            ScheduledUpdate.Insert(true);

            if DependencyEntryNos <> '' then
                DependencyEntryNos += ',';
            DependencyEntryNos += Format(ScheduledUpdate."Entry No.");
        until PTEAppDependency.Next() = 0;

        exit(DependencyEntryNos);
    end;

    local procedure CheckDependenciesReady(ScheduledUpdate: Record "D4P BC Scheduled PTE Update"): Integer
    var
        DepUpdate: Record "D4P BC Scheduled PTE Update";
        EntryNoList: List of [Text];
        EntryNoText: Text;
        EntryNo: Integer;
        AllReady: Boolean;
        MinCompletionBufferMs: BigInteger;
    begin
        AllReady := true;
        MinCompletionBufferMs := 10 * 60 * 1000;
        EntryNoList := ScheduledUpdate."Dependency Entry Nos.".Split(',');

        foreach EntryNoText in EntryNoList do begin
            if Evaluate(EntryNo, EntryNoText.Trim()) then begin
                if not DepUpdate.Get(EntryNo) then
                    exit(2);

                case DepUpdate.Status of
                    DepUpdate.Status::Failed,
                    DepUpdate.Status::Cancelled:
                        exit(2);
                    DepUpdate.Status::Completed:
                        if (CurrentDateTime() - DepUpdate."Completed On") < MinCompletionBufferMs then
                            AllReady := false;
                    DepUpdate.Status::Pending,
                    DepUpdate.Status::"In Progress":
                        AllReady := false;
                end;
            end;
        end;

        if AllReady then
            exit(0)
        else
            exit(1);
    end;

    local procedure GetVersionFromRange(MinVersion: Text; var DepPTEApp: Record "D4P BC PTE App"): Text[50]
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
