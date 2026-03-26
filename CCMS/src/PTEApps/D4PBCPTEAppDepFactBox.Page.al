namespace D4P.CCMS.PTEApps;

page 62062 "D4P BC PTE App Dep. FactBox"
{
    ApplicationArea = All;
    Caption = 'Dependencies';
    Editable = false;
    PageType = ListPart;
    SourceTable = "D4P BC PTE App Dependency";

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Dependency Package ID"; Rec."Dependency Package ID")
                {
                    ApplicationArea = All;
                }
                field("Version Range"; Rec."Version Range")
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    procedure SetPTEApp(PTEId: Guid)
    begin
        Rec.SetRange("PTE ID", PTEId);
        CurrPage.Update(false);
    end;
}
