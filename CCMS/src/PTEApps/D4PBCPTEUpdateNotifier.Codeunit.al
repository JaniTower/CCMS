namespace D4P.CCMS.PTEApps;

using System.Email;
using System.Security.User;
using System.Security.AccessControl;

codeunit 62020 "D4P BC PTE Update Notifier"
{
    Access = Internal;

    procedure SendCompletionNotification(var ScheduledUpdate: Record "D4P BC Scheduled PTE Update")
    begin
        if not TrySendEmail(ScheduledUpdate) then begin
            ScheduledUpdate."Email Error" := CopyStr(GetLastErrorText(), 1, MaxStrLen(ScheduledUpdate."Email Error"));
            ScheduledUpdate.Modify();
        end;
    end;

    [TryFunction]
    procedure TrySendEmail(var ScheduledUpdate: Record "D4P BC Scheduled PTE Update")
    var
        EmailMessage: Codeunit "Email Message";
        Email: Codeunit Email;
        RecipientEmail: Text;
        Subject: Text;
        Body: Text;
    begin
        RecipientEmail := GetRecipientEmail(ScheduledUpdate."Scheduled By");
        if RecipientEmail = '' then
            exit;

        Subject := BuildSubject(ScheduledUpdate);
        Body := BuildBody(ScheduledUpdate);

        EmailMessage.Create(RecipientEmail, Subject, Body, true);
        Email.Send(EmailMessage);

        ScheduledUpdate."Email Sent" := true;
        ScheduledUpdate.Modify();
    end;

    procedure GetRecipientEmail(UserName: Code[50]): Text
    var
        UserRec: Record User;
    begin
        if UserName = '' then
            exit('');

        UserRec.SetRange("User Name", UserName);
        UserRec.SetLoadFields("Contact Email");
        if not UserRec.FindFirst() then
            exit('');

        exit(UserRec."Contact Email");
    end;

    procedure BuildSubject(var ScheduledUpdate: Record "D4P BC Scheduled PTE Update"): Text
    begin
        if ScheduledUpdate.Status = ScheduledUpdate.Status::Completed then
            exit(StrSubstNo(CompletedSubjectLbl, ScheduledUpdate."PTE App Name", ScheduledUpdate."App Version"));

        exit(StrSubstNo(FailedSubjectLbl, ScheduledUpdate."PTE App Name", ScheduledUpdate."App Version"));
    end;

    procedure BuildBody(var ScheduledUpdate: Record "D4P BC Scheduled PTE Update"): Text
    var
        BodyBuilder: TextBuilder;
        StatusText: Text;
    begin
        if ScheduledUpdate.Status = ScheduledUpdate.Status::Completed then
            StatusText := CompletedStatusLbl
        else
            StatusText := FailedStatusLbl;

        ScheduledUpdate.CalcFields("Environment Friendly Name");

        BodyBuilder.AppendLine(StrSubstNo(BodyHeaderLbl, NotificationTitleLbl));
        BodyBuilder.AppendLine(StrSubstNo(BodyFieldLbl, AppFieldLbl, ScheduledUpdate."PTE App Name"));
        BodyBuilder.AppendLine(StrSubstNo(BodyFieldLbl, VersionFieldLbl, ScheduledUpdate."App Version"));
        BodyBuilder.AppendLine(StrSubstNo(BodyFieldLbl, EnvironmentFieldLbl,
            StrSubstNo('%1 (%2)', ScheduledUpdate."Environment Friendly Name", ScheduledUpdate."Environment Name")));
        BodyBuilder.AppendLine(StrSubstNo(BodyFieldLbl, StatusFieldLbl, StatusText));
        BodyBuilder.AppendLine(StrSubstNo(BodyFieldLbl, CompletedOnFieldLbl, Format(ScheduledUpdate."Completed On")));

        if (ScheduledUpdate.Status = ScheduledUpdate.Status::Failed) and (ScheduledUpdate."Error Message" <> '') then
            BodyBuilder.AppendLine(StrSubstNo(BodyFieldLbl, ErrorFieldLbl, ScheduledUpdate."Error Message"));

        exit(BodyBuilder.ToText());
    end;

    var
        CompletedSubjectLbl: Label 'PTE Update Completed: %1 v%2', Comment = '%1 = App Name, %2 = Version';
        FailedSubjectLbl: Label 'PTE Update Failed: %1 v%2', Comment = '%1 = App Name, %2 = Version';
        CompletedStatusLbl: Label 'Completed Successfully';
        FailedStatusLbl: Label 'Failed';
        NotificationTitleLbl: Label 'PTE Update Notification';
        AppFieldLbl: Label 'App';
        VersionFieldLbl: Label 'Version';
        EnvironmentFieldLbl: Label 'Environment';
        StatusFieldLbl: Label 'Status';
        CompletedOnFieldLbl: Label 'Completed On';
        ErrorFieldLbl: Label 'Error';
        BodyHeaderLbl: Label '<h2>%1</h2>', Locked = true, Comment = '%1 = Title';
        BodyFieldLbl: Label '<p><strong>%1:</strong> %2</p>', Locked = true, Comment = '%1 = Field name, %2 = Value';
}
