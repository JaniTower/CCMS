namespace D4P.CCMS.PTEApps;

codeunit 62063 "D4P BC PTE App Mgt"
{
    Access = Internal;

    procedure InitializeId(var PTEApp: Record "D4P BC PTE App")
    begin
        if IsNullGuid(PTEApp."ID") then
            PTEApp."ID" := CreateGuid();
    end;

    procedure DeleteRelatedRecords(PTEApp: Record "D4P BC PTE App")
    var
        PTEAppVersion: Record "D4P BC PTE App Version";
        PTEAppDependency: Record "D4P BC PTE App Dependency";
        PTEObjectRange: Record "D4P BC PTE Object Range";
    begin
        PTEAppVersion.SetRange("PTE ID", PTEApp."ID");
        if not PTEAppVersion.IsEmpty() then
            PTEAppVersion.DeleteAll(true);

        PTEAppDependency.SetRange("PTE ID", PTEApp."ID");
        if not PTEAppDependency.IsEmpty() then
            PTEAppDependency.DeleteAll(true);

        PTEObjectRange.SetRange("PTE ID", PTEApp."ID");
        if not PTEObjectRange.IsEmpty() then
            PTEObjectRange.DeleteAll(true);
    end;

    procedure ValidateRangeTo(PTEObjectRange: Record "D4P BC PTE Object Range")
    var
        RangeToErr: Label 'Range To must be greater than or equal to Range From.';
    begin
        if PTEObjectRange."Range To" < PTEObjectRange."Range From" then
            Error(RangeToErr);
    end;
}
