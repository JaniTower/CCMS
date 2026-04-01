namespace D4P.CCMS.PTEApps;

using D4P.CCMS.Nuget;

page 62052 "D4P BC PTE App Card"
{
    ApplicationArea = All;
    Caption = 'D365BC PTE App Card';
    PageType = Card;
    SourceTable = "D4P BC PTE App";

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("ID"; Rec."ID")
                {
                }
                field("Name"; Rec."Name")
                {
                }
                field("Latest App Version"; Rec."Latest App Version")
                {
                }
            }
            group(DevOpsGroup)
            {
                Caption = 'DevOps';

                field(DevOps; Rec."DevOps Environment")
                {
                }
                field("DevOps Organization"; Rec."DevOps Organization")
                {
                }
                field("DevOps Package"; Rec."DevOps Package")
                {
                    Visible = DevOpsPackageVisible;
                }
                field("DevOps Feed"; Rec."DevOps Feed")
                {
                    Visible = DevOpsFeedVisible;
                }
                field("NuGet Package Name"; Rec."NuGet Package Name")
                {
                }
            }
            part(ScheduledPTEUpdates; "D4P BC Sched. PTE Upd. Part")
            {
                Caption = 'Scheduled PTE Updates';
                SubPageLink = "PTE App ID" = field("ID");
            }
        }

        area(FactBoxes)
        {
            part(PTEAppPObjectRangeFactBox; "D4P BC PTE Obj. Ranges FactBox")
            {
                Caption = 'Object Range';
                SubPageLink = "PTE ID" = field("ID");
            }
            part(PTEAppVersionsFactBox; "D4P PTE App Versions FactBox")
            {
                Caption = 'Versions';
                SubPageLink = "PTE ID" = field("ID");
            }
            part(PTEAppDepFactBox; "D4P BC PTE App Dep. FactBox")
            {
                Caption = 'Dependencies';
                SubPageLink = "PTE ID" = field("ID");
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(GetLatestVersions)
            {
                Caption = 'Get Latest Versions';
                Image = Refresh;
                trigger OnAction()
                var
                    NugetProcessing: Codeunit "D4P BC Nuget Processing";
                begin
                    NugetProcessing.GetPTEAppVersionsAndNotify(Rec);
                end;
            }
        }
        area(Navigation)
        {
            action(ObjectRanges)
            {
                Caption = 'Object Ranges';
                ToolTip = 'View and edit per tenant extension object ranges for this app.';
                Image = EditLines;
                trigger OnAction()
                var
                    ObjectRanges: Page "D4P BC PTE Object Range";
                begin
                    ObjectRanges.SetAppId(Rec."ID");
                    ObjectRanges.Run();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(GetLatestVersions_Promoted; GetLatestVersions)
                {
                }
            }
            group(Category_Navigation)
            {
                Caption = 'Navigation';

                actionref(ObjectRanges_Promoted; ObjectRanges)
                {
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        SetVisibleFields();
    end;

    local procedure SetVisibleFields()
    begin
        if Rec."DevOps Environment" = Rec."DevOps Environment"::Azure then begin
            DevOpsPackageVisible := true;
            DevOpsFeedVisible := true;
        end else begin
            DevOpsPackageVisible := false;
            DevOpsFeedVisible := false;
        end;
    end;

    var
        DevOpsPackageVisible: Boolean;
        DevOpsFeedVisible: Boolean;
}
