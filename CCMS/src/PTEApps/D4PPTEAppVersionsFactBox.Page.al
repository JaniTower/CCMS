namespace D4P.CCMS.PTEApps;

using D4P.CCMS.Nuget;

page 62056 "D4P PTE App Versions FactBox"
{
    ApplicationArea = All;
    Caption = 'D365BC Versions';
    Editable = false;
    PageType = ListPart;
    SourceTable = "D4P BC PTE App Version";
    SourceTableView = sorting("Version Sort Key") order(descending);
    CardPageId = "D4P BC PTE App Version Card";

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("App Version"; Rec."App Version")
                {
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(DownloadAppPackage)
            {
                Caption = 'Download App Package';
                Image = Download;
                trigger OnAction()
                var
                    NugetProcessing: Codeunit "D4P BC Nuget Processing";
                begin
                    NugetProcessing.DownloadPackageContentAndNotify(Rec);
                end;
            }
        }
    }
}
