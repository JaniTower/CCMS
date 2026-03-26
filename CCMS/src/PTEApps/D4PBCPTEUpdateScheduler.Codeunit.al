namespace D4P.CCMS.PTEApps;

using D4P.CCMS.Environment;
using D4P.CCMS.Nuget;
using System.IO;
using System.Threading;
using System.Utilities;

codeunit 62053 "D4P BC PTE Update Scheduler"
{
    TableNo = "Job Queue Entry";

    trigger OnRun()
    begin
        ProcessPendingUpdates();
    end;

    procedure ScheduleUpdate(var BCEnvironment: Record "D4P BC Environment")
    var
        PTEApp: Record "D4P BC PTE App";
        PTEAppVersion: Record "D4P BC PTE App Version";
        ScheduledUpdate: Record "D4P BC Scheduled PTE Update";
        SchedulePTEDialog: Page "D4P BC Schedule PTE Dialog";
        SelectAppErr: Label 'No PTE app selected.';
        SelectVersionErr: Label 'No version selected.';
        ScheduledMsg: Label 'PTE update for %1 v%2 has been scheduled for %3.', Comment = '%1 = App Name, %2 = Version, %3 = DateTime';
        ScheduledDateTime: DateTime;
    begin
        // 1. Select PTE App
        if Page.RunModal(Page::"D4P BC PTE App List", PTEApp) <> Action::LookupOK then
            Error(SelectAppErr);

        // 2. Select Version
        PTEAppVersion.SetRange("PTE ID", PTEApp."ID");
        if Page.RunModal(Page::"D4P BC PTE App Version List", PTEAppVersion) <> Action::LookupOK then
            Error(SelectVersionErr);

        // 3. Pick date/time
        SchedulePTEDialog.RunModal();
        ScheduledDateTime := SchedulePTEDialog.GetScheduledDateTime();
        if ScheduledDateTime = 0DT then
            exit;

        // 4. Create scheduled update record
        ScheduledUpdate.Init();
        ScheduledUpdate."Customer No." := BCEnvironment."Customer No.";
        ScheduledUpdate."Tenant ID" := BCEnvironment."Tenant ID";
        ScheduledUpdate."Environment Name" := BCEnvironment.Name;
        ScheduledUpdate."PTE App ID" := PTEApp."ID";
        ScheduledUpdate."PTE App Name" := PTEApp."Name";
        ScheduledUpdate."App Version" := PTEAppVersion."App Version";
        ScheduledUpdate."Scheduled DateTime" := ScheduledDateTime;
        ScheduledUpdate.Status := ScheduledUpdate.Status::Pending;
        ScheduledUpdate."Created On" := CurrentDateTime();
        ScheduledUpdate.Insert(true);

        EnsureJobQueueExists();
        Message(ScheduledMsg, PTEApp."Name", PTEAppVersion."App Version", ScheduledDateTime);
    end;

    local procedure ProcessPendingUpdates()
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

    local procedure ProcessSingleUpdate(var ScheduledUpdate: Record "D4P BC Scheduled PTE Update")
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

        // Download .nupkg
        if not NugetProcessing.DownloadPackageToStream(PTEAppVersion, NupkgTempBlob) then begin
            FailUpdate(ScheduledUpdate, 'Failed to download NuGet package.');
            exit;
        end;

        // Extract .app from .nupkg
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

        // Deploy to environment
        if not TryDeployExtension(EnvironmentMgt, BCEnvironment, TempBlob) then begin
            FailUpdate(ScheduledUpdate, GetLastErrorText());
            exit;
        end;

        ScheduledUpdate.Status := ScheduledUpdate.Status::Completed;
        ScheduledUpdate."Completed On" := CurrentDateTime();
        ScheduledUpdate.Modify();
    end;

    [TryFunction]
    local procedure TryDeployExtension(var EnvironmentMgt: Codeunit "D4P BC Environment Mgt"; var BCEnvironment: Record "D4P BC Environment"; var TempBlob: Codeunit "Temp Blob")
    begin
        EnvironmentMgt.DeployExtensionToEnvironment(BCEnvironment, TempBlob);
    end;

    local procedure FailUpdate(var ScheduledUpdate: Record "D4P BC Scheduled PTE Update"; ErrorMsg: Text)
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
        JobQueueEntry."No. of Minutes between Runs" := 15;
        JobQueueEntry."Earliest Start Date/Time" := CurrentDateTime();
        JobQueueEntry.Insert(true);

        JobQueueEntry.SetStatus(JobQueueEntry.Status::Ready);
    end;
}
