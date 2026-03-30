namespace D4P.CCMS.Extension;

using D4P.CCMS.PTEApps;
page 62009 "D4P PTE Object Ranges"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "D4P PTE Object Range";
    Caption = 'PTE Object Ranges';
    Editable = true;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Customer No."; Rec."Customer No.")
                {
                }
                field("Tenant ID"; Rec."Tenant ID")
                {
                }
                field("PTE ID"; Rec."PTE ID")
                {
                    TableRelation = "D4P BC PTE App"."ID";

                    trigger OnValidate()
                    begin
                        Rec.CopyValuesFromApp(Rec."PTE ID");
                    end;
                }
                field("PTE Name"; Rec."PTE Name")
                {
                }
            }
        }

        area(FactBoxes)
        {
            part(PTEAppPObjectRangeFactBox; "D4P BC PTE Obj. Ranges FactBox")
            {
                Caption = 'Object Range';
                SubPageLink = "PTE ID" = field("PTE ID");
            }
            part(PTEAppVersionsFactBox; "D4P PTE App Versions FactBox")
            {
                Caption = 'Versions';
                SubPageLink = "PTE ID" = field("PTE ID");
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(OpenPteApp)
            {
                Caption = 'Open PTE App';
                Image = Open;
                trigger OnAction()
                begin
                    Rec.OpenPTEApp();
                end;

            }
        }
    }
}
