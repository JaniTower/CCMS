namespace D4P.CCMS.PTEApps;

using D4P.CCMS.Environment;
using System.Threading;

page 62054 "D4P BC Sched. PTE Upd. Part"
{
    ApplicationArea = All;
    Caption = 'Scheduled PTE Updates';
    PageType = ListPart;
    SourceTable = "D4P BC Scheduled PTE Update";
    SourceTableView = sorting("Entry No.") order(descending);
    Editable = false;
    DeleteAllowed = true;

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
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(DeleteEntry)
            {
                Caption = 'Delete';
                Image = Delete;
                ToolTip = 'Delete the selected scheduled PTE update entry.';
                trigger OnAction()
                begin
                    if not Confirm('Do you want to delete the selected entry?') then
                        exit;
                    Rec.Delete(true);
                    CurrPage.Update(false);
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
                    PTEUpdateScheduler.ScheduleUpdate(EnvironmentContext);
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
                    JobQueueEntry: Record "Job Queue Entry";
                    PTEUpdateScheduler: Codeunit "D4P BC PTE Update Scheduler";
                begin
                    PTEUpdateScheduler.EnsureJobQueueExists();
                    JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
                    JobQueueEntry.SetRange("Object ID to Run", Codeunit::"D4P BC PTE Update Scheduler");
                    if JobQueueEntry.FindFirst() then
                        Page.Run(Page::"Job Queue Entry Card", JobQueueEntry);
                end;
            }
        }
    }

    var
        EnvironmentContext: Record "D4P BC Environment";
        StatusStyleExpr: Text;

    procedure SetEnvironmentContext(var BCEnvironment: Record "D4P BC Environment")
    begin
        EnvironmentContext := BCEnvironment;
    end;

    trigger OnAfterGetRecord()
    begin
        case Rec.Status of
            Rec.Status::Pending:
                StatusStyleExpr := Format(PageStyle::Ambiguous);
            Rec.Status::"In Progress":
                StatusStyleExpr := Format(PageStyle::AttentionAccent);
            Rec.Status::Completed:
                StatusStyleExpr := Format(PageStyle::Favorable);
            Rec.Status::Failed:
                StatusStyleExpr := Format(PageStyle::Unfavorable);
            Rec.Status::Cancelled:
                StatusStyleExpr := Format(PageStyle::Standard);
        end;
    end;
}
