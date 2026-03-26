namespace D4P.CCMS.PTEApps;

using D4P.CCMS.Environment;
using System.Threading;

page 62060 "D4P BC Sched. PTE Upd. Part"
{
    ApplicationArea = All;
    Caption = 'Scheduled PTE Updates';
    PageType = ListPart;
    SourceTable = "D4P BC Scheduled PTE Update";
    SourceTableView = sorting("Entry No.") order(descending);
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("App Version"; Rec."App Version")
                {
                }
                field("Scheduled DateTime"; Rec."Scheduled DateTime")
                {
                }
                field(Status; Rec.Status)
                {
                    StyleExpr = StatusStyleExpr;
                }
                field("Completed On"; Rec."Completed On")
                {
                }
                field("Error Message"; Rec."Error Message")
                {
                }
                field("Dependency Entry Nos."; Rec."Dependency Entry Nos.")
                {
                    Visible = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(CancelUpdate)
            {
                Caption = 'Cancel';
                Image = Cancel;
                ToolTip = 'Cancel the selected scheduled update.';
                trigger OnAction()
                var
                    PTEUpdateScheduler: Codeunit "D4P BC PTE Update Scheduler";
                begin
                    PTEUpdateScheduler.CancelScheduledUpdate(Rec);
                end;
            }

            action(ScheduleUpdate)
            {
                Caption = 'Schedule Update';
                Image = Planning;
                ToolTip = 'Schedule a PTE app update to run at a specific date and time.';
                trigger OnAction()
                var
                    PTEUpdateScheduler: Codeunit "D4P BC PTE Update Scheduler";
                begin
                    PTEUpdateScheduler.ScheduleUpdate(EnvironmentContext, PTEAppNameContext);
                    CurrPage.Update(false);
                end;
            }
            action(OpenJobQueue)
            {
                Caption = 'Open Job Queue';
                Image = Job;
                ToolTip = 'Open the Job Queue Entry responsible for processing scheduled PTE updates.';
                trigger OnAction()
                var
                    PTEUpdateScheduler: Codeunit "D4P BC PTE Update Scheduler";
                begin
                    PTEUpdateScheduler.OpenJobQueueEntry();
                end;
            }
        }
    }

    var
        EnvironmentContext: Record "D4P BC Environment";
        PTEAppNameContext: Text[100];
        StatusStyleExpr: Text;

    procedure SetContext(var BCEnvironment: Record "D4P BC Environment"; PTEAppName: Text[100])
    begin
        EnvironmentContext := BCEnvironment;
        PTEAppNameContext := PTEAppName;
    end;

    trigger OnAfterGetRecord()
    var
        PTEUpdateScheduler: Codeunit "D4P BC PTE Update Scheduler";
    begin
        StatusStyleExpr := PTEUpdateScheduler.GetStatusStyleExpr(Rec);
    end;
}
