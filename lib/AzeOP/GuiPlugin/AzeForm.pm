package AzeOP::GuiPlugin::AzeForm;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractForm';
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use POSIX qw(strftime);

=head1 NAME

AzeOP::GuiPlugin::AzeForm - Time Tracker Edit Form

=head1 SYNOPSIS

 use AzeOP::GuiPlugin::AzeForm;

=head1 DESCRIPTION

The Time Tracker Edit Form

=cut

=head1 METHODS

All the methods of L<CallBackery::GuiPlugin::AbstractForm> plus:

=cut

=head2 formCfg

Returns a Configuration Structure for the TimeTracker Entry Form.

=cut


has formCfg => sub {
    my $self = shift;
    my $db = $self->user->db;
    my $cbUsers = $db->getMap('cbuser','login');
    my %cbUsers;
    
    for (@$cbUsers){
        $cbUsers{$_->{key}} = $_->{title};
    }

    return [
        $self->config->{type} eq 'edit' ? {
            key => 'aze_id',
            label => trm('Id'),
            widget => 'text',
            set => {
                readOnly => $self->true,
            },
        }:(),
        $self->user->may('admin') ? (
            {
                key => 'aze_cbuser',
                label => trm('User'),
                widget => 'selectBox',
                cfg => {
                    required => $self->true,
                    structure => $cbUsers
                },
                validator => sub {
                    my $value = shift;
                    return trm("Ungültiger user")
                        if not $cbUsers{$value};
                    return undef;
                },
            }
        ) :(),
        {
            key => 'aze_start',
            label => trm('Start'),
            widget => 'text',
            set => {
                required => $self->true,
                placeholder => 'YYYY-MM-DD HH:MM:SS',
            },
            validator => sub {
                my $value = shift;
                if ($value !~ /^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/) {
                    return "Startzeit als YYYY-MM-DD HH:MM:SS erwartet";
                }
                return undef;
            }
        },
        {
            key => 'aze_duration',
            label => trm('Dauer'),
            widget => 'text',
            set => {
                placeholder => 'HH:MM',
            },
            validator => sub {
                my $value = shift;
                if ($value !~ /^((\d?\d:\d\d)|(\d+(\.\d+)?))$/){
                    return "Dauer als HH:MM erwartet";
                }
                return undef;
            }
        },
        {
            key => 'aze_note',
            label => trm('Note'),
            widget => 'textArea',
            set => {
                placeholder => 'some extra information about this entry',
            }
        },
    ];
};

has actionCfg => sub {
    my $self = shift;
    my $type = $self->config->{type} // 'new';

    my $handler = sub {
        my $args = shift;
        if ($args->{aze_duration}){
            if ($args->{aze_duration} =~ /:/){
                my @duration = split /:/, $args->{aze_duration};
                $args->{aze_duration} = $duration[2]*3600+$duration[1]*60*$duration[0];
            }
            else {
                $args->{aze_duration} *= 3600;
            }
        }
        my @userMatch = ();
        if (! $self->user->may('admin')){
            $args->{aze_cbuser} = $self->user->userId;
            @userMatch = 'aze_cbuser' => $self->user->userId;
        }
        $args->{aze_lastmod} = strftime('%Y-%m-%d %H:%M:%S',localtime(time))
                        . ' - Edit  by '. $self->user->userInfo->{cbuser_login};

        my @fields = qw(start duration note);

        if ($type eq 'new'){
            push @fields, 'cbuser';
        }

        my $db = $self->user->db;

        my $id = $db->updateOrInsertData('aze',{
            map { $_ => $args->{'aze_'.$_} } @fields
        },$args->{aze_id} ? { id => int($args->{aze_id}), @userMatch } : (@userMatch));
        return {
            action => 'dataSaved'
        };
    };
    return [
        {
            label => $type eq 'edit'
               ? trm('Speichern')
               : trm('Hinzufügen'),
            action => 'submit',
            key => 'save',
            handler => $handler
        }
    ];
};

has grammar => sub {
    my $self = shift;
    $self->mergeGrammar(
        $self->SUPER::grammar,
        {
            _doc => "Tree Node Configuration",
            _vars => [ qw(type) ],
            type => {
                _doc => 'type of form to show: edit, add',
                _re => '(edit|add)'
            },
        },
    );
};

sub getAllFieldValues {
    my $self = shift;
    my $args = shift;
    return {} if $self->config->{type} ne 'edit';
    my $id = $args->{selection}{aze_id};
    return {} unless $id;

    my $db = $self->user->db;
    my $data = $db->fetchRow('aze',{id => $id});
    if ($data->{aze_duration}){
        $data->{aze_duration} = sprintf("%.1f", $data->{aze_duration}/3600);
    }
    return $data;
}

has checkAccess => sub {
    my $self = shift;
    return $self->user->may('admin');
};

1;
__END__

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2015-15-11/21/15 to 0.0 first version

=cut
