namespace D4P.CCMS.PTEApps;

using D4P.CCMS.Customer;

table 62020 "D4P BC Scheduled PTE Update"
{
    Caption = 'D365BC Scheduled PTE Update';
    DataClassification = CustomerContent;
    LookupPageId = "D4P BC Scheduled PTE Updates";
    DrillDownPageId = "D4P BC Scheduled PTE Updates";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(10; "Customer No."; Code[20])
        {
            Caption = 'Customer No.';
            TableRelation = "D4P BC Customer";
            ToolTip = 'Specifies the customer associated with the environment.';
        }
        field(20; "Tenant ID"; Guid)
        {
            Caption = 'Tenant ID';
            ToolTip = 'Specifies the tenant identifier.';
        }
        field(30; "Environment Name"; Text[30])
        {
            Caption = 'Environment Name';
            ToolTip = 'Specifies the environment where the PTE will be deployed.';
        }
        field(40; "PTE App ID"; Guid)
        {
            Caption = 'PTE App ID';
            TableRelation = "D4P BC PTE App"."ID";
            ToolTip = 'Specifies the PTE app to deploy.';
        }
        field(50; "PTE App Name"; Text[100])
        {
            Caption = 'PTE App Name';
            ToolTip = 'Specifies the name of the PTE app.';
        }
        field(60; "App Version"; Text[50])
        {
            Caption = 'App Version';
            ToolTip = 'Specifies the version to deploy.';
        }
        field(70; "Scheduled DateTime"; DateTime)
        {
            Caption = 'Scheduled Date Time';
            ToolTip = 'Specifies when the update should be executed.';
        }
        field(80; Status; Enum "D4P BC PTE Update Status")
        {
            Caption = 'Status';
            ToolTip = 'Specifies the current status of the scheduled update.';
        }
        field(90; "Created On"; DateTime)
        {
            Caption = 'Created On';
            ToolTip = 'Specifies when the update was scheduled.';
        }
        field(100; "Started On"; DateTime)
        {
            Caption = 'Started On';
            ToolTip = 'Specifies when the update started executing.';
        }
        field(110; "Completed On"; DateTime)
        {
            Caption = 'Completed On';
            ToolTip = 'Specifies when the update finished.';
        }
        field(120; "Error Message"; Text[2048])
        {
            Caption = 'Error Message';
            ToolTip = 'Specifies the error message if the update failed.';
        }
        field(130; "Dependency Entry Nos."; Text[250])
        {
            Caption = 'Dependency Entry Nos.';
            ToolTip = 'Specifies the entry numbers of dependency updates that must complete before this update can be processed.';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(Schedule; Status, "Scheduled DateTime")
        {
        }
        key(Environment; "Customer No.", "Tenant ID", "Environment Name", "Scheduled DateTime")
        {
        }
    }
}
