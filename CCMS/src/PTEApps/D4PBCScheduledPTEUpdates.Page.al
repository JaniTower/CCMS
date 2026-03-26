namespace D4P.CCMS.PTEApps;

using System.Threading;

page 62059 "D4P BC Scheduled PTE Updates"
{
    ApplicationArea = All;
    Caption = 'D365BC Scheduled PTE Updates';
    PageType = List;
    SourceTable = "D4P BC Scheduled PTE Update";
    SourceTableView = sorting("Entry No.") order(descending);
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    Visible = false;
                }
                field("PTE App Name"; Rec."PTE App Name")
                {
                }
                field("App Version"; Rec."App Version")
                {
                }
                field("Environment Name"; Rec."Environment Name")
                {
                }
                field("Scheduled DateTime"; Rec."Scheduled DateTime")
                {
                }
                field(Status; Rec.Status)
                {
                    StyleExpr = StatusStyleExpr;
                }
                field("Created On"; Rec."Created On")
                {
                }
                field("Started On"; Rec."Started On")
                {
                }
                field("Completed On"; Rec."Completed On")
                {
                }
                field("Error Message"; Rec."Error Message")
                {
                }
                field("Customer No."; Rec."Customer No.")
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
                ToolTip = 'Schedule a PTE app update for an environment.';
                trigger OnAction()
                var
                    PTEUpdateScheduler: Codeunit "D4P BC PTE Update Scheduler";
                begin
                    PTEUpdateScheduler.ScheduleUpdate();
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
        area(Promoted)
        {
            actionref(ScheduleUpdatePromoted; ScheduleUpdate)
            {
            }
            actionref(CancelUpdatePromoted; CancelUpdate)
            {
            }
            actionref(OpenJobQueuePromoted; OpenJobQueue)
            {
            }
        }
    }

    var
        StatusStyleExpr: Text;

    trigger OnAfterGetRecord()
    var
        PTEUpdateScheduler: Codeunit "D4P BC PTE Update Scheduler";
    begin
        StatusStyleExpr := PTEUpdateScheduler.GetStatusStyleExpr(Rec);
    end;
}
