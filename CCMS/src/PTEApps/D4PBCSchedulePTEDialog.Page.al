namespace D4P.CCMS.PTEApps;

using D4P.CCMS.Environment;
using D4P.CCMS.Tenant;

page 62058 "D4P BC Schedule PTE Dialog"
{
    ApplicationArea = All;
    Caption = 'Schedule PTE Update';
    DataCaptionExpression = 'Schedule PTE Update';
    PageType = Card;
    Editable = true;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    LinksAllowed = false;

    layout
    {
        area(Content)
        {
            group(Environment)
            {
                Caption = 'Environment';
                Editable = not EnvironmentIsSet;

                field(EnvironmentName; SelectedEnvironmentName)
                {
                    Caption = 'Environment';
                    ToolTip = 'Specifies the environment where the PTE will be deployed.';
                    Editable = false;

                    trigger OnAssistEdit()
                    begin
                        if EnvironmentIsSet then
                            exit;
                        LookupEnvironment();
                    end;
                }
                field(CustomerName; SelectedCustomerName)
                {
                    Caption = 'Customer';
                    ToolTip = 'Specifies the customer associated with the environment.';
                    Editable = false;
                }
                field(TenantName; SelectedTenantName)
                {
                    Caption = 'Tenant';
                    ToolTip = 'Specifies the tenant associated with the environment.';
                    Editable = false;
                }
                field(TenantID; SelectedTenantID)
                {
                    Caption = 'Tenant ID';
                    ToolTip = 'Specifies the tenant ID associated with the environment.';
                    Editable = false;
                }
            }
            group(App)
            {
                Caption = 'PTE App';
                Editable = not AppIsSet;

                field(AppName; SelectedAppName)
                {
                    Caption = 'App';
                    ToolTip = 'Specifies the PTE app to deploy.';
                    Editable = false;

                    trigger OnAssistEdit()
                    begin
                        if AppIsSet then
                            exit;
                        LookupApp();
                    end;
                }

                field(AppVersion; SelectedVersion)
                {
                    Caption = 'Version';
                    ToolTip = 'Specifies the version to deploy.';

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        PTEAppVersion: Record "D4P BC PTE App Version";
                    begin
                        PTEAppVersion.SetRange("PTE ID", PTEAppContext."ID");
                        if Page.RunModal(Page::"D4P BC PTE App Version List", PTEAppVersion) = Action::LookupOK then
                            SelectedVersion := PTEAppVersion."App Version";
                    end;
                }
            }
            group(DependenciesGroup)
            {
                Caption = 'Dependencies';
                Visible = HasDependencies;

                field(InstallDependencies; InstallDependencies)
                {
                    Caption = 'Install Dependencies';
                    ToolTip = 'Specifies whether to also schedule the installation of dependency apps before this update.';
                }
                part(DependenciesPart; "D4P BC PTE App Dep. FactBox")
                {
                    Caption = '';
                }
            }
            group(Schedule)
            {
                Caption = 'Schedule';

                field(ScheduledDate; ScheduleDate)
                {
                    Caption = 'Date';
                    ToolTip = 'Specifies the date to run the update.';
                }
                field(ScheduledTime; ScheduleTime)
                {
                    Caption = 'Time';
                    ToolTip = 'Specifies the time to run the update.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ScheduleAction)
            {
                Caption = 'Schedule';
                Image = Planning;
                ToolTip = 'Confirm and schedule the PTE update.';
                trigger OnAction()
                begin
                    CreateScheduledUpdate();
                end;
            }
        }
        area(Promoted)
        {
            actionref(ScheduleActionPromoted; ScheduleAction)
            {
            }
        }
    }

    var
        EnvironmentContext: Record "D4P BC Environment";
        PTEAppContext: Record "D4P BC PTE App";
        AppIsSet: Boolean;
        EnvironmentIsSet: Boolean;
        ScheduleDate: Date;
        ScheduleTime: Time;
        SelectedAppName: Text[100];
        SelectedCustomerName: Text[100];
        SelectedEnvironmentName: Text[100];
        SelectedTenantID: Guid;
        SelectedTenantName: Text[100];
        SelectedVersion: Text[50];
        HasDependencies: Boolean;
        InstallDependencies: Boolean;

    trigger OnOpenPage()
    begin
        ScheduleDate := Today() + 1;
        ScheduleTime := 020000T;
    end;

    local procedure LookupEnvironment()
    var
        BCEnvironment: Record "D4P BC Environment";
    begin
        if Page.RunModal(Page::"D4P BC Environment List", BCEnvironment) = Action::LookupOK then begin
            EnvironmentContext := BCEnvironment;
            UpdateEnvironmentDisplay(BCEnvironment);
        end;
    end;

    local procedure LookupApp()
    var
        PTEApp: Record "D4P BC PTE App";
    begin
        if Page.RunModal(Page::"D4P BC PTE App List", PTEApp) = Action::LookupOK then begin
            PTEAppContext := PTEApp;
            SelectedAppName := PTEApp."Name";
            SelectedVersion := '';
            UpdateDependencies();
        end;
    end;

    local procedure UpdateEnvironmentDisplay(var BCEnvironment: Record "D4P BC Environment")
    var
        BCTenant: Record "D4P BC Tenant";
    begin
        SelectedEnvironmentName := BCEnvironment."Friendly Name";
        SelectedTenantID := BCEnvironment."Tenant ID";
        BCEnvironment.CalcFields("Customer Name");
        SelectedCustomerName := BCEnvironment."Customer Name";
        if BCTenant.Get(BCEnvironment."Customer No.", BCEnvironment."Tenant ID") then
            SelectedTenantName := BCTenant."Tenant Name"
        else
            SelectedTenantName := '';
    end;

    procedure SetEnvironment(var BCEnvironment: Record "D4P BC Environment")
    begin
        EnvironmentContext := BCEnvironment;
        UpdateEnvironmentDisplay(BCEnvironment);
        EnvironmentIsSet := true;
    end;

    procedure SetApp(var PTEApp: Record "D4P BC PTE App")
    begin
        PTEAppContext := PTEApp;
        SelectedAppName := PTEApp."Name";
        AppIsSet := true;
        UpdateDependencies();
    end;

    local procedure UpdateDependencies()
    var
        PTEAppDependency: Record "D4P BC PTE App Dependency";
    begin
        PTEAppDependency.SetRange("PTE ID", PTEAppContext."ID");
        HasDependencies := not PTEAppDependency.IsEmpty();
        CurrPage.DependenciesPart.Page.SetPTEApp(PTEAppContext."ID");
    end;

    local procedure CreateScheduledUpdate()
    var
        PTEUpdateScheduler: Codeunit "D4P BC PTE Update Scheduler";
    begin
        if PTEUpdateScheduler.CreateAndScheduleUpdate(EnvironmentContext, PTEAppContext, SelectedVersion, ScheduleDate, ScheduleTime, InstallDependencies) then
            CurrPage.Close();
    end;
}
