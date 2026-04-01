namespace D4P.CCMS.PTEApps;

page 62064 "D4P BC PTE Sched. Dep. Part"
{
    ApplicationArea = All;
    Caption = 'Dependencies';
    PageType = ListPart;
    SourceTable = "D4P BC PTE Sched. Dep.";
    SourceTableTemporary = true;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field(Install; Rec.Install)
                {
                }
                field("Dependency Package ID"; Rec."Dependency Package ID")
                {
                    Editable = false;
                }
                field("Version Range"; Rec."Version Range")
                {
                    Editable = false;
                }
            }
        }
    }

    procedure LoadDependencies(PTEId: Guid)
    var
        PTEAppDependency: Record "D4P BC PTE App Dependency";
    begin
        Rec.DeleteAll();
        PTEAppDependency.SetRange("PTE ID", PTEId);
        PTEAppDependency.SetLoadFields("PTE ID", "Dependency Package ID", "Version Range");
        if PTEAppDependency.FindSet() then
            repeat
                Rec.Init();
                Rec."PTE ID" := PTEAppDependency."PTE ID";
                Rec."Dependency Package ID" := PTEAppDependency."Dependency Package ID";
                Rec."Version Range" := PTEAppDependency."Version Range";
                Rec.Install := true;
                Rec.Insert();
            until PTEAppDependency.Next() = 0;
        CurrPage.Update(false);
    end;

    procedure HasSelectedDependencies(): Boolean
    begin
        Rec.SetRange(Install, true);
        exit(not Rec.IsEmpty());
    end;

    procedure GetSelectedDependencies(var TempSchedDep: Record "D4P BC PTE Sched. Dep." temporary)
    begin
        TempSchedDep.DeleteAll();
        Rec.SetRange(Install, true);
        if Rec.FindSet() then
            repeat
                TempSchedDep := Rec;
                TempSchedDep.Insert();
            until Rec.Next() = 0;
        Rec.SetRange(Install);
    end;
}
