namespace D4P.CCMS.PTEApps;

table 62021 "D4P BC PTE App Dependency"
{
    DataClassification = CustomerContent;
    Caption = 'D365BC PTE App Dependency';

    fields
    {
        field(1; "PTE ID"; Guid)
        {
            Caption = 'PTE ID';
            ToolTip = 'Specifies the Per Tenant Extension''s ID.';
        }
        field(2; "Dependency Package ID"; Text[250])
        {
            Caption = 'Dependency Package ID';
            ToolTip = 'Specifies the NuGet package ID of the dependency.';
        }
        field(3; "Version Range"; Text[50])
        {
            Caption = 'Min. Version';
            ToolTip = 'Specifies the minimum required version of the dependency.';
        }
    }

    keys
    {
        key(PK; "PTE ID", "Dependency Package ID")
        {
            Clustered = true;
        }
    }
}
