namespace D4P.CCMS.PTEApps;

enum 62010 "D4P BC Dep. Check Result"
{
    Extensible = false;

    value(0; Ready)
    {
        Caption = 'Ready';
    }
    value(1; Waiting)
    {
        Caption = 'Waiting';
    }
    value(2; Failed)
    {
        Caption = 'Failed';
    }
}
