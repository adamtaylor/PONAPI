package PONAPI::DAO::Repository::SQLite;
use Moose;

use DBI;
use SQL::Composer;

with 'PONAPI::DAO::Repository';

has driver => (
    is      => 'ro',
    isa     => 'Str',
    default => sub { 'SQLite' },
);

has dbd => (
    is      => 'ro',
    isa     => 'Str',
    default => sub { 'DBI:SQLite:dbname=MockDB.db' },
);

has dbh => (
    is      => 'ro',
    isa     => 'DBI::db',
    lazy    => 1,
    builder => '_build_dbh',
);

sub _build_dbh {
    my $self = shift;
    DBI->connect( $self->dbd, '', '', { RaiseError => 1 } )
        or die $DBI::errstr;
}

sub BUILD {
    my $self = shift;

    $self->dbh->do($_) for
        q< DROP TABLE IF EXISTS articles; >,
        q< CREATE TABLE IF NOT EXISTS articles (
             id            INTEGER     PRIMARY KEY AUTOINCREMENT,
             title         CHAR(64)    NOT NULL,
             body          TEXT        NOT NULL,
             created       DATETIME    NOT NULL   DEFAULT CURRENT_TIMESTAMP,
             updated       DATETIME    NOT NULL   DEFAULT CURRENT_TIMESTAMP,
             status        CHAR(10)    NOT NULL   DEFAULT "pending approval" ); >,

        q< INSERT INTO articles (title, body, created, updated, status) VALUES
             ("JSON API paints my bikeshed!", "The shortest article. Ever.",
              "2015-05-22 14:56:29", "2015-05-22 14:56:29", "ok" ),
             ("A second title", "The 2nd shortest article. Ever.",
              "2015-06-22 14:56:29", "2015-06-22 14:56:29", "ok" ),
             ("a third one", "The 3rd shortest article. Ever.",
              "2015-07-22 14:56:29", "2015-07-22 14:56:29", "pending approval" ); >,

        q< DROP TABLE IF EXISTS people; >,
        q< CREATE TABLE IF NOT EXISTS people (
             id            INTEGER     PRIMARY KEY,
             name          CHAR(64)    NOT NULL   DEFAULT "anonymous",
             age           INTEGER     NOT NULL   DEFAULT "100",
             gender        CHAR(10)    NOT NULL   DEFAULT "unknown" ); >,

        q< INSERT INTO people (id, name, age, gender) VALUES
             (42, "John",  80, "male"),
             (88, "Jimmy", 18, "male"),
             (91, "Diana", 30, "female") >,

        q< DROP TABLE IF EXISTS rel_articles_people; >,
        q< CREATE TABLE IF NOT EXISTS rel_articles_people (
             id_articles   INTEGER     UNIQUE     NOT NULL,
             id_people     INTEGER     UNIQUE     NOT NULL ); >,

        q< INSERT INTO rel_articles_people (id_articles, id_people) VALUES
             (1, 42),
             (2, 88),
             (3, 91) >,

        q< DROP TABLE IF EXISTS comments; >,
        q< CREATE TABLE IF NOT EXISTS comments (
             id            INTEGER     PRIMARY KEY,
             body          TEXT        NOT NULL DEFAULT "" ); >,

        q< INSERT INTO comments (id, body) VALUES
             (5,  "First!"),
             (12, "I like XML better") >,

        q< DROP TABLE IF EXISTS rel_articles_comments; >,
        q< CREATE TABLE IF NOT EXISTS rel_articles_comments (
             id_articles   INTEGER     NOT NULL,
             id_comments   INTEGER     UNIQUE     NOT NULL ); >,

        q< INSERT INTO rel_articles_comments (id_articles, id_comments) VALUES
             (2, 5),
             (2, 12) >;
}

my %TABLE_RELATIONS = (
    articles => {
        authors  => { type => 'people',   rel_table => 'rel_articles_people'   },
        comments => { type => 'comments', rel_table => 'rel_articles_comments' },
    },
    people   => {
        articles => { type => 'articles', rel_table => 'rel_articles_people'   },
    },
    comments => {
        articles => { type => 'articles', rel_table => 'rel_articles_comments' },
    },
);

my %TABLE_COLUMNS = (
    articles => [qw< id title body created updated status >],
    people   => [qw< id name age gender >],
    comments => [qw< id body >],
);

sub has_type {
    my ( $self, $type ) = @_;
    !! exists $TABLE_RELATIONS{$type};
}

sub has_relationship {
    my ( $self, $type, $rel_name ) = @_;
    !! exists $TABLE_RELATIONS{$type}{$rel_name};
}

sub retrieve_all {
    my ( $self, %args ) = @_;

    # TODO: include <-- $args{include}
    # TODO: filter  <-- $args{filter}

    my $stmt = SQL::Composer::Select->new(
        from    => $args{type},
        columns => _stmt_columns(\%args),
    );

    $self->_retrieve_data( $stmt, @args{qw< document type >} );
}

sub retrieve {
    my ( $self, %args ) = @_;

    # TODO: include <-- $args{include}

    my $stmt = SQL::Composer::Select->new(
        from    => $args{type},
        columns => _stmt_columns(\%args),
        where   => [ id => $args{id} ],
    );

    $self->_retrieve_data( $stmt, @args{qw< document type >} );
}

sub retrieve_relationships {
    my ( $self, %args ) = @_;

    # TODO
}

sub retrieve_by_relationship {
    my ( $self, %args ) = @_;

    # TODO
}

sub create {
    my ( $self, %args ) = @_;

    my ( $doc, $type, $data ) = @args{qw< document type data >};
    $data and ref $data eq 'HASH'
        or return $doc->raise_error({ message => "can't create a resource without data" });

    my $stmt = SQL::Composer::Insert->new(
        into   => $type,
        values => [ %{ $data->{attributes} } ],
    );

    my $sth = $self->dbh->prepare($stmt->to_sql);
    my $ret = $sth->execute($stmt->to_bind);

    $ret < 0 and return $doc->raise_error({ message => $DBI::errstr });

    return $ret;
}

sub update {
    my ( $self, %args ) = @_;

    my ( $doc, $type, $id, $data ) = @args{qw< document type id data >};
    $data and ref $data eq 'HASH'
        or return $doc->raise_error({ message => "can't update a resource without data" });

    my $stmt = SQL::Composer::Update->new(
        table  => $type,
        values => [ %{ $data->{attributes} } ],
        where  => [ id => $id ],
    );

    my $sth = $self->dbh->prepare($stmt->to_sql);
    my $ret = $sth->execute($stmt->to_bind);

    $ret < 0 and return $doc->raise_error({ message => $DBI::errstr });

    return $ret;
}

sub delete : method {
    my ( $self, %args ) = @_;

    my ( $doc, $type, $id ) = @args{qw< document type id >};

    my $stmt = SQL::Composer::Delete->new(
        from  => $args{type},
        where => [ id => $id ],
    );

    my $sth = $self->dbh->prepare($stmt->to_sql);
    my $ret = $sth->execute($stmt->to_bind);

    $ret < 0 and return $doc->raise_error({ message => $DBI::errstr });

    return $ret;
}


## --------------------------------------------------------

sub _stmt_columns {
    my $args = shift;
    my ( $fields, $type ) = @{$args}{qw< fields type >};

    ref $fields eq 'HASH' and exists $fields->{$type}
        or return $TABLE_COLUMNS{$type};

    return +[ 'id', @{ $fields->{$type} } ];
}

sub _retrieve_data {
    my ( $self, $stmt, $doc, $type ) = @_;

    my $sth = $self->dbh->prepare($stmt->to_sql);
    my $ret = $sth->execute($stmt->to_bind);

    $ret or return $doc->raise_error({ message => $DBI::errstr });

    while ( my $row = $sth->fetchrow_hashref() ) {
        my $id = delete $row->{id};
        my $rec = $doc->add_resource( type => $type, id => $id );
        $rec->add_attribute( $_ => $row->{$_} ) for keys %{$row};

        $self->_add_resource_relationships($rec);

        # links???
    }
}

sub _add_resource_relationships {
    my ( $self, $rec ) = @_;

    my ( $rels, $errors ) =
        $self->_fetchall_resource_relationships( $rec->type, $rec->id );

    if ( @$errors ) {
        $rec->raise_error({ message => $_ }) for @$errors;
        return;
    }

    for my $r ( keys %{$rels} ) {
        $rec->add_relationship( $r, $_ ) for @{ $rels->{$r} };
    }
}

sub _fetchall_resource_relationships {
    my ( $self, $type, $id ) = @_;
    my %ret;
    my @errors;

    for my $name ( keys %{ $TABLE_RELATIONS{$type} } ) {
        my ( $rel_type, $rel_table ) =
            @{$TABLE_RELATIONS{$type}{$name}}{qw< type rel_table >};

        my $stmt = SQL::Composer::Select->new(
            from    => $rel_table,
            columns => [ 'id_' . $rel_type ],
            where   => [ 'id_' . $type => $id ],
        );

        my $sth = $self->dbh->prepare($stmt->to_sql);
        my $ret = $sth->execute($stmt->to_bind);

        $ret < 0 and push @errors => $DBI::errstr;

        $ret{$name} = +[
            map +{ type => $rel_type, id => @$_ },
            @{ $sth->fetchall_arrayref() }
        ];
    }

    return ( \%ret, \@errors );
}

sub _get_ids_filtered {
    my ( $self, $type, $filters ) = @_;

    my $data = $self->data;

    my @ids;

    # id filter

    my $id_filter = exists $filters->{id} ? delete $filters->{id} : undef;
    @ids = $id_filter
        ? grep { exists $data->{$type}{$_} } @{ $id_filter }
        : keys %{ $data->{$type} };

    # attribute filters
    for my $f ( keys %{ $filters } ) {
        @ids = grep {
            my $att = $data->{$type}{$_}{attributes}{$f};
            grep { $att eq $_ } @{ $filters->{$f} }
        } @ids;
    }

    return \@ids;
}


__PACKAGE__->meta->make_immutable;
no Moose; 1;
__END__
