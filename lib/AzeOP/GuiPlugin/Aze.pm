package AzeOP::GuiPlugin::Aze;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable';
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use POSIX qw(strftime);

=head1 NAME

AzeOP::GuiPlugin::Aze - Aze Table

=head1 SYNOPSIS

 use AzeOP::GuiPlugin::Aze;

=head1 DESCRIPTION

The Aze Table Gui.

=cut

my $getLastEntry = sub {
    my $self = shift;
    my $db = $self->user->mojoSqlDb;
    return $db->dbh->selectrow_hashref(<<"SQL_END",{},$self->user->userId);
        SELECT aze_id,aze_start,strftime('%s',aze_start,'utc') AS aze_epoch, aze_duration
        FROM aze
        WHERE
            aze_cbuser = ?
            AND date(aze_start,'localtime') = date('now','localtime')
        ORDER BY aze_start DESC
        LIMIT 1
SQL_END
};

=head1 METHODS

All the methods of L<CallBackery::GuiPlugin::AbstractTable> plus:

=cut

has formCfg => sub {
    my $self = shift;
    return [] unless $self->user->may('record');
    return [
        {
            key => 'tt_today',
            label => trm('Stopuhr'),
            widget => 'text',
            set => {
                readOnly => $self->true,
                width => 200
            },
            getter => sub {
                my $rec = $self->$getLastEntry();
                if ($rec ){
                    if (not $rec->{aze_duration}) {
                        return strftime('%H:%M:%S',gmtime(time - $rec->{aze_epoch}));
                    }
                }
                return trm('mit [Zeit Erfassen] starten')
            }
        }
    ]
};

=head2 tableCfg

=cut

has tableCfg => sub {
    my $self = shift;
    return [
        {
            label => trm('Id'),
            type => 'str',
            width => '1*',
            key => 'aze_id',
            sortable => $self->true,
        },
        $self->user->may('admin') ? (
        {
            label => trm('User'),
            type => 'str',
            width => '2*',
            key => 'cbuser_login',
            sortable => $self->true,
        },
        ):(),
        {
            label => trm('Datum'),
            type => 'str',
            width => '3*',
            key => 'c_date',
            sortable => $self->true,
        },
        {
            label => trm('Begin'),
            type => 'str',
            width => '2*',
            key => 'c_begin',
            sortable => $self->true,
        },
        {
            label => trm('Ende'),
            type => 'str',
            width => '2*',
            key => 'c_end',
            sortable => $self->true,
        },
        {
            label => trm('Total'),
            type => 'str',
            width => '2*',
            key => 'c_total',
            sortable => $self->true,
        },
        {
            label => trm('Bearbeitet am'),
            type => 'str',
            width => '6*',
            key => 'aze_lastmod',
            sortable => $self->true,
        },
        {
            label => trm('Bemerkung'),
            type => 'str',
            width => '2*',
            key => 'aze_note',
            sortable => $self->true,
        }
    ]
};


=head2 actionCfg

Only users who can write get any actions presented.

=cut

has actionCfg => sub {
    my $self = shift;
    my $recordTime = sub {
        my $rec = $self->$getLastEntry();
        my $db = $self->user->db;
        if ( ref $rec eq 'HASH' and not $rec->{aze_duration} ){
            $db->updateOrInsertData('aze',{
                    duration => time - int($rec->{aze_epoch}),
                    lastmod => strftime('%Y-%m-%d %H:%M:%S',localtime(time))
                        . ' - RecEnd by ' . $self->user->userInfo->{cbuser_login}
                },
                {
                    id => int($rec->{aze_id})
                }
            );
        }
        else {
            $db->updateOrInsertData('aze',{
                    cbuser => $self->user->userId,
                    start => strftime('%Y-%m-%d %H:%M:%S',localtime(time)),
                    lastmod => strftime('%Y-%m-%d %H:%M:%S',localtime(time))
                        . ' - RecStart by ' . $self->user->userInfo->{cbuser_login}
                }
            );
        }
        return {
            action => 'reload'
        }
    };

    my @actions = (
        {
            action => 'refresh',
            interval => 1
        }
    );

        if ( $self->user and $self->user->may('record') ) {
            push @actions, {
                label => trm('Zeit Erfassen'),
                key => 'record',
                action => 'submit',
                handler => $recordTime
            };
        }

        if (not $self->user or $self->user->may('admin') ) {
            push @actions, {
                label => trm('Neu'),
                action => 'popup',
                name => 'azeFormAdd',
                popupTitle => trm('Neuer Zeit Eintrag'),
                backend => {
                    plugin => 'AzeForm',
                    config => {
                        type => 'add'
                    }
                }
            },
            {
                label => trm('Bearbeiten'),
                action => 'popup',
                name => 'azeFormEdit',
                popupTitle => trm('Zeiteintrag Bearbeiten'),
                backend => {
                    plugin => 'AzeForm',
                    config => {
                        type => 'edit'
                    }
                }
            },
            {
                label => trm('Löschen'),
                action => 'submitVerify',
                question => trm('Diesen Eintrag wirklich löschen?'),
                key => 'delete',
                handler => sub {
                    my $args = shift;
                    my $id = $args->{selection}{aze_id};
                    die mkerror(4992,"Bitte einen Eintrag wählen")
                        if not $id;
                    $self->user->db->deleteData('aze',$id);
                    return {
                        action => 'reload'
                    };
                }
            };
    }
    return \@actions;
};

sub getTableRowCount {
    my $self = shift;
    my $args = shift;
    my $db = $self->user->mojoSqlDb;
    if ($self->user->may('admin')){
        return ($db->dbh->selectrow_array("SELECT count(aze_id) FROM aze"))[0];
    }
    else {
        return ($db->dbh->selectrow_array(
            "SELECT count(aze_id) FROM aze WHERE aze_cbuser = ? ",{},$self->user->userId)
        )[0];

    }
}

sub getTableData {
    my $self = shift;
    my $args = shift;
    my $db = $self->user->mojoSqlDb;
    my $SORT ='ORDER by aze_id DESC';
    if ($args->{sortColumn}){
        $SORT = 'ORDER BY '.$db->dbh->quote_identifier($args->{sortColumn});
        $SORT .= $args->{sortDesc} ? ' DESC' : ' ASC';
    }
    my $WHERE = '';
    if (! $self->user->may('admin')){
        $WHERE = ' WHERE aze_cbuser = ' . $db->dbh->quote($self->user->userId);
    }

    return $db->dbh->selectall_arrayref(<<"SQL_END",{Slice => {}}, $args->{lastRow}-$args->{firstRow}+1,$args->{firstRow});
SELECT aze_id,aze_cbuser,aze_start,aze_duration,aze_lastmod,aze_note,
    cbuser_login,
    date(aze_start) AS c_date,
    time(aze_start) AS c_begin,
    time(aze_start,'+' || aze_duration || ' seconds') AS c_end,
    time(aze_duration,'unixepoch') as c_total
FROM aze JOIN cbuser ON aze_cbuser = cbuser_id
$WHERE
$SORT
LIMIT ? OFFSET ?
SQL_END
}

1;
__END__

=head1 COPYRIGHT

Copyright (c) 2015 by Tobias Oetiker. All rights reserved.

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2015-34-08/27/15 to 0.0 first version

=cut
