namespace D4P.CCMS.PTEApps;

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
                field("Environment Friendly Name"; Rec."Environment Friendly Name")
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
                ToolTip = 'Schedule a PTE app update for an environment.';
                trigger OnAction()
                var
                    PTEUpdateScheduler: Codeunit "D4P BC PTE Update Scheduler";
                begin
                    PTEUpdateScheduler.ScheduleUpdate();
                    CurrPage.Update(false);
                end;
            }
            action(ViewJobQueueEntry)
            {
                Caption = 'View Job Queue Entry';
                Image = Job;
                ToolTip = 'Open the Job Queue Entry for the selected scheduled update.';
                trigger OnAction()
                var
                    PTEUpdateScheduler: Codeunit "D4P BC PTE Update Scheduler";
                begin
                    PTEUpdateScheduler.OpenJobQueueEntryForUpdate(Rec);
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
            actionref(ViewJobQueueEntryPromoted; ViewJobQueueEntry)
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
