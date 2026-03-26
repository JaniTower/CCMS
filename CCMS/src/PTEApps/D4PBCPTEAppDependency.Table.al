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
            Caption = 'Version Range';
            ToolTip = 'Specifies the version range string of the dependency (e.g. [1.0.0, )).';
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
