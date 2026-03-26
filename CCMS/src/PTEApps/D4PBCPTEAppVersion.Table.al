namespace D4P.CCMS.PTEApps;

using D4P.CCMS.Nuget;
table 62018 "D4P BC PTE App Version"
{
    DataClassification = CustomerContent;
    Caption = 'D365BC PTE App Version';

    fields
    {
        field(1; "PTE ID"; Guid)
        {
            Caption = 'PTE ID';
            ToolTip = 'Specifies the Per Tenant Extension''s ID.';
        }
        field(2; "App Version"; Text[50])
        {
            Caption = 'App Version';
            ToolTip = 'Specifies the version of the PTE app.';
        }
        field(3; "Package Content Url"; Text[250])
        {
            Caption = 'Package Content Url';
            ToolTip = 'Specifies the URL to the package content.';
        }
        field(4; "Version Sort Key"; Text[30])
        {
            Caption = 'Version Sort Key';
            ToolTip = 'Specifies the zero-padded version string used for correct semantic sort order.';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "PTE ID", "App Version")
        {
            Clustered = true;
        }
        key(SortKey; "PTE ID", "Version Sort Key")
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "PTE ID", "App Version")
        {
        }
    }

    procedure ComputeSortKey(VersionText: Text): Text
    var
        Parts: List of [Text];
        Part: Text;
        SortKey: Text;
        SegmentValue: Integer;
    begin
        Parts := VersionText.Split('.');
        while Parts.Count() < 4 do
            Parts.Add('0');
        foreach Part in Parts do begin
            Evaluate(SegmentValue, Part);
            if SortKey <> '' then
                SortKey += '.';
            SortKey += Format(SegmentValue, 0, '<Integer,5><Filler Character,0>');
        end;
        exit(SortKey);
    end;

    procedure DoExists(): Boolean
    var
        PTEAppVersion: Record "D4P BC PTE App Version";
    begin
        exit(PTEAppVersion.Get(Rec."PTE ID", Rec."App Version"));
    end;

    procedure GetPTEAppDevOps() DevOps: Enum "D4P BC DevOps Environment"
    var
        PTEApps: Record "D4P BC PTE App";
    begin
        if not PTEApps.Get(Rec."PTE ID") then
            exit(DevOps::NoDevOps);
        DevOps := PTEApps."DevOps Environment";
    end;

    procedure GetPTEAppName(): Text[100]
    var
        PTEApps: Record "D4P BC PTE App";
    begin
        if not PTEApps.Get(Rec."PTE ID") then
            exit('');
        exit(PTEApps."Name");
    end;

    procedure GetPTEOrganizationName(): Text[128]
    var
        PTEApps: Record "D4P BC PTE App";
    begin
        if not PTEApps.Get(Rec."PTE ID") then
            exit('');
        exit(PTEApps."DevOps Organization");
    end;

}