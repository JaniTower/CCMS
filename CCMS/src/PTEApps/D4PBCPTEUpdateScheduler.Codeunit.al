namespace D4P.CCMS.PTEApps;

using D4P.CCMS.Environment;
using D4P.CCMS.Nuget;
using System.IO;
using System.Threading;
using System.Utilities;

codeunit 62053 "D4P BC PTE Update Scheduler"
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
    begin
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
    var
        ScheduledUpdate: Record "D4P BC Scheduled PTE Update";
        ScheduledMsg: Label 'PTE update for %1 v%2 has been scheduled for %3.', Comment = '%1 = App Name, %2 = Version, %3 = DateTime';
        NoEnvironmentErr: Label 'Please select an environment.';
        NoAppSelectedErr: Label 'Please select a PTE app.';
        NoVersionSelectedErr: Label 'Please select a version.';
        ScheduledDateTime: DateTime;
    begin
        if BCEnvironment.Name = '' then
            Error(NoEnvironmentErr);
        if IsNullGuid(PTEApp."ID") then
            Error(NoAppSelectedErr);
        if AppVersion = '' then
            Error(NoVersionSelectedErr);

        ScheduledDateTime := CreateDateTime(ScheduleDate, ScheduleTime);

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
        ScheduledUpdate.Insert(true);

        EnsureJobQueueExists();
        Message(ScheduledMsg, PTEApp."Name", AppVersion, ScheduledDateTime);
    end;
}
