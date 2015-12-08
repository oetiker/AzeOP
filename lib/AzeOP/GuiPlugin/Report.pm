package AzeOP::GuiPlugin::Report;
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

=head1 METHODS

All the methods of L<CallBackery::GuiPlugin::AbstractTable> plus:

=cut

has formCfg => sub {
    my $self = shift;
    my @reports = (
        {title => trm('Tag'), key => 'day'},
        {title => trm('Woche'), key => 'week'},
        {title => trm('Monat'), key => 'month'},
        {title => trm('Jahr'), key => 'year'},
    );
    my %reports;
    for my $r (@reports) {
        $reports{$r->{key}} = $r->{title};
    }

    return [
        {
            key => 'report_sel',
            label => trm('Report'),
            widget => 'selectBox',
            cfg => {
                required => $self->true,
                structure => \@reports,
            },
            validator => sub {
                my $value = shift;
                return trm("Unbekannter Report")
                    if not $reports{$value};
                return undef;
            },
        }
    ]
};

=head2 tableCfg

=cut

has tableCfg => sub {
    my $self = shift;
    return [
        {
            label => trm('Periode'),
            type => 'str',
            width => '1*',
            key => 'period',
            sortable => $self->true,
        },
        $self->user->may('admin') ? (
        {
            label => trm('User'),
            type => 'str',
            width => '2*',
            key => 'login',
            sortable => $self->true,
        },
        ):(),
        {
            label => trm('Total'),
            type => 'str',
            width => '2*',
            key => 'total',
            sortable => $self->true,
        },
        {
            label => trm('Soll'),
            type => 'str',
            width => '2*',
            key => 'required',
            sortable => $self->true,
        },
        {
            label => trm('Differenz'),
            type => 'str',
            width => '2*',
            key => 'difference',
            sortable => $self->true,
        }
    ]
};


=head2 actionCfg

Only users who can write get any actions presented.

=cut

has strftimeFormat => sub {
    return {
        day => '%Y-%m-%d',
        week => '%Y.%W',
        month => '%Y-%m',
        year => '%Y'
    };
};

sub getTableRowCount {
    my $self = shift;
    my $args = shift;
    my $db = $self->user->mojoSqlDb;
    my $strftime = $db->dbh->quote($self->strftimeFormat->{$args->{formData}{report_sel} || 'day'});
    my $WHERE = '';
    if (! $self->user->may('admin')){
        $WHERE = 'WHERE aze_cbuser = ' . $db->dbh->quote($self->user->userId);
    }

    return ($db->dbh->selectrow_array(<<"SQL_END"))[0];
SELECT SUM(x)
  FROM (
    SELECT 1 AS x
    FROM aze
    $WHERE
    GROUP BY strftime($strftime,aze_start), aze_cbuser
  );
SQL_END
}

sub getTableData {
    my $self = shift;
    my $args = shift;
    my $db = $self->user->mojoSqlDb;
    my $strftime = $db->dbh->quote($self->strftimeFormat->{$args->{formData}{report_sel} || 'day'});
    my $SORT ='ORDER by period DESC';
    if ($args->{sortColumn}){
        $SORT = 'ORDER BY '.$db->dbh->quote_identifier($args->{sortColumn});
        $SORT .= $args->{sortDesc} ? ' DESC' : ' ASC';
    }
    my $WHERE = '';
    if (! $self->user->may('admin')){
        $WHERE = 'WHERE aze_cbuser = ' . $db->dbh->quote($self->user->userId);
    }

    return $db->dbh->selectall_arrayref(<<"SQL_END",{Slice => {}}, $args->{lastRow}-$args->{firstRow}+1,$args->{firstRow});
SELECT
    strftime($strftime,aze_start) AS period,
    cbuser_login as login,
    printf('%.1f',sum(ifnull(aze_duration,0))/3600.0) as total,
    sum(NULL) AS required,
    sum(NULL) AS difference
FROM aze JOIN cbuser ON aze_cbuser = cbuser_id
    $WHERE
    GROUP BY period
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
