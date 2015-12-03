package Test::PONAPI::DAO::Repository::MockDB::Table;
use Moose;
use SQL::Composer;

use PONAPI::DAO::Constants;

sub insert_stmt {
    my ($self, %args) = @_;

    my $table = $args{table};
    my $values = $args{values};

    my $stmt = SQL::Composer::Insert->new(
        into   => $table,
        values => [ %$values ],
        driver => 'sqlite',
    );

    return $stmt;
}

sub delete_stmt {
    my ($self, %args) = @_;

    my $table = $args{table};
    my $where = $args{where};

    my $stmt = SQL::Composer::Delete->new(
        from => $table,
        where => [ %$where ],
        driver => 'sqlite',
    );

    return $stmt;
}


sub select_stmt {
    my ($self, %args) = @_;

    my $type    = $args{type};
    my $filters = $self->_stmt_filters($type, $args{filter});
    my $stmt = SQL::Composer::Select->new(
        from    => $type,
        columns => $self->_stmt_columns(\%args),
        where   => [ %{ $filters } ],
    );

    return $stmt;
}

sub update_stmt {
    my ($self, %args) = @_;

    my $id          = $args{id};
    my $table       = $args{table};
    my $values      = $args{values} || {};

    local $@;
    my $stmt = eval {
        SQL::Composer::Update->new(
            table  => $table,
            values => [ %$values ],
            where  => [ id => $id ],
            driver => 'sqlite',
        )
    } or do {
        my $msg = "$@"||'Unknown error';
        PONAPI::Exception->throw(
            sql_error => "Failed to compose an update with the given values",
            internal => $msg,
        );
    };

    return $stmt;
}

sub _stmt_columns {
    my $self = shift;
    my $args = shift;
    my ( $fields, $type ) = @{$args}{qw< fields type >};

    return $fields if $self->TABLE ne $type;

    ref $fields eq 'HASH' and exists $fields->{$type}
        or return $self->COLUMNS;

    my @fields_minus_relationship_keys =
        grep { !exists $self->RELATIONS->{$_} }
        @{ $fields->{$type} };

    return +[ 'id', @fields_minus_relationship_keys ];
}

sub _stmt_filters {
    my ( $self, $type, $filter ) = @_;

    return $filter if $self->TABLE ne $type;

    return +{
        map   { $_ => $filter->{$_} }
        grep  { exists $filter->{$_} }
        @{ $self->COLUMNS }
    };
}

__PACKAGE__->meta->make_immutable;
no Moose; 1;
__END__
