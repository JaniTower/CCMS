namespace D4P.CCMS.PTEApps;

using D4P.CCMS.Environment;
using D4P.CCMS.Tenant;

page 62058 "D4P BC Schedule PTE Dialog"
{
    ApplicationArea = All;
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
                grid(DependenciesGrid)
                {
                    ShowCaption = false;
                    GridLayout = Columns;
                    group(group1)
                    {
                        ShowCaption = false;
                        field(InstallDependencies; InstallDependencies)
                        {
                            Caption = 'Install Dependencies';
                            ToolTip = 'Specifies whether to also schedule the installation of dependency apps before this update.';
                            trigger OnValidate()
                            begin
                                CurrPage.Update();
                            end;
                        }
                        field(DeployIntervalField; DeployIntervalMinutes)
                        {
                            Caption = 'Deploy Interval (min.)';
                            ToolTip = 'Specifies the number of minutes to wait between deploying dependencies and the main update.';
                            MinValue = 1;

                            trigger OnValidate()
                            begin
                                UpdateMainUpdateDateTime();
                            end;
                        }
                        field(MainUpdateAt; MainUpdateDateTime)
                        {
                            Caption = 'Main Update Scheduled At';
                            ToolTip = 'Specifies when the main update will be deployed, after the dependencies have been installed.';
                            Editable = false;
                        }
                    }
                    group(group2)
                    {
                        ShowCaption = false;
                        part(DependenciesPart; "D4P BC PTE App Dep. FactBox")
                        {
                            Caption = '';
                        }
                    }
                }
            }
            group(Schedule)
            {
                Caption = 'Schedule';

                field(ScheduledDate; ScheduleDate)
                {
                    Caption = 'Date';
                    ToolTip = 'Specifies the date to run the update.';

                    trigger OnValidate()
                    begin
                        UpdateMainUpdateDateTime();
                    end;
                }
                field(ScheduledTime; ScheduleTime)
                {
                    Caption = 'Time';
                    ToolTip = 'Specifies the time to run the update.';

                    trigger OnValidate()
                    begin
                        UpdateMainUpdateDateTime();
                    end;
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
        DeployIntervalMinutes: Integer;
        MainUpdateDateTime: DateTime;

    trigger OnOpenPage()
    begin
        ScheduleDate := Today() + 1;
        ScheduleTime := 020000T;
        DeployIntervalMinutes := 10;
        UpdateMainUpdateDateTime();
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

    local procedure UpdateMainUpdateDateTime()
    begin
        MainUpdateDateTime := CreateDateTime(ScheduleDate, ScheduleTime) + DeployIntervalMinutes * 60 * 1000;
    end;

    local procedure CreateScheduledUpdate()
    var
        PTEUpdateScheduler: Codeunit "D4P BC PTE Update Scheduler";
        ScheduledInPastErr: Label 'The scheduled time cannot be in the past. Please choose a later time.';
        MainDate: Date;
        MainTime: Time;
        Interval: Integer;
    begin
        if CreateDateTime(ScheduleDate, ScheduleTime) < CurrentDateTime() then
            Error(ScheduledInPastErr);

        if InstallDependencies and HasDependencies then begin
            MainDate := DT2Date(MainUpdateDateTime);
            MainTime := DT2Time(MainUpdateDateTime);
            Interval := DeployIntervalMinutes;
        end else begin
            MainDate := ScheduleDate;
            MainTime := ScheduleTime;
            Interval := 0;
        end;

        if PTEUpdateScheduler.CreateAndScheduleUpdate(EnvironmentContext, PTEAppContext, SelectedVersion, MainDate, MainTime, InstallDependencies, Interval) then
            CurrPage.Close();
    end;
}
