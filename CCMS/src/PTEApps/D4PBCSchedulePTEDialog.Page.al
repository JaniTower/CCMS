namespace D4P.CCMS.PTEApps;

page 62055 "D4P BC Schedule PTE Dialog"
{
    ApplicationArea = All;
    Caption = 'Schedule PTE Update';
    PageType = StandardDialog;

    layout
    {
        area(Content)
        {
            group(Schedule)
            {
                Caption = 'Schedule';

                field(ScheduledDate; ScheduleDate)
                {
                    ApplicationArea = All;
                    Caption = 'Date';
                    ToolTip = 'Specifies the date to run the update.';
                }
                field(ScheduledTime; ScheduleTime)
                {
                    ApplicationArea = All;
                    Caption = 'Time';
                    ToolTip = 'Specifies the time to run the update.';
                }
            }
        }
    }

    var
        ScheduleDate: Date;
        ScheduleTime: Time;

    trigger OnOpenPage()
    begin
        ScheduleDate := Today() + 1;
        ScheduleTime := 020000T;
    end;

    procedure GetScheduledDateTime(): DateTime
    begin
        exit(CreateDateTime(ScheduleDate, ScheduleTime));
    end;
}
