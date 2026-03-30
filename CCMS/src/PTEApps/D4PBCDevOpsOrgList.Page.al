namespace D4P.CCMS.PTEApps;

using D4P.CCMS.Nuget;

page 62050 "D4P BC DevOps Org. List"
{
    ApplicationArea = All;
    Caption = 'D365BC DevOps Organization List';
    PageType = List;
    SourceTable = "D4P BC DevOps Organization";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field(DevOps; Rec."DevOps Environment")
                {
                }
                field(ID; Rec.ID)
                {
                }
                field(Name; Rec.Name)
                {
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ImportToken)
            {
                Caption = 'Import Token';
                Image = CodesList;
                trigger OnAction()
                begin
                    Rec.ImportToken();
                end;
            }
            action(TestConnection)
            {
                Caption = 'Test Connection';
                Image = ValidateEmailLoggingSetup;
                trigger OnAction()
                var
                    NugetProcessing: Codeunit "D4P BC Nuget Processing";
                begin
                    NugetProcessing.TestConnectionAndNotify(Rec);
                end;
            }
        }
    }
}