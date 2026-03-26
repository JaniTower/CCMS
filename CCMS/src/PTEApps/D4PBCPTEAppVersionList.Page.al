namespace D4P.CCMS.PTEApps;

using D4P.CCMS.Nuget;

page 62057 "D4P BC PTE App Version List"
{
    ApplicationArea = All;
    Caption = 'D365BC PTE App Versions';
    Editable = false;
    PageType = List;
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
                field("Package Content Url"; Rec."Package Content Url")
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
            action(GetLatestVersions)
            {
                Caption = 'Get Latest Versions';
                ApplicationArea = All;
                Image = Refresh;
                ToolTip = 'Refresh the list of available versions from NuGet.';
                trigger OnAction()
                var
                    PTEApp: Record "D4P BC PTE App";
                    NugetProcessing: Codeunit "D4P BC Nuget Processing";
                    VersionsUpdatedMsg: Label 'Versions have been refreshed.';
                begin
                    if PTEApp.Get(Rec."PTE ID") then begin
                        NugetProcessing.GetPTEAppVersions(PTEApp);
                        CurrPage.Update(false);
                        Message(VersionsUpdatedMsg);
                    end;
                end;
            }
        }
        area(Promoted)
        {
            actionref(GetLatestVersionsPromoted; GetLatestVersions)
            {
            }
        }
    }

}
