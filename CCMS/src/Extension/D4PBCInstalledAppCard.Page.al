namespace D4P.CCMS.Extension;

using D4P.CCMS.Environment;
using D4P.CCMS.PTEApps;

page 62024 "D4P BC Installed App Card"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = None;
    SourceTable = "D4P BC Installed App";
    Caption = 'D365BC Installed App';
    InsertAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("App ID"; Rec."App ID")
                {
                }
                field("App Name"; Rec."App Name")
                {
                    StyleExpr = UpdateAvailableStyleExpr;
                }
                field("App Publisher"; Rec."App Publisher")
                {
                }
                field("App Version"; Rec."App Version")
                {
                }
                field(State; Rec.State)
                {
                }
                field("App Type"; Rec."App Type")
                {
                }
            }
            group(Update)
            {
                Caption = 'Update';

                field("Last Update Attempt Result"; Rec."Last Update Attempt Result")
                {
                }
                field("Available Update Version"; Rec."Available Update Version")
                {
                    StyleExpr = UpdateAvailableStyleExpr;
                }
            }
            group(Install)
            {
                Caption = 'Install';

                field("Environment Name"; Rec."Environment Name")
                {
                }
                field("Can Be Uninstalled"; Rec."Can Be Uninstalled")
                {
                }
                field("Last Uninstall Attempt Result"; Rec."Last Uninstall Attempt Result")
                {
                }
            }
            part(ScheduledPTEUpdates; "D4P BC Sched. PTE Upd. Part")
            {
                Caption = 'Scheduled PTE Updates';
                SubPageLink = "Customer No." = field("Customer No."), "Tenant ID" = field("Tenant ID"), "Environment Name" = field("Environment Name"), "PTE App Name" = field("App Name");
                Editable = true;
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(GetInstalledApps)
            {
                Caption = 'Get Installed Apps';
                Image = Refresh;
                ToolTip = 'Get the list of installed apps for the selected environment.';
                trigger OnAction()
                var
                    BCEnvironment: Record "D4P BC Environment";
                    EnvironmentManagement: Codeunit "D4P BC Environment Mgt";
                begin
                    BCEnvironment.Get(Rec."Customer No.", Rec."Tenant ID", Rec."Environment Name");
                    EnvironmentManagement.GetInstalledApps(BCEnvironment);
                end;
            }
            action(GetAvailableUpdates)
            {
                Caption = 'Get Available Updates';
                Image = Refresh;
                ToolTip = 'Get the list of available apps updates for the selected environment.';
                trigger OnAction()
                var
                    BCEnvironment: Record "D4P BC Environment";
                    EnvironmentManagement: Codeunit "D4P BC Environment Mgt";
                begin
                    BCEnvironment.Get(Rec."Customer No.", Rec."Tenant ID", Rec."Environment Name");
                    EnvironmentManagement.GetAvailableAppUpdates(BCEnvironment, true);
                end;
            }
            action(UpdateApp)
            {
                Caption = 'Update App';
                Image = UpdateXML;
                ToolTip = 'Update the selected app to the latest version.';
                trigger OnAction()
                var
                    BCEnvironment: Record "D4P BC Environment";
                    EnvironmentManagement: Codeunit "D4P BC Environment Mgt";
                begin
                    BCEnvironment.Get(Rec."Customer No.", Rec."Tenant ID", Rec."Environment Name");
                    EnvironmentManagement.UpdateApp(BCEnvironment, Rec."App ID", false);
                end;
            }
            action(UploadAppFile)
            {
                Caption = 'Upload App File';
                Image = Import;
                ToolTip = 'Upload an .app file to install or update an extension on the environment.';
                trigger OnAction()
                var
                    BCEnvironment: Record "D4P BC Environment";
                    EnvironmentManagement: Codeunit "D4P BC Environment Mgt";
                begin
                    BCEnvironment.Get(Rec."Customer No.", Rec."Tenant ID", Rec."Environment Name");
                    EnvironmentManagement.UploadExtension(BCEnvironment);
                end;
            }
            action(UploadPTE)
            {
                Caption = 'Upload PTE';
                Image = UpdateXML;
                ToolTip = 'Select a PTE app and version from NuGet to upload and install on the environment.';
                trigger OnAction()
                var
                    BCEnvironment: Record "D4P BC Environment";
                    EnvironmentManagement: Codeunit "D4P BC Environment Mgt";
                begin
                    BCEnvironment.Get(Rec."Customer No.", Rec."Tenant ID", Rec."Environment Name");
                    EnvironmentManagement.UploadPTEExtension(BCEnvironment);
                end;
            }
            action(DeleteAll)
            {
                Caption = 'Delete All';
                Image = Delete;
                ToolTip = 'Delete all fetched installed apps records.';
                trigger OnAction()
                var
                    InstalledApp: Record "D4P BC Installed App";
                    RecordCount: Integer;
                    DeletedSuccessMsg: Label '%1 installed apps records deleted.', Comment = '%1 = Number of records';
                    DeleteMsg: Label 'Are you sure you want to delete all %1 fetched installed apps records?', Comment = '%1 = Number of records';
                begin
                    InstalledApp.CopyFilters(Rec);
                    RecordCount := InstalledApp.Count();
                    if RecordCount = 0 then
                        exit;

                    if Confirm(DeleteMsg, false, RecordCount) then begin
                        InstalledApp.DeleteAll();
                        CurrPage.Update(false);
                        Message(DeletedSuccessMsg, RecordCount);
                    end;
                end;
            }
        }
        area(Promoted)
        {
            actionref(GetInstalledAppsPromoted; GetInstalledApps)
            {
            }
            actionref(GetAvailableUpdatesPromoted; GetAvailableUpdates)
            {
            }
            actionref(UpdateAppPromoted; UpdateApp)
            {
            }
            actionref(UploadAppFilePromoted; UploadAppFile)
            {
            }
            actionref(UploadPTEPromoted; UploadPTE)
            {
            }
            actionref(DeleteAllPromoted; DeleteAll)
            {
            }
        }
    }

    var
        UpdateAvailableStyleExpr: Text;

    trigger OnAfterGetRecord()
    var
        BCEnvironment: Record "D4P BC Environment";
    begin
        // Set style for App Name and Available Update Version when update is available
        if Rec."Available Update Version" <> '' then
            UpdateAvailableStyleExpr := Format(PageStyle::Attention)
        else
            UpdateAvailableStyleExpr := Format(PageStyle::Standard);

        if BCEnvironment.Get(Rec."Customer No.", Rec."Tenant ID", Rec."Environment Name") then
            CurrPage.ScheduledPTEUpdates.Page.SetEnvironmentContext(BCEnvironment);
    end;
}