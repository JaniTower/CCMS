namespace D4P.CCMS.PTEApps;

page 62053 "D4P BC Scheduled PTE Updates"
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
                    CancelConfirmQst: Label 'Do you want to cancel the scheduled update for %1 v%2?', Comment = '%1 = App Name, %2 = Version';
                    CancelledMsg: Label 'Scheduled update has been cancelled.';
                    CannotCancelErr: Label 'Only pending updates can be cancelled.';
                begin
                    if Rec.Status <> Rec.Status::Pending then
                        Error(CannotCancelErr);
                    if Confirm(CancelConfirmQst, false, Rec."PTE App Name", Rec."App Version") then begin
                        Rec.Status := Rec.Status::Cancelled;
                        Rec.Modify();
                        Message(CancelledMsg);
                    end;
                end;
            }
        }
        area(Promoted)
        {
            actionref(CancelUpdatePromoted; CancelUpdate)
            {
            }
        }
    }

    var
        StatusStyleExpr: Text;

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
